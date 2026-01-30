#!/bin/bash

# Process Existing Audio Files Script
# Transcribes existing audio files with enhanced features
# Preserves original recording date while noting processing date

set -e

# Configuration
JOURNAL_DIR="${JOURNAL_DIR:-$HOME/Documents/AudioJournal}"
WHISPER_MODEL="${WHISPER_MODEL:-base}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Function to display usage
usage() {
    echo "Usage: $0 [OPTIONS] <audio_file(s)>"
    echo ""
    echo "Process existing audio files with enhanced transcription features."
    echo ""
    echo "Options:"
    echo "  -h, --help           Show this help message"
    echo "  -m, --model MODEL    Whisper model to use (default: base)"
    echo "  -d, --date DATE      Override recording date (format: YYYY-MM-DD HH:MM)"
    echo "  -b, --batch          Process all audio files in a directory"
    echo "  -f, --force          Overwrite existing transcripts"
    echo ""
    echo "Examples:"
    echo "  $0 recording.m4a"
    echo "  $0 -d '2024-12-25 14:30' old_recording.wav"
    echo "  $0 -b ~/Downloads/audio_files/"
    echo "  $0 *.m4a"
    exit 1
}

# Function to format seconds to MM:SS
format_time() {
    local total_seconds=$1
    local minutes=$((total_seconds / 60))
    local seconds=$((total_seconds % 60))
    printf "%02d:%02d" $minutes $seconds
}

# Function to get file creation date
get_file_date() {
    local file="$1"
    local override_date="$2"
    
    if [ -n "$override_date" ]; then
        # Use override date if provided
        echo "$override_date"
    else
        # Try to get from file metadata first
        local metadata_date=$(ffprobe -v quiet -show_entries format_tags=creation_time -of default=noprint_wrappers=1:nokey=1 "$file" 2>/dev/null)
        
        if [ -n "$metadata_date" ]; then
            # Convert metadata date to our format
            date -j -f "%Y-%m-%dT%H:%M:%S" "${metadata_date%.*}" "+%Y-%m-%d %H:%M" 2>/dev/null || \
            date -d "${metadata_date%.*}" "+%Y-%m-%d %H:%M" 2>/dev/null || \
            echo ""
        else
            # Fall back to file modification time
            if [[ "$OSTYPE" == "darwin"* ]]; then
                stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$file"
            else
                stat -c "%y" "$file" | cut -d' ' -f1,2 | cut -d'.' -f1
            fi
        fi
    fi
}

# Function to generate filename from date
generate_filename() {
    local date_str="$1"
    # Parse date and format as MON_DD_HH.MM
    local month=$(date -j -f "%Y-%m-%d %H:%M" "$date_str" "+%b" 2>/dev/null || date -d "$date_str" "+%b" 2>/dev/null)
    local day_time=$(date -j -f "%Y-%m-%d %H:%M" "$date_str" "+%d_%H.%M" 2>/dev/null || date -d "$date_str" "+%d_%H.%M" 2>/dev/null)
    echo "${month^^}_${day_time}"
}

