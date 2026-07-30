#!/bin/bash
# find-highest-story.sh - Find the highest story number across all iterations
#
# Usage: find-highest-story.sh
#
# Returns: The highest story number found as a bare integer (no zero-padding, no
#          STORY- prefix), or 0 if none exist. The caller formats the next ID as
#          STORY-$(printf '%04d' $((HIGHEST + 1))).
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

# Extract story numbers from stdin and return the highest as a BARE INTEGER --
# no zero-padding, no prefix. The padding strip is the load-bearing part.
#
# The pre-0.6.0 version returned the number as written, so a project of 4-digit
# IDs yielded `0045`. A caller doing $((HIGHEST + 1)) then hits bash arithmetic,
# where a leading zero means OCTAL: $((0045 + 1)) is 38, and $((0008 + 1)) is a
# hard "value too great for base" error. Padding to four digits made this
# reachable for every story below 1000, where three digits had mostly hidden it.
#
# Tolerating a context-mesh domain prefix (`payments:STORY-0001`) is free here:
# `grep -oE "STORY-[0-9]+"` already drops anything left of `STORY-`. Kept
# deliberately, and covered by a test, so a later refactor doesn't lose it.
#
# Widths are mixed on purpose: 0.5.x wrote STORY-001 and 0.6.0 writes STORY-0001,
# and an unmigrated project has both. `sort -n` compares numerically, so 45 and
# 0045 order correctly against each other.
highest_from_stdin() {
    grep -oE "STORY-[0-9]+" | \
        grep -oE "[0-9]+$" | \
        sed 's/^0*//;s/^$/0/' | \
        sort -n | \
        tail -1
}

HIGHEST=""

if [[ -d "$ITERATIONS_DIR" ]]; then
    HIGHEST=$(grep -rh "Story ID.*STORY-" "$ITERATIONS_DIR"/*/stories/*.md 2>/dev/null | \
        highest_from_stdin)
fi

if [[ -z "$HIGHEST" ]]; then
    # Also check backlog as a fallback
    BACKLOG="$PROJECT_ROOT/product/backlog.md"
    if [[ -f "$BACKLOG" ]]; then
        HIGHEST=$(highest_from_stdin < "$BACKLOG" 2>/dev/null)
    fi
fi

if [[ -z "$HIGHEST" ]]; then
    echo "0"
else
    echo "$HIGHEST"
fi
