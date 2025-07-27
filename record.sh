#!/bin/bash

# Audio Journal Recording Script
# Records audio, transcribes with Whisper, organizes files

set -e

# Configuration
JOURNAL_DIR="${JOURNAL_DIR:-$HOME/audio_journal}"
AUDIO_FORMAT="${AUDIO_FORMAT:-wav}"
WHISPER_MODEL="${WHISPER_MODEL:-base}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Ensure journal directory exists
mkdir -p "$JOURNAL_DIR"

# Generate timestamp and filenames
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
DATE_DIR="$JOURNAL_DIR/$(date +"%Y/%m")"
mkdir -p "$DATE_DIR"

AUDIO_FILE="$DATE_DIR/journal_${TIMESTAMP}.${AUDIO_FORMAT}"
TRANSCRIPT_FILE="$DATE_DIR/journal_${TIMESTAMP}.md"

echo -e "${GREEN}Audio Journal - $(date)${NC}"
echo "Recording to: $AUDIO_FILE"
echo ""
echo -e "${YELLOW}Press ENTER to start recording, then CTRL+C to stop${NC}"
read -r

# Check if sox is available for recording
if ! command -v sox &> /dev/null; then
    echo -e "${RED}Error: sox not found. Install with: brew install sox${NC}"
    exit 1
fi

# Record audio
echo -e "${GREEN}🎙️  Recording... (Press CTRL+C to stop)${NC}"
trap 'echo -e "\n${YELLOW}Recording stopped${NC}"' INT

# Record using sox with default input device
# silence parameters: 1 0.1 3% (skip initial silence) 1 120.0 3% (stop after 2 minutes of silence)
sox -t coreaudio -d "$AUDIO_FILE" silence 1 0.1 3% 1 120.0 3%

echo -e "${GREEN}✅ Recording saved to: $(basename "$AUDIO_FILE")${NC}"

# Check if whisper is available
if ! command -v whisper &> /dev/null; then
    echo -e "${RED}Warning: whisper not found. Install with: pip install openai-whisper${NC}"
    echo "Creating transcript file without transcription..."
    create_transcript_file_no_whisper
    exit 0
fi

# Transcribe with whisper
echo -e "${YELLOW}🔄 Transcribing...${NC}"
whisper "$AUDIO_FILE" \
    --model "$WHISPER_MODEL" \
    --output_format txt \
    --output_dir "$(dirname "$AUDIO_FILE")" \
    --verbose False

# Create markdown transcript with metadata
create_transcript_file() {
    local txt_file="${AUDIO_FILE%.*}.txt"
    local audio_basename=$(basename "$AUDIO_FILE")
    local file_size=$(du -h "$AUDIO_FILE" | cut -f1)
    local duration=$(ffprobe -v quiet -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$AUDIO_FILE" 2>/dev/null | cut -d. -f1 || echo "unknown")
    
    cat > "$TRANSCRIPT_FILE" << EOF
# Audio Journal - $(date +"%B %d, %Y at %I:%M %p")

**Audio File:** \`$audio_basename\`  
**Duration:** ${duration}s  
**Size:** $file_size  
**Model:** $WHISPER_MODEL  

---

## Transcript

$(cat "$txt_file" 2>/dev/null || echo "Transcription failed or not available")

---

## Notes & Reflections

<!-- Add your thoughts, tags, or follow-up notes here -->

EOF

    # Clean up the raw txt file
    rm -f "$txt_file"
}

create_transcript_file_no_whisper() {
    local audio_basename=$(basename "$AUDIO_FILE")
    local file_size=$(du -h "$AUDIO_FILE" | cut -f1)
    
    cat > "$TRANSCRIPT_FILE" << EOF
# Audio Journal - $(date +"%B %d, %Y at %I:%M %p")

**Audio File:** \`$audio_basename\`  
**Size:** $file_size  

---

## Transcript

*Transcription not available - whisper not installed*

---

## Notes & Reflections

<!-- Add your thoughts, tags, or follow-up notes here -->

EOF
}

create_transcript_file

echo -e "${GREEN}✅ Transcript created: $(basename "$TRANSCRIPT_FILE")${NC}"
echo ""
echo -e "${YELLOW}Files created:${NC}"
echo "  Audio: $AUDIO_FILE"
echo "  Notes: $TRANSCRIPT_FILE"
echo ""
echo -e "${GREEN}Happy journaling! 📝${NC}"

# Optional: Open transcript in default editor
if [[ "$1" == "--edit" ]] || [[ "$1" == "-e" ]]; then
    ${EDITOR:-code} "$TRANSCRIPT_FILE"
fi