# Function to process JSON transcription with timestamps
process_json_transcription() {
    local json_file="$1"
    local output=""
    local last_minute=0
    local word_count=0
    local total_confidence=0
    local segment_count=0
    local low_confidence_count=0
    local paragraph_breaks=0
    local prev_end_time=""
    
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
    local duration=$(jq -r '.segments[-1].end' "$json_file" 2>/dev/null || echo "0")
    local duration_formatted=$(format_time ${duration%.*})
    
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
    local txt_file="$1"
    local audio_file="$2"
    local content=$(cat "$txt_file" 2>/dev/null || echo "Transcription failed or not available")
    local word_count=$(echo "$content" | wc -w)
    local duration=$(ffprobe -v quiet -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$audio_file" 2>/dev/null | cut -d. -f1 || echo "0")
    local duration_formatted=$(format_time $duration)
    
    echo "TRANSCRIPT:[00:00] $content"
    echo "LANGUAGE:unknown"
    echo "WORD_COUNT:$word_count"
    echo "DURATION:$duration_formatted"
    echo "AVG_CONFIDENCE:N/A"
    echo "LOW_CONFIDENCE:0"
    echo "PARAGRAPHS:1"
}

# Function to process a single audio file
process_audio_file() {
    local input_file="$1"
    local override_date="$2"
    local force_overwrite="$3"
    
    # Check if file exists
    if [ ! -f "$input_file" ]; then
        echo -e "${RED}Error: File not found: $input_file${NC}"
        return 1
    fi
    
    echo -e "\n${CYAN}Processing: ${BOLD}$(basename "$input_file")${NC}"
    
    # Get recording date
    local recording_date=$(get_file_date "$input_file" "$override_date")
    local year=$(date -j -f "%Y-%m-%d %H:%M" "$recording_date" "+%Y" 2>/dev/null || date -d "$recording_date" "+%Y" 2>/dev/null)
    
    # Generate filename
    local filename=$(generate_filename "$recording_date")
    
    echo -e "${BLUE}📅 Recording date:${NC} $recording_date"
    echo -e "${BLUE}📁 Output filename:${NC} $filename"
    
    # Set up directories
    local audio_dir="$JOURNAL_DIR/audio/$year"
    local transcript_dir="$JOURNAL_DIR/transcripts/$year"
    mkdir -p "$audio_dir"
    mkdir -p "$transcript_dir"
    
    # Define output files
    local audio_output="$audio_dir/${filename}.m4a"
    local transcript_output="$transcript_dir/${filename}.md"
    
    # Check if transcript already exists
    if [ -f "$transcript_output" ] && [ "$force_overwrite" != "true" ]; then
        echo -e "${YELLOW}⚠️  Transcript already exists. Use -f to overwrite.${NC}"
        return 1
    fi
    
    # Copy or convert audio file
    if [[ "${input_file##*.}" == "m4a" ]]; then
        echo -e "${YELLOW}📋 Copying audio file...${NC}"
        cp "$input_file" "$audio_output"
    else
        echo -e "${YELLOW}🔄 Converting to m4a...${NC}"
        ffmpeg -i "$input_file" -c:a aac -b:a 64k -ar 22050 "$audio_output" -y -loglevel error
    fi
    
    # Transcribe with whisper
    echo -e "${YELLOW}🔄 Transcribing with Whisper...${NC}"
    
    # Use JSON output if jq is available
    if command -v jq &> /dev/null; then
        whisper "$audio_output" \
            --model "$WHISPER_MODEL" \
            --output_format json \
            --output_dir "$(dirname "$audio_output")" \
            --verbose False \
            --fp16 False 2>/dev/null
        
        local transcription_data=$(process_json_transcription "${audio_output%.*}.json")
        rm -f "${audio_output%.*}.json"
    else
        whisper "$audio_output" \
            --model "$WHISPER_MODEL" \
            --output_format txt \
            --output_dir "$(dirname "$audio_output")" \
            --verbose False \
            --fp16 False 2>/dev/null
        
        local transcription_data=$(create_basic_transcript "${audio_output%.*}.txt" "$audio_output")
        rm -f "${audio_output%.*}.txt"
    fi
    
    # Parse transcription data
    local transcript=$(echo "$transcription_data" | grep "^TRANSCRIPT:" | cut -d: -f2-)
    local language=$(echo "$transcription_data" | grep "^LANGUAGE:" | cut -d: -f2)
    local word_count=$(echo "$transcription_data" | grep "^WORD_COUNT:" | cut -d: -f2)
    local duration=$(echo "$transcription_data" | grep "^DURATION:" | cut -d: -f2)
    local avg_confidence=$(echo "$transcription_data" | grep "^AVG_CONFIDENCE:" | cut -d: -f2)
    local low_confidence=$(echo "$transcription_data" | grep "^LOW_CONFIDENCE:" | cut -d: -f2)
    local paragraphs=$(echo "$transcription_data" | grep "^PARAGRAPHS:" | cut -d: -f2)
    
    # Get file info
    local file_size=$(du -h "$audio_output" | cut -f1)
    local audio_basename=$(basename "$audio_output")
    
    # Format dates
    local recording_date_formatted=$(date -j -f "%Y-%m-%d %H:%M" "$recording_date" "+%B %d, %Y at %I:%M %p" 2>/dev/null || \
                                    date -d "$recording_date" "+%B %d, %Y at %I:%M %p" 2>/dev/null)
    local processing_date=$(date "+%B %d, %Y at %I:%M %p")
    
    # Format language display
    local language_display=$(echo "$language" | sed 's/^./\U&/')
    if [ "$avg_confidence" != "N/A" ]; then
        language_display="$language_display (${avg_confidence}% confidence)"
    fi
    
    # Create transcript file
    cat > "$transcript_output" << EOF
# Audio Journal - $recording_date_formatted

**Audio:** \`$audio_basename\` | **Duration:** $duration | **Size:** $file_size  
**Processed:** $processing_date

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
- **Model:** whisper-$WHISPER_MODEL
- **Original File:** $(basename "$input_file")
- **Recording Date:** $recording_date_formatted
- **Processing Date:** $processing_date

---

## Notes

<!-- Add your thoughts, tags, or follow-up notes here -->

EOF

    echo -e "${GREEN}✅ Successfully processed!${NC}"
    echo -e "   ${PURPLE}🎵 Audio:${NC} $audio_basename"
    echo -e "   ${PURPLE}📄 Transcript:${NC} $(basename "$transcript_output")"
    
    # Update sync manifest
    update_sync_manifest "$year" "$filename" "$audio_output" "$transcript_output"
    
    # Git commit if available
    if [ -d "$JOURNAL_DIR/.git" ] && command -v git &> /dev/null; then
        cd "$JOURNAL_DIR"
        git add "$transcript_output"
        git add ".sync/manifest.json" 2>/dev/null || true
        git commit -q -m "Process existing recording: $filename (recorded: $recording_date)" || true
    fi
}

# Function to update sync manifest
update_sync_manifest() {
    local year="$1"
    local filename="$2"
    local audio_file="$3"
    local transcript_file="$4"
    local manifest="$JOURNAL_DIR/.sync/manifest.json"
    local entry_key="$year/$filename"
    
    mkdir -p "$JOURNAL_DIR/.sync"
    
    # Calculate file hashes
    local audio_hash=$(shasum -a 256 "$audio_file" | cut -d' ' -f1)
    local transcript_hash=$(shasum -a 256 "$transcript_file" | cut -d' ' -f1)
    local audio_size=$(stat -f%z "$audio_file" 2>/dev/null || stat -c%s "$audio_file" 2>/dev/null || echo 0)
    local duration=$(ffprobe -v quiet -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$audio_file" 2>/dev/null | cut -d. -f1 || echo 0)
    
    # Update manifest with jq if available
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
                   "synced": false,
                   "reprocessed": true
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
                   "synced": false,
                   "reprocessed": true
               }' > "$manifest"
        fi
    fi
}

# Main script

# Check dependencies
if ! command -v whisper &> /dev/null; then
    echo -e "${RED}Error: whisper not found. Install with: python3 -m pip install openai-whisper${NC}"
    exit 1
fi

if ! command -v ffmpeg &> /dev/null; then
    echo -e "${RED}Error: ffmpeg not found. Install with: brew install ffmpeg${NC}"
    exit 1
fi

# Parse command line arguments
OVERRIDE_DATE=""
BATCH_MODE=false
FORCE_OVERWRITE=false
FILES=()

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            ;;
        -m|--model)
            WHISPER_MODEL="$2"
            shift 2
            ;;
        -d|--date)
            OVERRIDE_DATE="$2"
            shift 2
            ;;
        -b|--batch)
            BATCH_MODE=true
            shift
            ;;
        -f|--force)
            FORCE_OVERWRITE=true
            shift
            ;;
        *)
            FILES+=("$1")
            shift
            ;;
    esac
done

# Check if files were provided
if [ ${#FILES[@]} -eq 0 ]; then
    echo -e "${RED}Error: No audio files specified${NC}"
    usage
fi

# Process files
echo -e "${CYAN}${BOLD}🎙️  AUDIO JOURNAL - PROCESS EXISTING FILES${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}📂 Output directory:${NC} $JOURNAL_DIR"
echo -e "${BLUE}🤖 Whisper model:${NC} $WHISPER_MODEL"

if [ "$BATCH_MODE" = true ]; then
    # Process directory
    BATCH_DIR="${FILES[0]}"
    if [ ! -d "$BATCH_DIR" ]; then
        echo -e "${RED}Error: Directory not found: $BATCH_DIR${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}📁 Batch processing:${NC} $BATCH_DIR"
    echo ""
    
    # Find all audio files
    shopt -s nullglob
    audio_files=("$BATCH_DIR"/*.{wav,mp3,m4a,flac,ogg,opus,webm})
    shopt -u nullglob
    
    if [ ${#audio_files[@]} -eq 0 ]; then
        echo -e "${RED}No audio files found in directory${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}Found ${#audio_files[@]} audio file(s)${NC}"
    
    # Process each file
    for file in "${audio_files[@]}"; do
        if [ -f "$file" ]; then
            process_audio_file "$file" "$OVERRIDE_DATE" "$FORCE_OVERWRITE"
        fi
    done
else
    # Process individual files
    for file in "${FILES[@]}"; do
        # Handle wildcards
        if [[ "$file" == *"*"* ]]; then
            shopt -s nullglob
            expanded_files=($file)
            shopt -u nullglob
            
            for expanded_file in "${expanded_files[@]}"; do
                process_audio_file "$expanded_file" "$OVERRIDE_DATE" "$FORCE_OVERWRITE"
            done
        else
            process_audio_file "$file" "$OVERRIDE_DATE" "$FORCE_OVERWRITE"
        fi
    done
fi

echo ""
echo -e "${GREEN}${BOLD}✅ Processing complete!${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"