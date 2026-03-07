#!/bin/bash

# Audio Journal Recording Script - Enhanced Version
# Records audio, transcribes with Whisper, organizes files
# Now with timestamps, paragraph breaks, and detailed metadata

set -e

# Configuration
JOURNAL_DIR="${JOURNAL_DIR:-$HOME/Documents/AudioJournal}"
AUDIO_FORMAT="${AUDIO_FORMAT:-m4a}"
WHISPER_MODEL="${WHISPER_MODEL:-base}"

# Determine transcription mode: API (fast) or local (free)
if [ -n "$OPENAI_API_KEY" ]; then
    TRANSCRIPTION_MODE="api"
elif command -v whisper &> /dev/null; then
    TRANSCRIPTION_MODE="local"
else
    TRANSCRIPTION_MODE="none"
fi

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
if [ "$TRANSCRIPTION_MODE" = "api" ]; then
    echo -e "${BLUE}🌐 Transcription:${NC} OpenAI Whisper API (fast)"
elif [ "$TRANSCRIPTION_MODE" = "local" ]; then
    echo -e "${BLUE}🌐 Transcription:${NC} Local whisper-$WHISPER_MODEL"
else
    echo -e "${YELLOW}⚠️  Transcription:${NC} Not available (set OPENAI_API_KEY or install whisper)"
fi
echo -e "${BLUE}📁 File:${NC} $FILENAME"
echo ""
echo -e "${CYAN}───────────────────────────────────────────────────────${NC}"
echo ""
echo -e "${GREEN}${BOLD}▶  Press ENTER to START recording${NC}"
echo -e "${YELLOW}   (then press CTRL+C to stop)${NC}"
echo ""
echo -e "${PURPLE}💡 Tip: Pause for 2+ seconds to create new paragraphs${NC}"
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
sox -t coreaudio -d "$TEMP_WAV" silence 1 0.1 1% 1 120.0 1%

# Compress to m4a using ffmpeg
echo -e "${YELLOW}🔄 Compressing audio...${NC}"
ffmpeg -i "$TEMP_WAV" -c:a aac -b:a 64k -ar 22050 "$AUDIO_FILE" -y -loglevel error
rm -f "$TEMP_WAV"

echo -e "${GREEN}${BOLD}✅ Recording saved successfully!${NC}"
echo -e "${BLUE}📁 Audio file: $(basename "$AUDIO_FILE")${NC}"

# Check if jq is available for JSON parsing
if ! command -v jq &> /dev/null; then
    echo -e "${RED}Warning: jq not found. Install with: brew install jq${NC}"
    echo -e "${YELLOW}Falling back to basic transcription without timestamps...${NC}"
    BASIC_MODE=true
else
    BASIC_MODE=false
fi

# Function to transcribe via OpenAI API
transcribe_via_api() {
    local audio_file="$1"
    local json_output="${audio_file%.*}.json"

    echo -e "${YELLOW}🔄 Transcribing via OpenAI API...${NC}"

    # Call OpenAI Whisper API with verbose_json for timestamps
    local response=$(curl -s -X POST "https://api.openai.com/v1/audio/transcriptions" \
        -H "Authorization: Bearer $OPENAI_API_KEY" \
        -H "Content-Type: multipart/form-data" \
        -F "file=@$audio_file" \
        -F "model=whisper-1" \
        -F "response_format=verbose_json" \
        -F "timestamp_granularities[]=segment")

    # Check for errors
    if echo "$response" | jq -e '.error' > /dev/null 2>&1; then
        local error_msg=$(echo "$response" | jq -r '.error.message')
        echo -e "${RED}API Error: $error_msg${NC}"
        return 1
    fi

    # Save response to JSON file (same format as local whisper)
    echo "$response" > "$json_output"
    return 0
}

# Function to transcribe via local whisper
transcribe_via_local() {
    local audio_file="$1"

    echo -e "${YELLOW}🔄 Transcribing via local whisper ($WHISPER_MODEL model)...${NC}"

    if [ "$BASIC_MODE" = false ]; then
        whisper "$audio_file" \
            --model "$WHISPER_MODEL" \
            --output_format json \
            --output_dir "$(dirname "$audio_file")" \
            --verbose False \
            --fp16 False 2>/dev/null
    else
        whisper "$audio_file" \
            --model "$WHISPER_MODEL" \
            --output_format txt \
            --output_dir "$(dirname "$audio_file")" \
            --verbose False \
            --fp16 False 2>/dev/null
    fi
}

