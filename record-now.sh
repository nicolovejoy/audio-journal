#!/bin/bash

# Live Audio Journal Recording Script
# Real-time transcription with paragraph marking

set -e

# Configuration
JOURNAL_DIR="${JOURNAL_DIR:-$HOME/Documents/AudioJournal}"
WHISPER_MODEL="${WHISPER_MODEL:-base}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Check for Python 3
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}Error: Python 3 is required${NC}"
    echo "Install with: brew install python3"
    exit 1
fi

# Check dependencies
check_dependency() {
    if ! command -v "$1" &> /dev/null; then
        echo -e "${RED}Error: $1 not found${NC}"
        echo "Install with: $2"
        exit 1
    fi
}

check_dependency "sox" "brew install sox"
check_dependency "ffmpeg" "brew install ffmpeg"
check_dependency "whisper" "pip install openai-whisper"

# Clear screen and show interface
clear
echo ""
echo -e "${CYAN}${BOLD}╔═══════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}${BOLD}║                                                       ║${NC}"
echo -e "${CYAN}${BOLD}║${NC}    ${BOLD}${PURPLE}🎙️  LIVE TRANSCRIPTION MODE 🎙️${NC}                ${CYAN}${BOLD}║${NC}"
echo -e "${CYAN}${BOLD}║                                                       ║${NC}"
echo -e "${CYAN}${BOLD}╚═══════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}This mode transcribes as you speak!${NC}"
echo ""
echo -e "${BLUE}Controls during recording:${NC}"
echo -e "  ${YELLOW}RETURN${NC} - Start new paragraph (triggers transcription)"
echo -e "  ${YELLOW}.${NC}      - Mark sentence end"
echo -e "  ${YELLOW}Ctrl+C${NC} - Stop recording and save"
echo ""
echo -e "${PURPLE}💡 Tips:${NC}"
echo -e "  • Press Return after each thought or topic"
echo -e "  • Transcription happens in background"
echo -e "  • Results appear as they're ready"
echo ""
echo -e "${GREEN}${BOLD}Press RETURN to start...${NC}"
read -r

# Run the Python script
export JOURNAL_DIR="$JOURNAL_DIR"
export WHISPER_MODEL="$WHISPER_MODEL"

python3 "$(dirname "$0")/record-live-v2.py"