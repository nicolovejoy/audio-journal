# Audio Journal System

A command-line audio journaling system that records your thoughts, auto-transcribes them with Whisper, and keeps everything organized and searchable.

## Features

- **One-command recording**: Record audio with automatic timestamping
- **Auto-transcription**: Uses OpenAI Whisper for speech-to-text
- **Smart organization**: Files organized by year/month automatically
- **Full-text search**: Search across all transcripts with context
- **Audio playback**: Easy access to original recordings
- **Markdown format**: Human-readable transcripts with metadata

## Quick Start

1. **Install dependencies**:

   ```bash
   # Install sox for audio recording
   brew install sox

   # Install whisper for transcription
   pip install openai-whisper

   # Optional: Install ffmpeg for better audio handling
   brew install ffmpeg
   ```

2. **Setup**:

   ```bash
   # Clone or create your journal directory
   mkdir ~/audio_journal
   cd ~/audio_journal

   # Make scripts executable
   chmod +x record.sh
   chmod +x search.sh

   # Optional: Add to PATH
   echo 'export PATH="$HOME/audio_journal:$PATH"' >> ~/.zshrc
   source ~/.zshrc
   ```

3. **Start journaling**:
   ```bash
   ./record.sh
   ```

## Usage

### Recording a Journal Entry

```bash
# Basic recording
./record.sh

# Record and immediately open transcript for editing
./record.sh --edit
```

**Recording process:**

1. Press Enter to start recording
2. Speak your thoughts
3. Press Ctrl+C to stop
4. Wait for automatic transcription
5. Files are saved and organized automatically

### Searching Your Journal

```bash
# Search for any term
./search.sh "morning routine"

# Search recent entries only
./search.sh "project ideas" --recent 7

# Search specific date
./search.sh "book notes" --date 2025-07-23

# Search and auto-play first match
./search.sh "meeting" --play
```

**Search features:**

- Case-insensitive search across all transcripts
- Shows context around matches
- Interactive selection of results
- Option to open transcript or play audio

## File Organization

```
~/audio_journal/
├── 2025/
│   ├── 07/
│   │   ├── journal_20250723_083045.m4a
│   │   ├── journal_20250723_083045.md
│   │   ├── journal_20250723_193012.m4a
│   │   └── journal_20250723_193012.md
│   └── 08/
│       ├── journal_20250801_074530.m4a
│       └── journal_20250801_074530.md
└── ...
```

**Naming convention**: `journal_YYYYMMDD_HHMMSS.{m4a,md}`

## Transcript Format

Each transcript is a markdown file with:

```markdown
# Audio Journal - July 23, 2025 at 8:30 AM

**Audio File:** `journal_20250723_083045.m4a`  
**Duration:** 127s  
**Size:** 2.1M  
**Model:** base

---

## Transcript

[Your transcribed thoughts here...]

---

## Notes & Reflections

<!-- Add your thoughts, tags, or follow-up notes here -->
```

## Configuration

Set environment variables to customize behavior:

```bash
# Change journal location (default: ~/audio_journal)
export JOURNAL_DIR="/path/to/your/journal"

# Change audio format (default: wav)
export AUDIO_FORMAT="mp3"  # or flac, aiff

# Change Whisper model (default: base)
# Options: tiny, base, small, medium, large
export WHISPER_MODEL="small"

# Set default editor for transcripts
export EDITOR="code"  # or vim, nano, etc.
```

## Tips & Tricks

### Daily Practice

- Set a consistent time (e.g., morning coffee)
- Keep recordings focused (3-10 minutes)
- Review and add notes to transcripts later

### Organization

- Use consistent keywords for easy searching
- Add tags in the "Notes & Reflections" section
- Reference other entries with dates or keywords

### Audio Quality

- Find a quiet space when possible
- Speak clearly and at normal pace
- Test recording levels initially

### Workflow Integration

- Add aliases for common commands:
  ```bash
  alias journal="cd ~/audio_journal && ./record.sh"
  alias jsearch="cd ~/audio_journal && ./search.sh"
  ```

## Troubleshooting

### "sox not found"

```bash
brew install sox
```

### "whisper not found"

```bash
pip install openai-whisper
```

### Poor transcription quality

- Try a larger Whisper model: `export WHISPER_MODEL="small"`
- Check audio input levels
- Reduce background noise

### Permission denied

```bash
chmod +x record.sh search.sh
```

### Can't hear audio playback

- Check system volume
- Install alternative player: `brew install mpv`

## Advanced Usage

### Batch Processing Old Audio Files

If you have existing audio files to transcribe:

```bash
# Create a simple batch script
for file in *.m4a; do
    whisper "$file" --output_format txt
    # Process into markdown format...
done
```

### Integration with Note-Taking Apps

- Import markdown files into Obsidian, Logseq, or Notion
- Use file system watchers to auto-import new entries
- Set up cloud sync for cross-device access

### Backup Strategy

- Sync journal directory to cloud storage
- Consider separate backup for audio files (larger)
- Export transcripts periodically

## Claude Code Integration

This system works great with Claude Code for:

- Customizing scripts for your workflow
- Adding new features (tags, summaries, etc.)
- Fixing issues or improving performance
- Creating additional automation

Just run `claude-code` in your journal directory and ask for help!

---

**Happy journaling!** 🎙️📝
