# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

### Development & Testing
```bash
# Run the main recording script (live transcription mode)
./record-now.sh

# Search through transcripts
./search.sh "keyword"
./search.sh -y 2025  # Filter by year
./search.sh -l 10    # Limit results

# Setup new installation
./setup.sh

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

- **record.sh**: Main recording and transcription script. Uses sox for recording, ffmpeg for compression. Supports both OpenAI Whisper API (fast, recommended) and local whisper (free). Includes timestamps, paragraph breaks, confidence metrics, and auto git commits.
- **record-now.sh**: Live transcription mode (experimental). Records audio while transcribing in real-time via local whisper. Press RETURN for new paragraphs, Ctrl+C to stop and save.
- **process-existing.sh**: Process existing audio files. Preserves original recording dates and supports batch processing.
- **search.sh**: Search functionality with interactive selection and playback. Searches across all transcripts and provides context.
- **setup.sh**: Initial setup script that creates directory structure, checks dependencies, and initializes git repos.

### Transcription Modes

The system supports two transcription backends:

1. **OpenAI Whisper API** (recommended): Set `OPENAI_API_KEY` env var. Fast (~10s for 5min audio), highest quality.
2. **Local whisper**: Install via `pip install openai-whisper`. Free but slower. Model controlled via `WHISPER_MODEL` env var.

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

### Scope

This repo is focused on **audio journaling** — spoken word recording, transcription, and archival. Songwriting transcription has moved to the [songscribe](~/src/songscribe) project.

### Next Steps

1. Improve journal search (tagging, categorization, date ranges)
2. Better transcript formatting (speaker detection, topic headers)
3. Evaluate `record-live-v2.py` / `record-now.sh` live transcription mode for promotion from experimental