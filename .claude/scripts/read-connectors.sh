#!/usr/bin/env bash
# Read all connectors from a Miro board via REST.
#
# Why this exists: the official Miro MCP's layout DSL has no connector type. The
# opportunity-tree absorb mode needs the connector graph to detect re-parenting,
# so we drop one level and hit Miro's REST API directly.
#
# Auth: set MIRO_ACCESS_TOKEN in your environment (a Miro REST access token with
# boards:read scope). See docs/miro-setup.md.
#
# Output shape (stdout):
#   {
#     "board_id": "...",
#     "fetched_at": "ISO-8601",
#     "count": N,
#     "connectors": [
#       { "id": "...", "from_id": "...", "to_id": "...", "shape": "curved", "captions": [...] },
#       ...
#     ]
#   }
#
# Usage: read-connectors.sh <board_id>
# Example: .claude/scripts/read-connectors.sh <BOARD_ID>

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $(basename "$0") <board_id>" >&2
  exit 64
fi

board_id="$1"

if [[ -z "${MIRO_ACCESS_TOKEN:-}" ]]; then
  echo "error: MIRO_ACCESS_TOKEN is not set. Export a Miro REST access token" >&2
  echo "       (boards:read scope). See docs/miro-setup.md." >&2
  exit 1
fi

# URL-encode the board_id so trailing '=' survives the path.
encoded_id="$(jq -rn --arg v "$board_id" '$v|@uri')"

cursor=""
all_pages="[]"

while :; do
  url="https://api.miro.com/v2/boards/${encoded_id}/connectors?limit=50"
  if [[ -n "$cursor" ]]; then
    url="${url}&cursor=${cursor}"
  fi

  response="$(curl -sS \
    -H "Authorization: Bearer ${MIRO_ACCESS_TOKEN}" \
    -H "Accept: application/json" \
    "$url")"

  # Bubble up Miro errors verbatim.
  if echo "$response" | jq -e '.type == "error"' >/dev/null 2>&1; then
    echo "Miro API error:" >&2
    echo "$response" | jq . >&2
    exit 2
  fi

  page_data="$(echo "$response" | jq '.data // []')"
  all_pages="$(jq -n --argjson a "$all_pages" --argjson b "$page_data" '$a + $b')"

  cursor="$(echo "$response" | jq -r '.cursor // empty')"
  [[ -z "$cursor" ]] && break
done

jq -n \
  --arg board_id "$board_id" \
  --arg fetched_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --argjson raw "$all_pages" \
  '{
    board_id: $board_id,
    fetched_at: $fetched_at,
    count: ($raw | length),
    connectors: ($raw | map({
      id: .id,
      from_id: (.startItem.id // null),
      to_id: (.endItem.id // null),
      shape: (.shape // null),
      style: (.style // null),
      captions: (.captions // [])
    }))
  }'
