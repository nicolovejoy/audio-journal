#!/bin/bash

# Audio Journal Search Script
# Search through transcripts and play associated audio

set -e

JOURNAL_DIR="${JOURNAL_DIR:-$HOME/audio_journal}"
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

if [ $# -eq 0 ]; then
    echo "Usage: $0 <search_term> [options]"
    echo ""
    echo "Options:"
    echo "  --recent N    Show only last N entries (default: all)"
    echo "  --date YYYY-MM-DD    Show entries from specific date"
    echo "  --play        Auto-play first match"
    echo ""
    echo "Examples:"
    echo "  $0 'morning routine'"
    echo "  $0 project --recent 7"
    echo "  $0 'book idea' --date 2025-07-20"
    exit 1
fi

SEARCH_TERM="$1"
shift

# Parse options
RECENT=""
DATE_FILTER=""
AUTO_PLAY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --recent)
            RECENT="$2"
            shift 2
            ;;
        --date)
            DATE_FILTER="$2"
            shift 2
            ;;
        --play)
            AUTO_PLAY=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Find matching transcript files
if [[ -n "$DATE_FILTER" ]]; then
    # Convert YYYY-MM-DD to search pattern
    DATE_PATTERN=$(echo "$DATE_FILTER" | sed 's/-//g')
    SEARCH_PATH="$JOURNAL_DIR"
    FIND_CMD="find \"$SEARCH_PATH\" -name \"journal_${DATE_PATTERN}_*.md\""
else
    FIND_CMD="find \"$JOURNAL_DIR\" -name \"*.md\" -type f"
fi

# Apply recent filter
if [[ -n "$RECENT" ]]; then
    FIND_CMD="$FIND_CMD | head -$RECENT"
fi

# Search for term in files
echo -e "${GREEN}Searching for: '$SEARCH_TERM'${NC}"
echo ""

MATCHES=()
while IFS= read -r -d '' file; do
    if grep -qi "$SEARCH_TERM" "$file"; then
        MATCHES+=("$file")
    fi
done < <(eval "$FIND_CMD" -print0 2>/dev/null)

if [[ ${#MATCHES[@]} -eq 0 ]]; then
    echo -e "${YELLOW}No matches found for '$SEARCH_TERM'${NC}"
    exit 0
fi

# Display results
echo -e "${GREEN}Found ${#MATCHES[@]} matches:${NC}"
echo ""

for i in "${!MATCHES[@]}"; do
    file="${MATCHES[$i]}"
    
    # Extract date from filename
    basename_file=$(basename "$file")
    if [[ $basename_file =~ journal_([0-9]{8})_([0-9]{6})\.md ]]; then
        date_part="${BASH_REMATCH[1]}"
        time_part="${BASH_REMATCH[2]}"
        formatted_date=$(date -j -f "%Y%m%d" "$date_part" +"%B %d, %Y" 2>/dev/null || echo "$date_part")
        formatted_time="${time_part:0:2}:${time_part:2:2}:${time_part:4:2}"
    else
        formatted_date="Unknown date"
        formatted_time=""
    fi
    
    # Show context around match
    context=$(grep -i -A2 -B2 "$SEARCH_TERM" "$file" | head -5)
    
    echo -e "${BLUE}[$((i+1))] $formatted_date $formatted_time${NC}"
    echo -e "${YELLOW}Context:${NC}"
    echo "$context" | sed 's/^/  /'
    echo ""
done

# Interactive selection
if [[ ${#MATCHES[@]} -gt 1 ]] && [[ "$AUTO_PLAY" != true ]]; then
    echo -n "Select entry to open (1-${#MATCHES[@]}), 'a' for audio, or Enter to exit: "
    read -r selection
    
    if [[ "$selection" =~ ^[0-9]+$ ]] && [[ $selection -ge 1 ]] && [[ $selection -le ${#MATCHES[@]} ]]; then
        selected_file="${MATCHES[$((selection-1))]}"
    elif [[ "$selection" == "a" ]]; then
        echo -n "Select entry for audio (1-${#MATCHES[@]}): "
        read -r audio_selection
        if [[ "$audio_selection" =~ ^[0-9]+$ ]] && [[ $audio_selection -ge 1 ]] && [[ $audio_selection -le ${#MATCHES[@]} ]]; then
            selected_file="${MATCHES[$((audio_selection-1))]}"
            play_audio=true
        fi
    else
        exit 0
    fi
else
    selected_file="${MATCHES[0]}"
fi

# Open selected file or play audio
if [[ "$play_audio" == true ]] || [[ "$AUTO_PLAY" == true ]]; then
    # Find associated audio file
    transcript_dir=$(dirname "$selected_file")
    transcript_name=$(basename "$selected_file" .md)
    audio_file="$transcript_dir/${transcript_name}.wav"
    
    # Also check for m4a if wav not found (for backward compatibility)
    if [[ ! -f "$audio_file" ]]; then
        audio_file="$transcript_dir/${transcript_name}.m4a"
    fi
    
    if [[ -f "$audio_file" ]]; then
        echo -e "${GREEN}Playing: $(basename "$audio_file")${NC}"
        if command -v afplay &> /dev/null; then
            afplay "$audio_file"
        elif command -v mpv &> /dev/null; then
            mpv "$audio_file"
        else
            echo "No audio player found. Install afplay or mpv."
            open "$audio_file"  # Fallback to system default
        fi
    else
        echo -e "${YELLOW}Audio file not found: $audio_file${NC}"
    fi
else
    echo -e "${GREEN}Opening: $(basename "$selected_file")${NC}"
    ${EDITOR:-code} "$selected_file"
fi