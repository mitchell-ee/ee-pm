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

# Resolve the user's project root. As a bundled plugin script this file lives
# in the plugin cache, not the user's repo, so climbing up from the script
# location won't reach product/. Prefer CLAUDE_PROJECT_DIR (set by the harness);
# fall back to the current working directory, which is the project root when a
# skill invokes this script.
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"

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
