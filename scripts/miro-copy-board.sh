#!/usr/bin/env bash
# Copy a Miro board, optionally into a specific team.
#
# Handy for absorb validation: copy a canonical board to a throwaway, edit the
# copy by hand, then run the skill's absorb pass against it without touching the
# real board.
#
# Auth: set MIRO_ACCESS_TOKEN in your environment (a Miro REST access token with
# boards:write scope). See docs/miro-setup.md.
# Team:  set MIRO_TEAM_ID to land the copy in a specific team. If unset, the copy
# lands in your token's default team.
#
# Usage:
#   miro-copy-board.sh <source_board_id> <new_name>
#   MIRO_TEAM_ID=xxx miro-copy-board.sh <source_board_id> <new_name>
#
# Prints the new board id and URL to stdout (JSON).

set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $(basename "$0") <source_board_id> <new_name>" >&2
  exit 64
fi

src_board_id="$1"
new_name="$2"

if [[ -z "${MIRO_ACCESS_TOKEN:-}" ]]; then
  echo "error: MIRO_ACCESS_TOKEN is not set. Export a Miro REST access token" >&2
  echo "       (boards:write scope). See docs/miro-setup.md." >&2
  exit 1
fi

team_id="${MIRO_TEAM_ID:-}"
encoded_src="$(jq -rn --arg v "$src_board_id" '$v|@uri')"

if [[ -n "$team_id" ]]; then
  body="$(jq -n --arg name "$new_name" --arg team "$team_id" '{name: $name, teamId: $team}')"
else
  body="$(jq -n --arg name "$new_name" '{name: $name}')"
fi

response="$(curl -sS -X PUT \
  -H "Authorization: Bearer ${MIRO_ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  "https://api.miro.com/v2/boards?copy_from=${encoded_src}" \
  -d "$body")"

if ! echo "$response" | jq -e '.id' >/dev/null 2>&1; then
  echo "copy failed:" >&2
  echo "$response" | jq . >&2
  exit 2
fi

echo "$response" | jq '{id, name, viewLink, team}'
