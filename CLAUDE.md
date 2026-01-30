# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

### Development & Testing
```bash
# Run the main recording script
./record.sh
./record.sh --edit  # Opens transcript after recording

# Search through transcripts
./search.sh "keyword"
./search.sh -y 2025  # Filter by year
./search.sh -l 10    # Limit results

# Setup new installation
./setup.sh

```

### Testing Individual Components
```bash
# Test audio recording (requires sox)
sox -d -r 16000 test.wav silence 1 0.1 3% 1 2.0 3%

# Test audio compression (requires ffmpeg)
ffmpeg -i test.wav -c:a aac -b:a 64k test.m4a

# Test Whisper transcription
whisper test.m4a --language en --output_format txt

# Process existing audio files
./process-existing.sh recording.m4a
./process-existing.sh -d "2024-12-25 14:30" old_recording.wav
./process-existing.sh -b ~/Downloads/audio_files/
```

## Architecture Overview

This is a Bash-based audio journaling system with a two-repository design:

1. **Code Repository** (`~/src/audio-journal/`): Contains the scripts (public)
2. **Data Repository** (`~/Documents/AudioJournal/`): Contains journal entries (private)

### Core Scripts

- **record.sh**: Main recording and transcription script. Uses sox for recording, ffmpeg for compression, and OpenAI Whisper for transcription. Handles all file organization and git commits.
- **record-enhanced.sh**: Enhanced version with timestamps, paragraph breaks, word count, and transcription confidence metrics.
- **process-existing.sh**: Process existing audio files with enhanced features. Preserves original recording dates and supports batch processing.
- **search.sh**: Search functionality with interactive selection and playback. Searches across all transcripts and provides context.
- **setup.sh**: Initial setup script that creates directory structure, checks dependencies, and initializes git repos.

### Data Structure
```
AudioJournal/
├── audio/
│   └── 2025/
│       └── JAN_28_07.05.m4a
├── transcripts/
│   └── 2025/
│       └── JAN_28_07.05.md
└── .sync/
    └── manifest.json
```

### Key Design Decisions

1. **File Naming**: Compact format `MON_DD_HH.MM` (e.g., `JAN_28_07.05`)
2. **Storage Strategy**: Git for transcripts, optional cloud sync for audio
3. **Metadata**: JSON manifest tracks SHA-256 hashes for integrity
4. **Dependencies**: Graceful degradation if optional dependencies missing
5. **Privacy**: All data local by default, no cloud services required

### When Making Changes

- Maintain compatibility with both macOS and Linux
- Preserve the simple, Unix-philosophy approach
- Keep scripts self-contained and dependency-light
- Use colored output for better UX (but make it optional)
- Always use proper error handling and user feedback
- Maintain backward compatibility with existing data structures