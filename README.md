# Audio Journal

A simple, efficient command-line audio journaling system with automatic transcription.

**Code Repository**: https://github.com/nicolovejoy/audio-journal

## Features

- 🎙️ **Quick audio recording** with automatic silence detection
- 🔤 **Automatic transcription** using OpenAI Whisper (99+ languages)
- 📁 **Organized file structure** - entries sorted by year with compact naming
- 🗜️ **Efficient storage** - audio compressed to m4a format (~10x smaller than WAV)
- 🔍 **Full-text search** across all transcripts
- 🔄 **Hybrid sync support** - Git for transcripts, cloud for audio
- 📊 **Enhanced transcription** - timestamps, paragraph breaks, confidence metrics
- 📥 **Import existing audio** - process voice memos and recordings from other devices

## Quick Start

```bash
# Install dependencies
brew install sox ffmpeg jq
pip install openai-whisper

# Run setup
./setup.sh

# Start recording (live transcription mode)
./record-now.sh

# Search entries
./search.sh "meeting notes"
```

## File Structure

This system uses two separate git repositories:

1. **Code Repository** (`~/src/audio-journal/`):
   - The scripts and tools (this repo)
   - Clone from: https://github.com/nicolovejoy/audio-journal

2. **Data Repository** (`~/Documents/AudioJournal/`):
   - Your personal journal entries
   - Created automatically on first run
   - Private to your machine (or your own remote)

```
~/Documents/AudioJournal/        # Your journal data (separate git repo)
├── audio/
│   └── 2025/
│       ├── JAN_28_07.05.m4a  # Audio: MON_DD_HH.MM format
│       └── JAN_28_14.30.m4a  # Multiple entries per day
├── transcripts/
│   └── 2025/
│       ├── JAN_28_07.05.md   # Enhanced transcript with metadata
│       └── JAN_28_14.30.md   # Includes timestamps and paragraphs
├── .git/                      # Version control (transcripts only)
├── .gitignore                 # Excludes audio files
└── .sync/
    └── manifest.json          # Metadata for sync tracking
```

## Usage

### Recording

```bash
./record-now.sh          # Start live transcription mode
```

**Controls during recording:**
- `RETURN` - Start new paragraph (triggers transcription)
- `.` - Mark sentence end
- `Ctrl+C` - Stop recording and save

The script transcribes in real-time as you speak, showing results as they're ready.

### Searching

```bash
./search.sh              # List all entries
./search.sh "keyword"    # Search transcripts
./search.sh -l 10        # Limit results
./search.sh -v           # Verbose output with context
./search.sh -y 2025      # Filter by year
```

### Processing Existing Audio

```bash
# Process a single file
./process-existing.sh recording.m4a

# Override the recording date
./process-existing.sh -d "2024-12-25 14:30" old_recording.wav

# Batch process a directory
./process-existing.sh -b ~/Downloads/audio_files/

# Process multiple files
./process-existing.sh *.m4a

# Force overwrite existing transcripts
./process-existing.sh -f recording.m4a
```

### Configuration

Set environment variables to customize:

```bash
export JOURNAL_DIR="$HOME/MyJournal"        # Change storage location
export WHISPER_MODEL="small"                # Use larger model (base/small/medium/large)
export AUDIO_FORMAT="wav"                   # Keep uncompressed audio
```

## Sync Strategy

The system uses a hybrid approach:

1. **Transcripts in Git**
   - Small text files (~2-5KB)
   - Version controlled
   - Easy to merge across devices
   - Full-text searchable

2. **Audio in Cloud Storage**
   ```bash
   # Option 1: iCloud (Mac/iOS)
   ln -s ~/Library/Mobile\ Documents/com~apple~CloudDocs/AudioJournal ~/Documents/AudioJournal
   
   # Option 2: Dropbox
   ln -s ~/Dropbox/AudioJournal ~/Documents/AudioJournal
   ```

3. **Metadata Tracking**
   - SHA-256 hashes for integrity
   - File sizes and durations
   - Sync status per entry

## Transcript Format

Enhanced transcripts include:
- Recording date and time
- Audio file reference
- Duration and file size  
- Timestamped transcription with paragraph breaks
- Word count and language detection
- Confidence metrics
- Space for manual notes

Example:
```markdown
# Audio Journal - January 28, 2025 at 07:05 AM

**Audio:** `JAN_28_07.05.m4a` | **Duration:** 03:45 | **Size:** 1.2M  

---

## Transcript

[00:00] Today I want to discuss the new project architecture. The main focus will be on scalability and maintainability.

[01:00] We need to consider three key components: the frontend, the API layer, and the database design.

[02:00] First, let's talk about the frontend architecture...

---

## Metadata

- **Words:** 523
- **Duration:** 03:45
- **Language:** English (95.3% confidence)
- **Paragraphs:** 3
- **Average Confidence:** 95.3%
- **Low Confidence Segments:** 2 (marked with *)
- **Model:** whisper-base

---

## Notes

<!-- Add your thoughts, tags, or follow-up notes here -->
#architecture #planning
```

## What's New

### Efficient Storage
- **Compact naming**: `MON_DD_HH.MM` format (e.g., `JAN_28_07.05`)
- **m4a compression**: ~10x smaller than WAV with great quality
- **Yearly folders**: Simple flat structure, easy to archive

### Hybrid Sync
- **Git for text**: Version control for all transcripts
- **Cloud for audio**: iCloud/Dropbox for large audio files
- **Metadata tracking**: JSON manifest with hashes and sync status

### Better Organization
- **One folder per year**: ~365 files/year is manageable
- **Auto-commit**: Git tracks all transcript changes
- **Setup script**: One-command installation

## Dependencies

- **sox**: Audio recording
- **ffmpeg**: Audio compression  
- **whisper**: Transcription (optional)
- **jq**: JSON processing (optional)
- **git**: Version control (optional)

## Privacy & Security

- All data stored locally
- No cloud services required
- Audio files can be encrypted via FileVault
- Git repos can be private/self-hosted

## Tips

1. **For long recordings**: Whisper works best with <30 min audio
2. **For better transcription**: Use `WHISPER_MODEL=small` or `medium`
3. **For meetings**: Consider `WHISPER_MODEL=medium.en` for English-only
4. **For privacy**: Keep audio files local, only sync transcripts
5. **For multilingual use**: Whisper auto-detects language but works best when each recording is in a single language. Don't mix languages within one recording.

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
- Try a larger model: `export WHISPER_MODEL="small"`
- Check audio input levels
- Reduce background noise

### Permission denied
```bash
chmod +x *.sh
```

## License

MIT License - see LICENSE file