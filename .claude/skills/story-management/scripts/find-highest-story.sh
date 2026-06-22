#!/bin/bash
# find-highest-story.sh - Find the highest story number across all iterations
#
# Usage: find-highest-story.sh
#
# Returns: The highest STORY-XXX number found, or 0 if none exist
#
# Story numbers are globally unique across all iterations and never reset.
# This script scans ALL iterations to find the current maximum.

set -e

# Get script directory to find project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

ITERATIONS_DIR="$PROJECT_ROOT/product/iterations"

if [[ ! -d "$ITERATIONS_DIR" ]]; then
    echo "0"
    exit 0
fi

# Find all story files and extract the highest number
HIGHEST=$(grep -rh "Story ID.*STORY-" "$ITERATIONS_DIR"/*/stories/*.md 2>/dev/null | \
    grep -oE "STORY-[0-9]+" | \
    sed 's/STORY-//' | \
    sort -n | \
    tail -1)

if [[ -z "$HIGHEST" ]]; then
    # Also check backlog as a fallback
    BACKLOG="$PROJECT_ROOT/product/context/backlog.md"
    if [[ -f "$BACKLOG" ]]; then
        HIGHEST=$(grep -oE "STORY-[0-9]+" "$BACKLOG" 2>/dev/null | \
            sed 's/STORY-//' | \
            sort -n | \
            tail -1)
    fi
fi

if [[ -z "$HIGHEST" ]]; then
    echo "0"
else
    echo "$HIGHEST"
fi
