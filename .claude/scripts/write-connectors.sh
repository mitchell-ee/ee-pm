#!/usr/bin/env bash
# Create, update, or delete Miro connectors via REST.
#
# Why this exists: the official Miro MCP's layout DSL has no connector type. The
# opportunity-tree skill needs to draw and re-parent the parent->child edges that
# make up the tree, so we hit Miro's REST API directly. read-connectors.sh is the
# read complement of this script.
#
# Auth: set MIRO_ACCESS_TOKEN in your environment (a Miro REST access token with
# boards:write scope). See docs/miro-setup.md.
#
# GOTCHA — do not "simplify" the create path into a pair-splitting loop.
# `create` takes from_id and to_id as explicit positional args and the request
# body is assembled with `jq -n` (startItem/endItem objects). An earlier
# iteration word-split id pairs with `set -- $pair` and interpolated them into
# the body; Miro's REST API rejects that with HTTP 400 "startItem.id expected
# Number". Keep ids as explicit args and let jq build the JSON.
#
# Usage:
#   write-connectors.sh create <board_id> <from_id> <to_id> \
#       [--shape curved|straight|elbowed] \
#       [--stroke-color #1a1a1a] [--stroke-width 2] [--caption "text"]
#   write-connectors.sh update <board_id> <connector_id> \
#       [--shape ...] [--stroke-color ...] [--stroke-width ...] [--caption ...]
#   write-connectors.sh delete <board_id> <connector_id>
#
# create/update print the resulting connector as JSON to stdout.
# delete prints nothing on success (exit 0); HTTP errors bubble to stderr.
#
# Example:
#   write-connectors.sh create <BOARD_ID> 3458764... 3458764... --shape curved

set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "usage: $(basename "$0") create|update|delete <board_id> ..." >&2
  exit 64
fi

subcommand="$1"
board_id="$2"
shift 2

# --- token resolution (mirrors read-connectors.sh) ----------------------------
if [[ -z "${MIRO_ACCESS_TOKEN:-}" ]]; then
  echo "error: MIRO_ACCESS_TOKEN is not set. Export a Miro REST access token" >&2
  echo "       (boards:write scope). See docs/miro-setup.md." >&2
  exit 1
fi

encoded_id="$(jq -rn --arg v "$board_id" '$v|@uri')"
base_url="https://api.miro.com/v2/boards/${encoded_id}/connectors"

# Bubble up Miro errors verbatim, else echo the response.
check_response() {
  local response="$1"
  if echo "$response" | jq -e '.type == "error"' >/dev/null 2>&1; then
    echo "Miro API error:" >&2
    echo "$response" | jq . >&2
    exit 2
  fi
  echo "$response" | jq .
}

# Assemble the optional style/shape/caption body shared by create and update.
# Reads the remaining "$@" flags; emits a JSON object on stdout.
build_body() {
  local shape="" stroke_color="" stroke_width="" caption=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --shape)        shape="$2"; shift 2 ;;
      --stroke-color) stroke_color="$2"; shift 2 ;;
      --stroke-width) stroke_width="$2"; shift 2 ;;
      --caption)      caption="$2"; shift 2 ;;
      *) echo "error: unknown flag '$1'" >&2; exit 64 ;;
    esac
  done

  jq -n \
    --arg shape "$shape" \
    --arg stroke_color "$stroke_color" \
    --arg stroke_width "$stroke_width" \
    --arg caption "$caption" \
    '
    {}
    | (if $shape != "" then .shape = $shape else . end)
    | (if $stroke_color != "" or $stroke_width != ""
        then .style = (
          {}
          | (if $stroke_color != "" then .strokeColor = $stroke_color else . end)
          | (if $stroke_width != "" then .strokeWidth = $stroke_width else . end)
        )
        else . end)
    | (if $caption != "" then .captions = [ { content: $caption } ] else . end)
    '
}

case "$subcommand" in
  create)
    if [[ $# -lt 2 ]]; then
      echo "usage: $(basename "$0") create <board_id> <from_id> <to_id> [flags]" >&2
      exit 64
    fi
    from_id="$1"
    to_id="$2"
    shift 2
    extra_body="$(build_body "$@")"
    body="$(jq -n \
      --arg from_id "$from_id" \
      --arg to_id "$to_id" \
      --argjson extra "$extra_body" \
      '{ startItem: { id: $from_id }, endItem: { id: $to_id } } + $extra')"

    response="$(curl -sS -X POST "$base_url" \
      -H "Authorization: Bearer ${MIRO_ACCESS_TOKEN}" \
      -H "Content-Type: application/json" \
      -H "Accept: application/json" \
      -d "$body")"
    check_response "$response"
    ;;

  update)
    if [[ $# -lt 1 ]]; then
      echo "usage: $(basename "$0") update <board_id> <connector_id> [flags]" >&2
      exit 64
    fi
    connector_id="$1"
    shift
    body="$(build_body "$@")"
    if [[ "$body" == "{}" ]]; then
      echo "error: update needs at least one of --shape/--stroke-color/--stroke-width/--caption" >&2
      exit 64
    fi

    response="$(curl -sS -X PATCH "${base_url}/${connector_id}" \
      -H "Authorization: Bearer ${MIRO_ACCESS_TOKEN}" \
      -H "Content-Type: application/json" \
      -H "Accept: application/json" \
      -d "$body")"
    check_response "$response"
    ;;

  delete)
    if [[ $# -ne 1 ]]; then
      echo "usage: $(basename "$0") delete <board_id> <connector_id>" >&2
      exit 64
    fi
    connector_id="$1"

    http_code="$(curl -sS -o /tmp/.write-connectors-del.$$ -w "%{http_code}" \
      -X DELETE "${base_url}/${connector_id}" \
      -H "Authorization: Bearer ${MIRO_ACCESS_TOKEN}" \
      -H "Accept: application/json")"
    if [[ "$http_code" != "204" ]]; then
      echo "delete failed (HTTP ${http_code}):" >&2
      cat "/tmp/.write-connectors-del.$$" >&2
      rm -f "/tmp/.write-connectors-del.$$"
      exit 2
    fi
    rm -f "/tmp/.write-connectors-del.$$"
    ;;

  *)
    echo "error: unknown subcommand '$subcommand' (expected create|update|delete)" >&2
    exit 64
    ;;
esac
