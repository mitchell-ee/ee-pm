#!/bin/bash

# 0.7.0-priority-p0p3.sh
# Migrates story priority fields from the legacy Critical/High/Medium/Low scale
# to P0/P1/P2/P3.
#
#   Critical -> P0    High -> P1    Medium -> P2    Low -> P3
#
# Usage:
#   ./0.7.0-priority-p0p3.sh --dry-run [<product-dir>]
#   ./0.7.0-priority-p0p3.sh --apply   [<product-dir>]
#
# <product-dir> defaults to ./product
#
# GUARD (what makes this idempotent):
#   Only lines that ARE a priority field are touched:
#       **Priority**: Critical        markdown body form
#       priority: Critical            YAML frontmatter form
#       | ... | Critical | ...        backlog table cell
#   The value must be one of the four legacy words, on its own. After a run the
#   fields read P0..P3, which is not in the input alphabet, so a second run
#   matches nothing.
#
#   This is why the match is ANCHORED ON THE FIELD and never on the bare word.
#   A blanket substitution would rewrite prose ("High-volume imports") and other
#   scales that are NOT story priority:
#       **Importance**: High     Torres assumption-map quadrant vocabulary
#       **Confidence**: High     story confidence
#       **Impact**: High         synthesis / interview pain impact
#   Those must survive untouched. The fixture tests exactly this.

set -e

MODE=""
PRODUCT_DIR="product"

while [ "$#" -gt 0 ]; do
    case "$1" in
        --dry-run) MODE="dry"; shift ;;
        --apply)   MODE="apply"; shift ;;
        -*)
            echo "Unknown option: $1" >&2
            exit 2
            ;;
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

# Field-anchored patterns. Each captures the field prefix so it is preserved.
#   1. **Priority**: <word>
#   2. priority: <word>            (frontmatter, any indent)
#   3. | <word> |                  (backlog table cell)
SED_SCRIPT='
s/^\([[:space:]]*\*\*Priority\*\*:[[:space:]]*\)Critical[[:space:]]*$/\1P0/
s/^\([[:space:]]*\*\*Priority\*\*:[[:space:]]*\)High[[:space:]]*$/\1P1/
s/^\([[:space:]]*\*\*Priority\*\*:[[:space:]]*\)Medium[[:space:]]*$/\1P2/
s/^\([[:space:]]*\*\*Priority\*\*:[[:space:]]*\)Low[[:space:]]*$/\1P3/
s/^\([[:space:]]*priority:[[:space:]]*\)Critical[[:space:]]*$/\1P0/
s/^\([[:space:]]*priority:[[:space:]]*\)High[[:space:]]*$/\1P1/
s/^\([[:space:]]*priority:[[:space:]]*\)Medium[[:space:]]*$/\1P2/
s/^\([[:space:]]*priority:[[:space:]]*\)Low[[:space:]]*$/\1P3/
'

# Files holding at least one legacy priority FIELD (not merely the word).
MATCHES=$(grep -rlE '^[[:space:]]*(\*\*Priority\*\*:|priority:)[[:space:]]*(Critical|High|Medium|Low)[[:space:]]*$' \
    "$PRODUCT_DIR" 2>/dev/null || true)

if [ -z "$MATCHES" ]; then
    echo "nothing to do — no legacy priority fields found under $PRODUCT_DIR/"
    exit 0
fi

COUNT=$(echo "$MATCHES" | wc -l | tr -d ' ')

if [ "$MODE" = "dry" ]; then
    echo "Would update $COUNT file(s):"
    echo "$MATCHES" | while IFS= read -r f; do
        [ -z "$f" ] && continue
        echo "  $f"
        grep -nE '^[[:space:]]*(\*\*Priority\*\*:|priority:)[[:space:]]*(Critical|High|Medium|Low)[[:space:]]*$' "$f" \
            | sed 's/^/      /'
    done
    echo
    echo "(dry run — nothing written)"
    exit 0
fi

echo "$MATCHES" | while IFS= read -r f; do
    [ -z "$f" ] && continue
    sed -i '' "$SED_SCRIPT" "$f" 2>/dev/null || sed -i "$SED_SCRIPT" "$f"
    echo "  updated $f"
done

echo "Updated $COUNT file(s)."
echo
echo "NOTE: backlog table cells (| Critical |) are not rewritten by this script —"
echo "column position is ambiguous across backlog layouts. Check product/backlog.md"
echo "by hand; setup §7.3's priority check will flag it if it still uses old words."
