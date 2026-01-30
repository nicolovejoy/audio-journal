#!/bin/bash

# Audio Journal Recording Script
# Records audio, transcribes with Whisper, organizes files

set -e

# Configuration
JOURNAL_DIR="${JOURNAL_DIR:-$HOME/Documents/AudioJournal}"
AUDIO_FORMAT="${AUDIO_FORMAT:-m4a}"
WHISPER_MODEL="${WHISPER_MODEL:-base}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
BLINK='\033[5m'
NC='\033[0m' # No Color

# Ensure journal directory exists
YEAR=$(date +"%Y")
AUDIO_DIR="$JOURNAL_DIR/audio/$YEAR"
TRANSCRIPT_DIR="$JOURNAL_DIR/transcripts/$YEAR"
mkdir -p "$AUDIO_DIR"
mkdir -p "$TRANSCRIPT_DIR"
mkdir -p "$JOURNAL_DIR/.sync"

# Generate compact filename: MON_DD_HH.MM
MONTH=$(date +"%b" | tr '[:lower:]' '[:upper:]')
FILENAME="${MONTH}_$(date +"%d_%H.%M")"

AUDIO_FILE="$AUDIO_DIR/${FILENAME}.${AUDIO_FORMAT}"
TRANSCRIPT_FILE="$TRANSCRIPT_DIR/${FILENAME}.md"

# Clear screen for better UX
clear
echo ""
echo -e "${BLUE}${BOLD}╔═══════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}${BOLD}║                                                       ║${NC}"
echo -e "${BLUE}${BOLD}║${NC}  ${BOLD}${BLUE}⏸️  NOT RECORDING YET - PRESS ENTER TO START ⏸️${NC}   ${BLUE}${BOLD}║${NC}"
echo -e "${BLUE}${BOLD}║                                                       ║${NC}"
echo -e "${BLUE}${BOLD}╚═══════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}🎙️  AUDIO JOURNAL RECORDING STUDIO${NC}"
echo -e "${CYAN}───────────────────────────────────────────────────────${NC}"
echo ""
echo -e "${BLUE}📅 Date:${NC} $(date +'%A, %B %d, %Y')"
echo -e "${BLUE}🕐 Time:${NC} $(date +'%I:%M %p')"
echo -e "${BLUE}🌐 Model:${NC} $WHISPER_MODEL (auto-detects language)"
echo -e "${BLUE}📁 File:${NC} $FILENAME"
echo ""
echo -e "${CYAN}───────────────────────────────────────────────────────${NC}"
echo ""
echo -e "${GREEN}${BOLD}▶  Press ENTER to START recording${NC}"
echo -e "${YELLOW}   (then press CTRL+C to stop)${NC}"
echo ""
echo -e "${PURPLE}💡 Tip: Speak in one language per recording${NC}"
echo ""
read -r

# Check if sox is available for recording
if ! command -v sox &> /dev/null; then
    echo -e "${RED}Error: sox not found. Install with: brew install sox${NC}"
    exit 1
fi

# Check if ffmpeg is available for compression
if ! command -v ffmpeg &> /dev/null; then
    echo -e "${RED}Error: ffmpeg not found. Install with: brew install ffmpeg${NC}"
    exit 1
fi

# Clear screen and show recording interface
clear
echo ""
echo -e "${RED}${BLINK}●${NC} ${RED}${BOLD}RECORDING IN PROGRESS${NC} ${RED}${BLINK}●${NC}"
echo ""
echo -e "${RED}═══════════════════════════════════════════════════════${NC}"
echo -e "${RED}║                                                     ║${NC}"
echo -e "${RED}║${NC}    ${BOLD}${RED}🎙️  RECORDING... SPEAK NOW! 🎙️${NC}              ${RED}║${NC}"
echo -e "${RED}║                                                     ║${NC}"
echo -e "${RED}║${NC}         ${YELLOW}Press ${BOLD}CTRL+C${NC}${YELLOW} to stop${NC}                    ${RED}║${NC}"
echo -e "${RED}║                                                     ║${NC}"
echo -e "${RED}═══════════════════════════════════════════════════════${NC}"
echo ""

# Set up trap to handle recording stop
trap 'echo -e "\n\n${GREEN}✓ Recording stopped${NC}\n"' INT

# Record using sox to temporary WAV file
TEMP_WAV="/tmp/audio_journal_temp_$$.wav"
sox -t coreaudio -d "$TEMP_WAV" silence 1 0.1 3% 1 120.0 3%

# Compress to m4a using ffmpeg
echo -e "${YELLOW}🔄 Compressing audio...${NC}"
ffmpeg -i "$TEMP_WAV" -c:a aac -b:a 64k -ar 22050 "$AUDIO_FILE" -y -loglevel error
rm -f "$TEMP_WAV"

echo -e "${GREEN}${BOLD}✅ Recording saved successfully!${NC}"
echo -e "${BLUE}📁 Audio file: $(basename "$AUDIO_FILE")${NC}"

# Define functions before using them

# Check if whisper is available
if ! command -v whisper &> /dev/null; then
    echo -e "${RED}Warning: whisper not found. Install with: python3 -m pip install openai-whisper${NC}"
    echo "Creating transcript file without transcription..."
    create_transcript_file_no_whisper
    update_sync_manifest
    exit 0
