#!/bin/bash

# Audio Journal Search Script
# Search through transcripts and play associated audio

set -e

JOURNAL_DIR="${JOURNAL_DIR:-$HOME/Documents/AudioJournal}"
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Function to display usage
show_usage() {
    echo "Usage: $0 [search_term] [options]"
    echo ""
    echo "Search through your audio journal transcripts"
    echo ""
    echo "Options:"
    echo "  -l, --limit N        Limit results to N entries (default: 20)"
    echo "  -v, --verbose        Show more context around matches"
    echo "  -a, --audio          Play audio file instead of opening transcript"
    echo "  -y, --year YYYY      Search only in specific year"
    echo ""
    echo "Examples:"
    echo "  $0                   # List all entries"
    echo "  $0 'morning routine' # Search for term"
    echo "  $0 meeting -l 5      # Show 5 most recent matches"
    echo "  $0 -y 2025           # Show all 2025 entries"
    exit 1
}

# Default values
SEARCH_TERM=""
LIMIT=20
VERBOSE=false
PLAY_AUDIO=false
YEAR_FILTER=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_usage
            ;;
        -l|--limit)
            LIMIT="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -a|--audio)
            PLAY_AUDIO=true
            shift
            ;;
        -y|--year)
            YEAR_FILTER="$2"
            shift 2
            ;;
        -*)
            echo "Unknown option: $1"
            show_usage
            ;;
        *)
            SEARCH_TERM="$1"
            shift
            ;;
    esac
done

# Determine search path
if [[ -n "$YEAR_FILTER" ]]; then
    SEARCH_PATH="$JOURNAL_DIR/transcripts/$YEAR_FILTER"
    if [[ ! -d "$SEARCH_PATH" ]]; then
        echo -e "${YELLOW}No entries found for year $YEAR_FILTER${NC}"
        exit 0
    fi
else
    SEARCH_PATH="$JOURNAL_DIR/transcripts"
fi

# Find transcript files
echo -e "${GREEN}Searching in: $SEARCH_PATH${NC}"
if [[ -n "$SEARCH_TERM" ]]; then
    echo -e "${GREEN}Search term: '$SEARCH_TERM'${NC}"
fi
echo ""

# Build find command
FIND_CMD="find \"$SEARCH_PATH\" -name \"*.md\" -type f"
if [[ ! -d "$SEARCH_PATH" ]]; then
    echo -e "${YELLOW}Journal directory not found: $SEARCH_PATH${NC}"
    echo "Run ./setup.sh to initialize"
    exit 1
fi

# Get all markdown files, sorted by newest first
mapfile -t ALL_FILES < <(eval "$FIND_CMD" | sort -r)

# Filter by search term if provided
MATCHES=()
if [[ -n "$SEARCH_TERM" ]]; then
    for file in "${ALL_FILES[@]}"; do
        if grep -qi "$SEARCH_TERM" "$file" 2>/dev/null; then
            MATCHES+=("$file")
        fi
    done
else
    MATCHES=("${ALL_FILES[@]}")
fi

# Apply limit
if [[ ${#MATCHES[@]} -gt $LIMIT ]]; then
    MATCHES=("${MATCHES[@]:0:$LIMIT}")
fi

# Display results
if [[ ${#MATCHES[@]} -eq 0 ]]; then
    if [[ -n "$SEARCH_TERM" ]]; then
        echo -e "${YELLOW}No matches found for '$SEARCH_TERM'${NC}"
    else
        echo -e "${YELLOW}No journal entries found${NC}"
    fi
    exit 0
fi

echo -e "${GREEN}Found ${#MATCHES[@]} entries:${NC}"
echo ""

# Display each match
for i in "${!MATCHES[@]}"; do
    file="${MATCHES[$i]}"
    
    # Extract date from new filename format
    basename_file=$(basename "$file" .md)
    year=$(basename "$(dirname "$file")")
    
    # Parse filename like JAN_28_07.05
    if [[ $basename_file =~ ^([A-Z]{3})_([0-9]{2})_([0-9]{2})\.([0-9]{2})$ ]]; then
        month="${BASH_REMATCH[1]}"
        day="${BASH_REMATCH[2]}"
        hour="${BASH_REMATCH[3]}"
        minute="${BASH_REMATCH[4]}"
        formatted_date="$month $day, $year at $hour:$minute"
    else
        formatted_date="$basename_file"
    fi
    
    echo -e "${BLUE}[$((i+1))] $formatted_date${NC}"
    echo -e "    File: $(basename "$file")"
    
    # Show context if search term provided
    if [[ -n "$SEARCH_TERM" ]]; then
        if [[ "$VERBOSE" == true ]]; then
            context=$(grep -i -A3 -B3 "$SEARCH_TERM" "$file" 2>/dev/null | head -10)
        else
            context=$(grep -i -m1 "$SEARCH_TERM" "$file" 2>/dev/null)
        fi
        if [[ -n "$context" ]]; then
            echo -e "${YELLOW}    Match:${NC}"
            echo "$context" | sed 's/^/      /'
        fi
    else
        # Show first line of transcript when no search term
        first_line=$(grep -m1 "^[^#]" "$file" 2>/dev/null | head -1)
        if [[ -n "$first_line" ]]; then
            echo "    Preview: ${first_line:0:60}..."
        fi
    fi
    echo ""
done

# Interactive selection
if [[ ${#MATCHES[@]} -eq 1 ]]; then
    selected_file="${MATCHES[0]}"
    if [[ "$PLAY_AUDIO" == true ]]; then
        action="play"
    else
        action="open"
    fi
else
    echo -n "Select entry (1-${#MATCHES[@]}), 'q' to quit: "
    read -r selection
    
    if [[ "$selection" == "q" ]] || [[ -z "$selection" ]]; then
        exit 0
    elif [[ "$selection" =~ ^[0-9]+$ ]] && [[ $selection -ge 1 ]] && [[ $selection -le ${#MATCHES[@]} ]]; then
        selected_file="${MATCHES[$((selection-1))]}"
        
        if [[ "$PLAY_AUDIO" != true ]]; then
            echo -n "Open (t)ranscript or play (a)udio? [t/a]: "
            read -r action_choice
            if [[ "$action_choice" == "a" ]]; then
                action="play"
            else
                action="open"
            fi
        else
            action="play"
        fi
    else
        echo -e "${YELLOW}Invalid selection${NC}"
        exit 1
    fi
fi

# Perform action
if [[ "$action" == "play" ]]; then
    # Find associated audio file in audio directory
    basename_file=$(basename "$selected_file" .md)
    year=$(basename "$(dirname "$selected_file")")
    audio_file="$JOURNAL_DIR/audio/$year/${basename_file}.m4a"
    
    # Check for other audio formats if m4a not found
    if [[ ! -f "$audio_file" ]]; then
        audio_file="$JOURNAL_DIR/audio/$year/${basename_file}.wav"
    fi
    
    if [[ -f "$audio_file" ]]; then
        echo -e "${GREEN}Playing: $(basename "$audio_file")${NC}"
        if command -v afplay &> /dev/null; then
            afplay "$audio_file"
        elif command -v mpv &> /dev/null; then
            mpv "$audio_file"
        elif command -v ffplay &> /dev/null; then
            ffplay -nodisp -autoexit "$audio_file" 2>/dev/null
        else
            echo "Opening in default application..."
            open "$audio_file"
        fi
    else
        echo -e "${YELLOW}Audio file not found${NC}"
        echo "Expected: $audio_file"
    fi
else
    echo -e "${GREEN}Opening: $(basename "$selected_file")${NC}"
    ${EDITOR:-open} "$selected_file"
fi