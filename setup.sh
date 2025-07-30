#!/bin/bash

# Audio Journal Setup Script
# Initializes the audio journal directory structure and dependencies

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Audio Journal Setup${NC}"
echo "===================="
echo ""

# Configuration
JOURNAL_DIR="${JOURNAL_DIR:-$HOME/Documents/AudioJournal}"

# Create directory structure
echo -e "${YELLOW}Creating journal directory structure...${NC}"
mkdir -p "$JOURNAL_DIR"
mkdir -p "$JOURNAL_DIR/.sync"
mkdir -p "$JOURNAL_DIR/audio/$(date +"%Y")"
mkdir -p "$JOURNAL_DIR/transcripts/$(date +"%Y")"

# Check and install dependencies
echo -e "${YELLOW}Checking dependencies...${NC}"

check_dependency() {
    local cmd=$1
    local install_cmd=$2
    
    if command -v "$cmd" &> /dev/null; then
        echo -e "${GREEN}✓${NC} $cmd is installed"
    else
        echo -e "${YELLOW}⚠${NC}  $cmd is not installed"
        echo "    Install with: $install_cmd"
    fi
}

check_dependency "sox" "brew install sox"
check_dependency "ffmpeg" "brew install ffmpeg"
check_dependency "whisper" "pip install openai-whisper"
check_dependency "jq" "brew install jq"
check_dependency "git" "xcode-select --install"

# Initialize git repository if not exists
if [ ! -d "$JOURNAL_DIR/.git" ] && command -v git &> /dev/null; then
    echo ""
    echo -e "${YELLOW}Initializing git repository...${NC}"
    cd "$JOURNAL_DIR"
    git init -q
    
    # Create .gitignore
    cat > .gitignore << 'EOF'
# Audio directory (we don't track audio files in git)
audio/

# System files
.DS_Store
.Spotlight-V100
.Trashes

# Temporary files
*.tmp
*~
EOF
    
    git add .gitignore
    git commit -q -m "Initial commit: Audio journal setup" || true
    echo -e "${GREEN}✓${NC} Git repository initialized"
fi

# Create initial README in journal directory
if [ ! -f "$JOURNAL_DIR/README.md" ]; then
    cat > "$JOURNAL_DIR/README.md" << 'EOF'
# Audio Journal

This directory contains your audio journal entries organized by year.

## Structure

```
AudioJournal/
├── audio/
│   └── 2025/
│       └── JAN_28_07.05.m4a   # Audio recordings
├── transcripts/
│   └── 2025/
│       └── JAN_28_07.05.md    # Transcripts and notes
├── .git/                      # Version control for transcripts
└── .sync/                     # Sync metadata
```

## File Naming

Files use the format: `MON_DD_HH.MM` where:
- `MON`: Three-letter month (JAN, FEB, MAR, etc.)
- `DD`: Day of month
- `HH.MM`: Time in 24-hour format with dots

## Sync Strategy

- **Transcripts**: Tracked in git for version control
- **Audio files**: Sync via iCloud/Dropbox (not in git)
- **Metadata**: JSON manifest in `.sync/` directory

EOF
    
    cd "$JOURNAL_DIR"
    git add README.md
    git commit -q -m "Add journal README" || true
fi

# Create sync manifest template
if [ ! -f "$JOURNAL_DIR/.sync/manifest.json" ]; then
    echo '{"entries": {}}' > "$JOURNAL_DIR/.sync/manifest.json"
fi

# Set up cloud sync (optional)
echo ""
echo -e "${BLUE}Cloud Sync Setup (Optional)${NC}"
echo "=============================="
echo ""
echo "To sync audio files across devices, you can:"
echo ""
echo "1. ${YELLOW}iCloud Drive${NC} (recommended for Mac/iOS):"
echo "   ln -s ~/Library/Mobile\\ Documents/com~apple~CloudDocs/AudioJournal $JOURNAL_DIR"
echo ""
echo "2. ${YELLOW}Dropbox${NC}:"
echo "   ln -s ~/Dropbox/AudioJournal $JOURNAL_DIR"
echo ""
echo "3. ${YELLOW}Manual sync${NC}:"
echo "   Keep files in $JOURNAL_DIR and sync manually"
echo ""

# Success message
echo -e "${GREEN}✅ Setup complete!${NC}"
echo ""
echo "To start recording:"
echo "  ./record.sh"
echo ""
echo "To search entries:"
echo "  ./search.sh [search term]"
echo ""
echo "Journal location: $JOURNAL_DIR"