fi

# Transcribe with whisper
echo -e "${YELLOW}🔄 Transcribing...${NC}"
whisper "$AUDIO_FILE" \
    --model "$WHISPER_MODEL" \
    --output_format txt \
    --output_dir "$(dirname "$AUDIO_FILE")" \
    --verbose False \
    --fp16 False 2>/dev/null

# Create markdown transcript with metadata
create_transcript_file() {
    local txt_file="${AUDIO_FILE%.*}.txt"
    local audio_basename=$(basename "$AUDIO_FILE")
    local file_size=$(du -h "$AUDIO_FILE" | cut -f1)
    local duration=$(ffprobe -v quiet -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$AUDIO_FILE" 2>/dev/null | cut -d. -f1 || echo "unknown")
    
    cat > "$TRANSCRIPT_FILE" << EOF
# Audio Journal - $(date +"%B %d, %Y at %I:%M %p")

**Audio:** \`$audio_basename\` | **Duration:** ${duration}s | **Size:** $file_size  

---

## Transcript

$(cat "$txt_file" 2>/dev/null || echo "Transcription failed or not available")

---

## Notes

<!-- Add your thoughts, tags, or follow-up notes here -->

EOF

    # Clean up the raw txt file
    rm -f "$txt_file"
}

# Update sync manifest
update_sync_manifest() {
    local manifest="$JOURNAL_DIR/.sync/manifest.json"
    local year=$(date +"%Y")
    local entry_key="$year/$FILENAME"
    
    # Calculate file hashes
    local audio_hash=$(shasum -a 256 "$AUDIO_FILE" | cut -d' ' -f1)
    local transcript_hash=$(shasum -a 256 "$TRANSCRIPT_FILE" | cut -d' ' -f1)
    local audio_size=$(stat -f%z "$AUDIO_FILE" 2>/dev/null || stat -c%s "$AUDIO_FILE" 2>/dev/null || echo 0)
    local duration=$(ffprobe -v quiet -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$AUDIO_FILE" 2>/dev/null | cut -d. -f1 || echo 0)
    
    # Create or update manifest using jq if available, otherwise use simple format
    if command -v jq &> /dev/null; then
        if [ -f "$manifest" ]; then
            jq --arg key "$entry_key" \
               --arg audio_hash "$audio_hash" \
               --arg transcript_hash "$transcript_hash" \
               --arg audio_size "$audio_size" \
               --arg duration "$duration" \
               '.entries[$key] = {
                   "audio_hash": $audio_hash,
                   "audio_size": ($audio_size | tonumber),
                   "transcript_hash": $transcript_hash,
                   "duration": ($duration | tonumber),
                   "created": now | strftime("%Y-%m-%d %H:%M:%S"),
                   "synced": false
               }' "$manifest" > "$manifest.tmp" && mv "$manifest.tmp" "$manifest"
        else
            echo '{"entries": {}}' | \
            jq --arg key "$entry_key" \
               --arg audio_hash "$audio_hash" \
               --arg transcript_hash "$transcript_hash" \
               --arg audio_size "$audio_size" \
               --arg duration "$duration" \
               '.entries[$key] = {
                   "audio_hash": $audio_hash,
                   "audio_size": ($audio_size | tonumber),
                   "transcript_hash": $transcript_hash,
                   "duration": ($duration | tonumber),
                   "created": now | strftime("%Y-%m-%d %H:%M:%S"),
                   "synced": false
               }' > "$manifest"
        fi
    fi
}

create_transcript_file
update_sync_manifest

echo -e "${GREEN}${BOLD}✅ Transcript created successfully!${NC}"
echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${GREEN}         📝 JOURNAL ENTRY COMPLETE! 📝${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}📎 Files created:${NC}"
echo -e "   ${PURPLE}🎵 Audio:${NC} $(basename "$AUDIO_FILE")"
echo -e "   ${PURPLE}📄 Notes:${NC} $(basename "$TRANSCRIPT_FILE")"
echo ""
echo -e "${GREEN}${BOLD}Happy journaling! 🌟${NC}"
echo ""

# Optional: Open transcript in default editor
if [[ "$1" == "--edit" ]] || [[ "$1" == "-e" ]]; then
    ${EDITOR:-code} "$TRANSCRIPT_FILE"
fi

# Initialize git repo if not exists
if [ ! -d "$JOURNAL_DIR/.git" ] && command -v git &> /dev/null; then
    echo -e "${YELLOW}Initializing git repository for transcripts...${NC}"
    cd "$JOURNAL_DIR"
    git init -q
    echo "audio/" >> .gitignore
    echo ".DS_Store" >> .gitignore
    git add .gitignore
    git commit -q -m "Initial commit: Audio journal setup"
fi

# Auto-commit transcript if git is available
if [ -d "$JOURNAL_DIR/.git" ] && command -v git &> /dev/null; then
    cd "$JOURNAL_DIR"
    git add "$TRANSCRIPT_FILE"
    git add ".sync/manifest.json" 2>/dev/null || true
    git commit -q -m "Add journal entry: $FILENAME" || true
fi