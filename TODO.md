# TODO: Repository Cleanup Needed

## Current State (Jan 2025)

The repo is in a transitional state with multiple recording script versions and some cleanup needed.

### What's Working
- `search.sh` - Search transcripts (committed, good)
- `setup.sh` - Initial setup (committed, good)
- `process-existing.sh` - Import existing audio files (new, ready to use)
- `record-live-v2.py` + `record-now.sh` - Python live transcription (new, experimental)

### Issues to Resolve

1. **No `record.sh` at root** - The main entry point was deleted. README/CLAUDE.md reference it but it doesn't exist.

2. **`old/` directory** - Contains scripts that should either be promoted to root or deleted:
   - `old/record.sh` - Enhanced bash version (timestamps, paragraphs, confidence)
   - `old/record-old.sh` - Basic bash version
   - `old/record-live.py` - Python live v1

3. **Documentation mismatch** - CLAUDE.md mentions `record-enhanced.sh` which doesn't exist.

### Recommendations

**Option A: Keep it simple (bash-based)**
```
record.sh        <- copy from old/record.sh (enhanced version)
rm -rf old/
```

**Option B: Two modes**
```
record.sh        <- copy from old/record.sh (bash, transcribe-at-end)
record-live.sh   <- rename record-now.sh (Python, real-time)
rm -rf old/
```

**Option C: Go all-in on live transcription**
```
record.sh        <- rename record-now.sh (Python live)
rm -rf old/
```

### After choosing, also:
- Update CLAUDE.md to match actual scripts
- Update README.md if needed
- Delete `migrate.sh` reference if any

## Directory Structure Change

The data structure changed from flat to separated:
```
# Old:
AudioJournal/2025/file.m4a
AudioJournal/2025/file.md

# New:
AudioJournal/audio/2025/file.m4a
AudioJournal/transcripts/2025/file.md
```

All new scripts use the new structure. This is good but means old journal data may need migration.
