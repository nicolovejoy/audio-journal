#!/usr/bin/env python3

"""
Live Audio Journal Recording with Real-time Transcription V2
- Overlapping segments to prevent word loss
- Live draft display during transcription
- Better segment handling
"""

import os
import sys
import time
import threading
import subprocess
import queue
import tempfile
import json
from datetime import datetime
from pathlib import Path
import termios
import tty
import select
import signal

class LiveRecorder:
    def __init__(self):
        self.journal_dir = Path(os.environ.get('JOURNAL_DIR', Path.home() / 'Documents' / 'AudioJournal'))
        self.whisper_model = os.environ.get('WHISPER_MODEL', 'base')
        self.recording = False
        self.segments = []
        self.transcription_queue = queue.Queue()
        self.results = {}
        self.temp_dir = Path(tempfile.mkdtemp())
        self.main_audio_file = self.temp_dir / "recording.wav"
        self.last_segment_end = 0.0  # Track where last segment actually ended
        self.start_time = None
        self.current_draft = {}  # Store draft transcriptions
        self.overlap_seconds = 1.0  # Overlap between segments
        
        # Setup directories
        self.year = datetime.now().strftime("%Y")
        self.audio_dir = self.journal_dir / 'audio' / self.year
        self.transcript_dir = self.journal_dir / 'transcripts' / self.year
        self.audio_dir.mkdir(parents=True, exist_ok=True)
        self.transcript_dir.mkdir(parents=True, exist_ok=True)
        
        # Generate filename
        now = datetime.now()
        self.filename = now.strftime("%b").upper() + now.strftime("_%d_%H.%M")
        
    def start_recording(self):
        """Start sox recording in background"""
        self.recording = True
        self.start_time = time.time()
        
        # Start sox with larger buffer for better real-time performance
        self.sox_process = subprocess.Popen([
            'sox', '-t', 'coreaudio', '-d', 
            '-r', '16000',  # Lower sample rate for faster processing
            str(self.main_audio_file),
            'silence', '1', '0.1', '1%', '1', '120.0', '1%'
        ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        
        print(f"\033[32m🎙️  Recording started - {self.filename}\033[0m")
        print("\033[33mPress RETURN for new paragraph, '.' for sentence end, Ctrl+C to finish\033[0m")
        print("\033[36m" + "="*60 + "\033[0m\n")
        print("\033[90m[Draft text will appear here as you speak...]\033[0m\n")
        
    def mark_segment(self, segment_type='paragraph'):
        """Mark current position as segment boundary with overlap"""
        if not self.recording:
            return
            
        current_time = time.time() - self.start_time
        
        # Ensure minimum segment length
        if current_time > self.last_segment_end + 0.5:
            # Start segment slightly before last end for continuity
            segment_start = max(0, self.last_segment_end - self.overlap_seconds)
            
            segment = {
                'start': segment_start,
                'end': current_time,
                'type': segment_type,
                'index': len(self.segments),
                'actual_start': self.last_segment_end  # Where new content actually begins
            }
            self.segments.append(segment)
            self.last_segment_end = current_time
            
            # Queue for transcription
            self.transcription_queue.put(segment)
            
            # Visual feedback
            if segment_type == 'paragraph':
                print(f"\n\033[35m[¶ New paragraph at {self.format_time(current_time)}]\033[0m")
            else:
                print(f"\033[35m[. Sentence at {self.format_time(current_time)}]\033[0m", end='')
            
            # Start live preview for this segment
            threading.Thread(target=self.show_live_preview, args=(segment,), daemon=True).start()
            
            return segment
        
    def format_time(self, seconds):
        """Format seconds to MM:SS"""
        mins = int(seconds // 60)
        secs = int(seconds % 60)
        return f"{mins:02d}:{secs:02d}"
        
    def extract_segment_audio(self, segment):
        """Extract audio segment with proper timing"""
        output_file = self.temp_dir / f"segment_{segment['index']}.wav"
        
        # Wait for audio to be written to disk
        time.sleep(1.0)
        
        # Extract with slight padding
        cmd = [
            'ffmpeg', '-i', str(self.main_audio_file),
            '-ss', str(segment['start']),
            '-to', str(segment['end'] + 0.5),  # Add small buffer at end
            '-c', 'copy',
            str(output_file),
            '-y', '-loglevel', 'error'
        ]
        
        subprocess.run(cmd, check=False)
        return output_file if output_file.exists() else None
        
    def show_live_preview(self, segment):
        """Show preliminary transcription quickly"""
        # Quick and dirty transcription for preview
        audio_file = self.extract_segment_audio(segment)
        if not audio_file:
            return
            
        try:
            # Use tiny model for fast preview if available
            preview_model = 'tiny' if segment['index'] > 0 else self.whisper_model
            
            print(f"\033[90m[Transcribing segment {segment['index']+1}...]\033[0m", end='\r')
            
            result = subprocess.run([
                'whisper', str(audio_file),
                '--model', preview_model,
                '--output_format', 'txt',
                '--output_dir', str(self.temp_dir),
                '--verbose', 'False',
                '--fp16', 'False'
            ], capture_output=True, text=True, timeout=30)
            
            txt_file = audio_file.with_suffix('.txt')
            if txt_file.exists():
                with open(txt_file) as f:
                    draft_text = f.read().strip()
                    
                # Store draft
                self.current_draft[segment['index']] = draft_text
                
                # Clear the "Transcribing..." message
                print(' ' * 40, end='\r')
                
                # Show draft in gray/italic
                print(f"\033[90m[{self.format_time(segment['actual_start'])}] {draft_text}\033[0m")
                
        except Exception as e:
            pass  # Silently fail for preview
            
    def transcribe_segment(self, segment):
        """Full quality transcription for final version"""
        audio_file = self.temp_dir / f"segment_{segment['index']}.wav"
        
        # Re-extract if needed for better quality
        if not audio_file.exists():
            audio_file = self.extract_segment_audio(segment)
            
        if not audio_file:
            return None
            
        try:
            # Full quality transcription
            result = subprocess.run([
                'whisper', str(audio_file),
                '--model', self.whisper_model,
                '--output_format', 'json',
                '--output_dir', str(self.temp_dir),
                '--verbose', 'False',
                '--fp16', 'False'
            ], capture_output=True, text=True)
            
            # Parse result
            json_file = audio_file.with_suffix('.json')
            if json_file.exists():
                with open(json_file) as f:
                    data = json.load(f)
                    full_text = data.get('text', '').strip()
                    
                    # If we have overlap, try to remove duplicate content
                    if segment['index'] > 0 and segment['index']-1 in self.results:
                        prev_text = self.results[segment['index']-1]['text']
                        # Simple deduplication - look for overlap
                        if len(prev_text) > 20:
                            # Check if beginning of new text appears at end of previous
                            words_to_check = full_text.split()[:5]
                            if words_to_check:
                                check_phrase = ' '.join(words_to_check)
                                if check_phrase in prev_text:
                                    # Remove the overlapping part
                                    idx = full_text.find(check_phrase)
                                    if idx > 0:
                                        full_text = full_text[idx+len(check_phrase):].strip()
                    
                    return full_text
                    
        except Exception as e:
            print(f"\033[31mTranscription error: {e}\033[0m")
            
        return None
        
    def transcription_worker(self):
        """Background thread for processing final transcriptions"""
        while self.recording or not self.transcription_queue.empty():
            try:
                segment = self.transcription_queue.get(timeout=1)
                
                # Wait a bit for better audio capture
                time.sleep(0.5)
                
                text = self.transcribe_segment(segment)
                if text:
                    self.results[segment['index']] = {
                        'text': text,
                        'start': segment['actual_start'],
                        'end': segment['end'],
                        'type': segment['type']
                    }
                    
                    # Display final result (overwrite draft)
                    print(f"\033[32m[{self.format_time(segment['actual_start'])}] {text}\033[0m\n")
                    
            except queue.Empty:
                continue
            except Exception as e:
                print(f"\033[31mWorker error: {e}\033[0m")
                
    def get_single_char(self):
        """Get single character input without blocking"""
        fd = sys.stdin.fileno()
        old_settings = termios.tcgetattr(fd)
        try:
            tty.setraw(sys.stdin.fileno())
            if select.select([sys.stdin], [], [], 0.1)[0]:
                ch = sys.stdin.read(1)
                return ch
        finally:
            termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)
        return None
        
    def monitor_input(self):
        """Monitor keyboard input during recording"""
        while self.recording:
            ch = self.get_single_char()
            if ch:
                if ch == '\r' or ch == '\n':  # Return key
                    self.mark_segment('paragraph')
                elif ch == '.':  # Period key
                    self.mark_segment('sentence')
                elif ch == '\x03':  # Ctrl+C
                    self.stop_recording()
                    break
                    
    def stop_recording(self):
        """Stop recording and finalize"""
        if not self.recording:
            return
            
        print("\n\n\033[33m⏹️  Stopping recording...\033[0m")
        
        # Mark final segment
        self.mark_segment('paragraph')
        
        self.recording = False
        if hasattr(self, 'sox_process'):
            self.sox_process.terminate()
            self.sox_process.wait()
            
        # Wait for transcriptions to complete
        print("\033[33m⏳ Finishing final transcriptions...\033[0m")
        while not self.transcription_queue.empty():
            time.sleep(0.5)
        time.sleep(3)  # Give time for final processing
        
    def save_results(self):
        """Save audio and create transcript file"""
        # Compress audio
        final_audio = self.audio_dir / f"{self.filename}.m4a"
        print(f"\033[33m🔄 Compressing audio...\033[0m")
        subprocess.run([
            'ffmpeg', '-i', str(self.main_audio_file),
            '-c:a', 'aac', '-b:a', '64k', '-ar', '22050',
            str(final_audio), '-y', '-loglevel', 'error'
        ])
        
        # Build transcript
        transcript_parts = []
        for i in sorted(self.results.keys()):
            result = self.results[i]
            time_str = f"[{self.format_time(result['start'])}]"
            transcript_parts.append(f"{time_str} {result['text']}")
            if result['type'] == 'paragraph':
                transcript_parts.append("")  # Empty line for paragraph
                
        full_transcript = "\n".join(transcript_parts)
        
        # Create markdown file
        transcript_file = self.transcript_dir / f"{self.filename}.md"
        duration = self.format_time(time.time() - self.start_time)
        word_count = sum(len(r['text'].split()) for r in self.results.values())
        
        with open(transcript_file, 'w') as f:
            f.write(f"# Audio Journal - {datetime.now().strftime('%B %d, %Y at %I:%M %p')}\n\n")
            f.write(f"**Audio:** `{self.filename}.m4a` | **Duration:** {duration} | ")
            f.write(f"**Segments:** {len(self.results)}\n\n")
            f.write("---\n\n")
            f.write("## Transcript\n\n")
            f.write(full_transcript)
            f.write("\n\n---\n\n")
            f.write("## Metadata\n\n")
            f.write(f"- **Words:** {word_count}\n")
            f.write(f"- **Duration:** {duration}\n")
            f.write(f"- **Paragraphs:** {sum(1 for r in self.results.values() if r['type'] == 'paragraph')}\n")
            f.write(f"- **Model:** whisper-{self.whisper_model}\n")
            f.write(f"- **Live Transcription:** Yes (with overlap)\n")
            f.write("\n---\n\n")
            f.write("## Notes\n\n")
            f.write("<!-- Add your thoughts, tags, or follow-up notes here -->\n\n")
            
        print(f"\n\033[32m✅ Journal entry saved!\033[0m")
        print(f"  🎵 Audio: {final_audio.name}")
        print(f"  📄 Transcript: {transcript_file.name}")
        
        # Git commit
        if (self.journal_dir / '.git').exists():
            subprocess.run(['git', 'add', str(transcript_file)], 
                         cwd=self.journal_dir, capture_output=True)
            subprocess.run(['git', 'commit', '-q', '-m', f'Add live entry: {self.filename}'],
                         cwd=self.journal_dir, capture_output=True)
            
        # Cleanup
        for file in self.temp_dir.glob('*'):
            file.unlink()
        self.temp_dir.rmdir()
        
    def run(self):
        """Main execution"""
        try:
            # Check dependencies
            for cmd in ['sox', 'ffmpeg', 'whisper']:
                if subprocess.run(['which', cmd], capture_output=True).returncode != 0:
                    print(f"\033[31mError: {cmd} not found\033[0m")
                    return
                    
            self.start_recording()
            
            # Start transcription worker
            worker = threading.Thread(target=self.transcription_worker)
            worker.start()
            
            # Monitor input
            self.monitor_input()
            
            # Wait for worker
            worker.join()
            
            # Save results
            if self.results:
                self.save_results()
            else:
                print("\033[33mNo segments transcribed\033[0m")
                
        except KeyboardInterrupt:
            self.stop_recording()
        except Exception as e:
            print(f"\033[31mError: {e}\033[0m")
            self.stop_recording()

if __name__ == "__main__":
    recorder = LiveRecorder()
    recorder.run()