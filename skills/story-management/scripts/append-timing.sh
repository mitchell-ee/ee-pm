#!/bin/bash
# append-timing.sh - Append a timing entry to the centralized timing log
#
# Usage: append-timing.sh <command> <iteration> <duration_seconds> [metadata_json]
#
# Arguments:
#   command          - The command/skill name (e.g., "/synth", "/req")
#   iteration        - The iteration name (e.g., "2025-12-02-admin-page")
#   duration_seconds - Duration in seconds
#   metadata_json    - Optional JSON object with additional metadata (default: {})
#
# Example:
#   ./append-timing.sh "/synth" "2025-12-02-admin-page" 180 '{"themes_identified": 4}'

set -e

COMMAND="$1"
ITERATION="$2"
DURATION="$3"
METADATA="${4:-{}}"

if [[ -z "$COMMAND" || -z "$ITERATION" || -z "$DURATION" ]]; then
    echo "Usage: append-timing.sh <command> <iteration> <duration_seconds> [metadata_json]"
    exit 1
fi

# Get script directory to find project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Navigate from .claude/skills/<skill>/scripts/ to project root (4 levels up)
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
TIMING_LOG="$PROJECT_ROOT/product/metrics/timing-log.jsonl"

# Generate ISO8601 timestamp
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Create timing entry
ENTRY=$(cat <<EOF
{"timestamp": "$TIMESTAMP", "command": "$COMMAND", "iteration": "$ITERATION", "duration_seconds": $DURATION, "generation_seconds": $DURATION, "status": "success", "metadata": $METADATA}
EOF
)

# Append to timing log (create product/metrics/ on first use)
mkdir -p "$(dirname "$TIMING_LOG")"
echo "$ENTRY" >> "$TIMING_LOG"

echo "Timing entry appended to $TIMING_LOG"
