#!/usr/bin/env bash
# Print a fresh Miro REST access token to stdout.
#
# Reads the token file (see miro-token-lib.sh for path resolution). If the
# stored access token has more than ${MIRO_REFRESH_MARGIN_SEC:-300} seconds
# left, prints it as-is. Otherwise exchanges the refresh_token for a new pair,
# atomically rewrites the file, then prints the new access token.
#
# Bootstrap once with miro-oauth-bootstrap.sh before this can work.
#
# Used by the connector REST scripts (read/write-connectors.sh, miro-copy-board.sh)
# and by the SessionStart hook that exports MIRO_ACCESS_TOKEN.

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./miro-token-lib.sh
source "${here}/miro-token-lib.sh"

TOKEN_FILE="$(miro_token_file)"
SAFETY_MARGIN_SEC="${MIRO_REFRESH_MARGIN_SEC:-300}"

if [[ ! -r "$TOKEN_FILE" ]]; then
  echo "error: ${TOKEN_FILE} missing — run miro-oauth-bootstrap.sh first" >&2
  exit 1
fi

access_token="$(jq -r '.access_token // ""' "$TOKEN_FILE")"
refresh_token="$(jq -r '.refresh_token // ""' "$TOKEN_FILE")"
expires_epoch="$(jq -r '.expires_epoch // 0' "$TOKEN_FILE")"

now_epoch="$(date -u +%s)"
remaining=$((expires_epoch - now_epoch))

if [[ -n "$access_token" && "$remaining" -gt "$SAFETY_MARGIN_SEC" ]]; then
  printf '%s' "$access_token"
  exit 0
fi

if [[ -z "$refresh_token" ]]; then
  echo "error: no refresh_token in ${TOKEN_FILE} — re-run miro-oauth-bootstrap.sh" >&2
  exit 1
fi

miro_resolve_client_creds client_id client_secret || exit 1

token_response="$(curl -sS -X POST "https://api.miro.com/v1/oauth/token" \
  -d "grant_type=refresh_token" \
  -d "client_id=${client_id}" \
  -d "client_secret=${client_secret}" \
  -d "refresh_token=${refresh_token}")"

if ! echo "$token_response" | jq -e '.access_token' >/dev/null 2>&1; then
  echo "Miro token refresh failed:" >&2
  echo "$token_response" | jq . >&2
  exit 2
fi

new_access="$(echo "$token_response" | jq -r '.access_token')"
new_refresh="$(echo "$token_response" | jq -r '.refresh_token // empty')"
expires_in="$(echo "$token_response" | jq -r '.expires_in // 3600')"
new_expires="$((now_epoch + expires_in))"

# Atomic rewrite. Keep the existing refresh_token if Miro didn't rotate one.
final_refresh="${new_refresh:-$refresh_token}"
tmp_file="$(mktemp "${TOKEN_FILE}.XXXXXX")"
jq -n \
  --arg access "$new_access" \
  --arg refresh "$final_refresh" \
  --argjson expires "$new_expires" \
  '{access_token: $access, refresh_token: $refresh, expires_epoch: $expires}' \
  > "$tmp_file"
chmod 600 "$tmp_file"
mv "$tmp_file" "$TOKEN_FILE"

printf '%s' "$new_access"
