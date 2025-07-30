#!/bin/bash

# Migration script to restructure existing audio journal files

set -e

JOURNAL_DIR="${JOURNAL_DIR:-$HOME/Documents/AudioJournal}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Audio Journal Migration Script${NC}"
echo "==============================="
echo ""
echo "This will restructure your journal to separate audio and transcript directories."
echo "Current structure: Year/files"
echo "New structure: audio/Year/files and transcripts/Year/files"
echo ""
echo -n "Continue? [y/N] "
read -r response

if [[ ! "$response" =~ ^[Yy]$ ]]; then
    echo "Migration cancelled."
    exit 0
fi

# Create new directory structure
echo -e "${YELLOW}Creating new directory structure...${NC}"
mkdir -p "$JOURNAL_DIR/audio"
mkdir -p "$JOURNAL_DIR/transcripts"

# Find all year directories
for year_dir in "$JOURNAL_DIR"/[0-9][0-9][0-9][0-9]; do
    if [ -d "$year_dir" ]; then
        year=$(basename "$year_dir")
        echo -e "${GREEN}Processing year: $year${NC}"
        
        # Create year subdirectories
        mkdir -p "$JOURNAL_DIR/audio/$year"
        mkdir -p "$JOURNAL_DIR/transcripts/$year"
        
        # Move audio files
        for audio in "$year_dir"/*.m4a "$year_dir"/*.wav "$year_dir"/*.mp3; do
            if [ -f "$audio" ]; then
                filename=$(basename "$audio")
                echo "  Moving audio: $filename"
                mv "$audio" "$JOURNAL_DIR/audio/$year/"
            fi
        done 2>/dev/null || true
        
        # Move transcript files
        for transcript in "$year_dir"/*.md; do
            if [ -f "$transcript" ]; then
                filename=$(basename "$transcript")
                echo "  Moving transcript: $filename"
                mv "$transcript" "$JOURNAL_DIR/transcripts/$year/"
            fi
        done 2>/dev/null || true
        
        # Remove empty year directory
        rmdir "$year_dir" 2>/dev/null || true
    fi
done

# Update git tracking
if [ -d "$JOURNAL_DIR/.git" ]; then
    echo -e "${YELLOW}Updating git repository...${NC}"
    cd "$JOURNAL_DIR"
    git add -A
    git commit -m "Migrate to separated audio/transcript structure" || true
fi

echo ""
echo -e "${GREEN}✅ Migration complete!${NC}"
echo ""
echo "New structure:"
echo "  Audio files: $JOURNAL_DIR/audio/"
echo "  Transcripts: $JOURNAL_DIR/transcripts/"
echo ""
echo "Don't forget to update your WHISPER_MODEL for better accuracy:"
echo "  export WHISPER_MODEL=\"medium\"  # or \"large\" for best quality"