# Perform transcription based on available method
if [ "$TRANSCRIPTION_MODE" = "api" ]; then
    if ! transcribe_via_api "$AUDIO_FILE"; then
        echo -e "${YELLOW}API transcription failed, trying local whisper...${NC}"
        if command -v whisper &> /dev/null; then
            transcribe_via_local "$AUDIO_FILE"
        else
            echo -e "${RED}No fallback available. Transcript will be empty.${NC}"
            BASIC_MODE=true
        fi
    fi
elif [ "$TRANSCRIPTION_MODE" = "local" ]; then
    transcribe_via_local "$AUDIO_FILE"
else
    echo -e "${YELLOW}No transcription method available.${NC}"
    echo -e "${BLUE}To enable transcription, either:${NC}"
    echo -e "  1. Set OPENAI_API_KEY for fast cloud transcription"
    echo -e "  2. Install local whisper: pip install openai-whisper"
    BASIC_MODE=true
fi

# Function to format seconds to MM:SS
format_time() {
    local total_seconds=$1
    local minutes=$((total_seconds / 60))
    local seconds=$((total_seconds % 60))
    printf "%02d:%02d" $minutes $seconds
}

# Function to process JSON transcription with timestamps
process_json_transcription() {
    local json_file="${AUDIO_FILE%.*}.json"
    local output=""
    local last_minute=0
    local word_count=0
    local total_confidence=0
    local segment_count=0
    local low_confidence_count=0
    local paragraph_breaks=0
    
    if [ ! -f "$json_file" ]; then
        echo "Transcription failed or not available"
        return 1
    fi
    
    # Extract language and segments
    local language=$(jq -r '.language' "$json_file")
    local segments=$(jq -c '.segments[]' "$json_file")
    
    # Process each segment
    while IFS= read -r segment; do
        local start_time=$(echo "$segment" | jq -r '.start')
        local end_time=$(echo "$segment" | jq -r '.end')
        local text=$(echo "$segment" | jq -r '.text')
        local avg_logprob=$(echo "$segment" | jq -r '.avg_logprob')
        
        # Calculate confidence (convert log probability to percentage)
        local confidence=$(echo "scale=2; e($avg_logprob) * 100" | bc -l 2>/dev/null || echo "0")
        
        # Track statistics
        total_confidence=$(echo "$total_confidence + $confidence" | bc -l)
        segment_count=$((segment_count + 1))
        
        # Count words
        local segment_words=$(echo "$text" | wc -w)
        word_count=$((word_count + segment_words))
        
        # Mark low confidence segments
        if (( $(echo "$confidence < 80" | bc -l) )); then
            low_confidence_count=$((low_confidence_count + 1))
            text="$text*"
        fi
        
        # Add minute markers
        local current_minute=$(echo "$start_time / 60" | bc)
        if [ $current_minute -gt $last_minute ]; then
            for ((i=$last_minute+1; i<=current_minute; i++)); do
                output+="\n[$(format_time $((i*60)))] "
            done
            last_minute=$current_minute
        fi
        
        # Add text with potential paragraph break
        # Check if there's a significant time gap (2+ seconds)
        if [ -n "$prev_end_time" ]; then
            local gap=$(echo "$start_time - $prev_end_time" | bc -l)
            if (( $(echo "$gap > 2.0" | bc -l) )); then
                output+="\n\n"
                paragraph_breaks=$((paragraph_breaks + 1))
            fi
        fi
        
        output+="$text "
        prev_end_time=$end_time
    done <<< "$segments"
    
    # Calculate averages
    local avg_confidence=$(echo "scale=1; $total_confidence / $segment_count" | bc -l)
    
    # Get audio duration
    local duration=$(jq -r '.segments[-1].end' "$json_file")
    local duration_formatted=$(format_time ${duration%.*})
    
    # Clean up JSON file
    rm -f "$json_file"
    
    # Return the formatted transcription and metadata
    echo "TRANSCRIPT:$output"
    echo "LANGUAGE:$language"
    echo "WORD_COUNT:$word_count"
    echo "DURATION:$duration_formatted"
    echo "AVG_CONFIDENCE:$avg_confidence"
    echo "LOW_CONFIDENCE:$low_confidence_count"
    echo "PARAGRAPHS:$((paragraph_breaks + 1))"
}

