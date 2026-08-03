#!/bin/bash

# 0.6.0-sidecar-rekey.sh
# Widens 2-digit artifact ref-ids to 4-digit across Miro sidecars, the repo
# files that reference them, and the assumption-map directory names that embed
# them.
#
#   OPP-01 -> OPP-0001        OUTCOME-01->OPP-01 -> OUTCOME-0001->OPP-0001
#   STORY-14 -> STORY-0014    SOL-03-checkout/ -> SOL-0003-checkout/
#
# Usage:
#   ./0.6.0-sidecar-rekey.sh --dry-run [<product-dir>]
#   ./0.6.0-sidecar-rekey.sh --apply   [<product-dir>]
#
# <product-dir> defaults to ./product
#
# WHY THIS EXISTS
#   Sidecars key their nodes/connectors maps BY ARTIFACT ID. The 0.6.0 widening
#   from 2- to 4-digit ids invalidates every key. It fails SILENTLY: a stale
#   sidecar does not error, it reads as "every node is new", so the next absorb
#   pass proposes recreating every node on a board that already has them.
#   The Miro shape ids are stable — only the repo-side keys need rewriting.
#
# GUARD (what makes this idempotent):
#   The pattern matches a known ref-id prefix followed by EXACTLY two digits,
#   with a non-digit (or end) on both sides:
#       (OPP|OUTCOME|SOL|STORY|ASSUMPTION|ACTIVITY)-[0-9]{2}(?![0-9])
#   Once widened to 4 digits the pattern no longer matches, so a second run
#   changes nothing. A project already migrated by hand is at the fixed point
#   and correctly reports "nothing to do".
#
#   PRODUCT-{SLUG} is deliberately NOT in the prefix list — the OST root is the
#   one ref-id that carries no number (see opportunity-tree/SKILL.md).

set -e

MODE=""
PRODUCT_DIR="product"

while [ "$#" -gt 0 ]; do
    case "$1" in
        --dry-run) MODE="dry"; shift ;;
        --apply)   MODE="apply"; shift ;;
        -*) echo "Unknown option: $1" >&2; exit 2 ;;
        *) PRODUCT_DIR="$1"; shift ;;
    esac
done

if [ -z "$MODE" ]; then
    echo "Usage: $0 --dry-run|--apply [<product-dir>]" >&2
    exit 2
fi

if [ ! -d "$PRODUCT_DIR" ]; then
    echo "nothing to do — no $PRODUCT_DIR/ directory"
    exit 0
fi

PREFIXES='OPP|OUTCOME|SOL|STORY|ASSUMPTION|ACTIVITY'
# Match PREFIX-NN not followed by another digit.
MATCH_RE="(${PREFIXES})-[0-9]{2}([^0-9]|\$)"

# --- Discover work -----------------------------------------------------------

FILES=$(grep -rlE "$MATCH_RE" "$PRODUCT_DIR" 2>/dev/null || true)
DIRS=$(find "$PRODUCT_DIR" -type d 2>/dev/null \
    | grep -E "/(${PREFIXES})-[0-9]{2}(-|\$)" || true)

if [ -z "$FILES" ] && [ -z "$DIRS" ]; then
    echo "nothing to do — no 2-digit ref-ids found under $PRODUCT_DIR/"
    exit 0
fi

# --- Report ------------------------------------------------------------------

if [ "$MODE" = "dry" ]; then
    if [ -n "$FILES" ]; then
        echo "Files with 2-digit ref-ids:"
        echo "$FILES" | while IFS= read -r f; do
            [ -z "$f" ] && continue
            echo "  $f"
            grep -noE "(${PREFIXES})-[0-9]{2}" "$f" | sort -u -t: -k2 | sed 's/^/      line /'
        done
    fi
    if [ -n "$DIRS" ]; then
        echo
        echo "Directories to rename (git mv):"
        echo "$DIRS" | while IFS= read -r d; do
            [ -z "$d" ] && continue
            base=$(basename "$d")
            new=$(echo "$base" | sed -E "s/^(${PREFIXES})-([0-9]{2})(-|\$)/\1-00\2\3/")
            echo "  $d  ->  $(dirname "$d")/$new"
        done
    fi
    echo
    echo "(dry run — nothing written)"
    exit 0
fi

# --- Apply -------------------------------------------------------------------

# 1. Rewrite file contents. Zero-pad NN -> 00NN.
if [ -n "$FILES" ]; then
    echo "$FILES" | while IFS= read -r f; do
        [ -z "$f" ] && continue
        perl -pi -e "s/\\b(${PREFIXES})-([0-9]{2})(?![0-9])/\$1-00\$2/g" "$f"
        echo "  rewrote $f"
    done
fi

# 2. Rename directories that embed an id. Deepest-first so parents stay valid.
if [ -n "$DIRS" ]; then
    echo "$DIRS" | awk '{print length, $0}' | sort -rn | cut -d' ' -f2- \
    | while IFS= read -r d; do
        [ -z "$d" ] && continue
        base=$(basename "$d")
        parent=$(dirname "$d")
        new=$(echo "$base" | sed -E "s/^(${PREFIXES})-([0-9]{2})(-|\$)/\1-00\2\3/")
        [ "$base" = "$new" ] && continue
        if git -C "$parent" rev-parse --git-dir >/dev/null 2>&1; then
            git mv "$d" "$parent/$new" 2>/dev/null || mv "$d" "$parent/$new"
        else
            mv "$d" "$parent/$new"
        fi
        echo "  renamed $d -> $parent/$new"
    done
fi

echo
echo "Rekey complete. The Miro shape ids were NOT touched — only repo-side keys."
echo "Re-run with --dry-run to confirm the fixed point (expect 'nothing to do')."
