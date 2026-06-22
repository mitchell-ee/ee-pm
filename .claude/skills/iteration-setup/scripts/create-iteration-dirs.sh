#!/bin/bash

# create-iteration-dirs.sh
# Creates directory structure for a new product iteration.
#
# Usage:
#   ./create-iteration-dirs.sh <iteration-slug>
#   ./create-iteration-dirs.sh <iteration-slug> --from-seed <seed-iteration-path>
#
# iteration-slug is the full folder name, conventionally YYYY-MM-DD-{initiative}.
# Example: 2026-06-02-{iteration-slug}
#
# When --from-seed is supplied, the interviews/ directory is copied from the
# seed iteration so a new iteration starts with the reference interviews
# already in place.
#
# The layout is flat (see iteration-setup/SKILL.md step 4): there is no
# discovery/ subtree and no per-iteration opportunity-tree/ or design/ folder.
# The OST is product-level (product/context/opportunity-solution-tree/).

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <iteration-slug> [--from-seed <seed-iteration-path>]"
    echo "Example: $0 2026-06-02-{iteration-slug}"
    echo "Example: $0 2026-06-02-{new-slug} --from-seed product/iterations/2026-06-02-{iteration-slug}"
    exit 1
fi

ITERATION_SLUG="$1"
ITERATION_DIR="product/iterations/${ITERATION_SLUG}"
SEED_DIR=""

shift
while [ "$#" -gt 0 ]; do
    case "$1" in
        --from-seed)
            SEED_DIR="$2"
            shift 2
            ;;
        *)
            echo "Unknown argument: $1"
            exit 1
            ;;
    esac
done

if [ ! -d "product" ]; then
    echo "Error: Must be run from project root (product/ directory not found)"
    exit 1
fi

if [ -d "$ITERATION_DIR" ]; then
    echo "Error: Iteration already exists at ${ITERATION_DIR}"
    exit 1
fi

echo "Creating iteration directory: ${ITERATION_DIR}"

# Flat layout per iteration-setup/SKILL.md step 4. README.md, synthesis.md, and
# retrospective.md are created in later steps; epics/ stays empty unless the
# solution is large (>8 stories).
mkdir -p "${ITERATION_DIR}/interviews"
mkdir -p "${ITERATION_DIR}/prototypes"
mkdir -p "${ITERATION_DIR}/epics"
mkdir -p "${ITERATION_DIR}/stories"
mkdir -p "${ITERATION_DIR}/story-maps"

touch "${ITERATION_DIR}/decisions.md"

if [ -n "$SEED_DIR" ]; then
    if [ ! -d "${SEED_DIR}/interviews" ]; then
        echo "Error: seed iteration has no interviews/: ${SEED_DIR}"
        exit 1
    fi
    cp -R "${SEED_DIR}/interviews/." "${ITERATION_DIR}/interviews/"
    echo "Seeded interviews from ${SEED_DIR}/interviews"
fi

echo ""
echo "Iteration ${ITERATION_SLUG} created successfully."
echo ""
echo "Next steps:"
echo "  1. Write ${ITERATION_DIR}/README.md with goals and scope"
echo "  2. If not seeded, populate ${ITERATION_DIR}/interviews/"
echo "  3. Run discovery-synthesis to produce synthesis.md from interviews"
echo ""