# Function to create basic transcript without JSON parsing
create_basic_transcript() {
    local txt_file="${AUDIO_FILE%.*}.txt"
    local content=$(cat "$txt_file" 2>/dev/null || echo "Transcription failed or not available")
    local word_count=$(echo "$content" | wc -w)
    local duration=$(ffprobe -v quiet -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$AUDIO_FILE" 2>/dev/null | cut -d. -f1 || echo "0")
    local duration_formatted=$(format_time $duration)
    
    echo "TRANSCRIPT:[00:00] $content"
    echo "LANGUAGE:unknown"
    echo "WORD_COUNT:$word_count"
    echo "DURATION:$duration_formatted"
    echo "AVG_CONFIDENCE:N/A"
    echo "LOW_CONFIDENCE:0"
    echo "PARAGRAPHS:1"
    
    rm -f "$txt_file"
}

# Create transcript file without transcription (fallback)
create_transcript_file_no_whisper() {
    local audio_basename=$(basename "$AUDIO_FILE")
    local file_size=$(du -h "$AUDIO_FILE" | cut -f1)
    local duration=$(ffprobe -v quiet -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$AUDIO_FILE" 2>/dev/null | cut -d. -f1 || echo "0")
    local duration_formatted=$(format_time $duration)

    cat > "$TRANSCRIPT_FILE" << EOF
# Audio Journal - $(date +"%B %d, %Y at %I:%M %p")

**Audio:** \`$audio_basename\` | **Duration:** $duration_formatted | **Size:** $file_size

---

## Transcript

*Transcription not available. To enable:*
- Set \`OPENAI_API_KEY\` for fast cloud transcription, or
- Install local whisper: \`pip install openai-whisper\`

---

## Notes

<!-- Add your thoughts, tags, or follow-up notes here -->

EOF
}

# Create markdown transcript with metadata
create_transcript_file() {
    local audio_basename=$(basename "$AUDIO_FILE")
    local file_size=$(du -h "$AUDIO_FILE" | cut -f1)
    
    # Get transcription data
    local transcription_data
    if [ "$BASIC_MODE" = false ]; then
        transcription_data=$(process_json_transcription)
    else
        transcription_data=$(create_basic_transcript)
    fi
    
    # Parse the transcription data
    local transcript=$(echo "$transcription_data" | grep "^TRANSCRIPT:" | cut -d: -f2-)
    local language=$(echo "$transcription_data" | grep "^LANGUAGE:" | cut -d: -f2)
    local word_count=$(echo "$transcription_data" | grep "^WORD_COUNT:" | cut -d: -f2)
    local duration=$(echo "$transcription_data" | grep "^DURATION:" | cut -d: -f2)
    local avg_confidence=$(echo "$transcription_data" | grep "^AVG_CONFIDENCE:" | cut -d: -f2)
    local low_confidence=$(echo "$transcription_data" | grep "^LOW_CONFIDENCE:" | cut -d: -f2)
    local paragraphs=$(echo "$transcription_data" | grep "^PARAGRAPHS:" | cut -d: -f2)
    
    # Format language display
    local language_display=$(echo "$language" | sed 's/^./\U&/')
    if [ "$avg_confidence" != "N/A" ]; then
        language_display="$language_display (${avg_confidence}% confidence)"
    fi
    
    cat > "$TRANSCRIPT_FILE" << EOF
# Audio Journal - $(date +"%B %d, %Y at %I:%M %p")

**Audio:** \`$audio_basename\` | **Duration:** $duration | **Size:** $file_size  

---

## Transcript

$transcript

---

## Metadata

- **Words:** $word_count
- **Duration:** $duration
- **Language:** $language_display
- **Paragraphs:** $paragraphs
- **Average Confidence:** ${avg_confidence}%
- **Low Confidence Segments:** $low_confidence$([ "$low_confidence" -gt 0 ] && echo " (marked with *)")
- **Model:** $([ "$TRANSCRIPTION_MODE" = "api" ] && echo "OpenAI Whisper API" || echo "whisper-$WHISPER_MODEL")

---

## Notes

<!-- Add your thoughts, tags, or follow-up notes here -->

EOF
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

# Create transcript based on what's available
JSON_FILE="${AUDIO_FILE%.*}.json"
TXT_FILE="${AUDIO_FILE%.*}.txt"

if [ -f "$JSON_FILE" ]; then
    # JSON transcription available (API or local with jq)
    BASIC_MODE=false
    create_transcript_file
elif [ -f "$TXT_FILE" ]; then
    # Text-only transcription available
    BASIC_MODE=true
    create_transcript_file
else
    # No transcription available
    create_transcript_file_no_whisper
fi

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
if [ -f "$JSON_FILE" ] || [ -f "$TXT_FILE" ]; then
    echo -e "${GREEN}✨ Features in this recording:${NC}"
    if [ -f "$JSON_FILE" ]; then
        echo -e "   • Minute-by-minute timestamps"
        echo -e "   • Automatic paragraph breaks on pauses"
        echo -e "   • Word count and confidence metrics"
    else
        echo -e "   • Basic transcription"
    fi
fi
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