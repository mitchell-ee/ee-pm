#!/usr/bin/env bash
# One-time OAuth bootstrap for a Miro app (REST connector path).
#
# Runs the authorization-code flow:
#   1. Resolves client_id/client_secret (env or 1Password — see miro-token-lib.sh).
#   2. Starts a local HTTP listener to catch the callback
#      (port ${MIRO_REDIRECT_PORT:-8888}).
#   3. Opens (and prints) the authorize URL — pick the workspace, approve.
#   4. Exchanges the returned code for access + refresh tokens.
#   5. Writes access + refresh + expiry to the token file (0600).
#
# Only the rotating runtime tokens are stored locally; client_id/secret stay in
# whatever source you resolved them from (env or 1Password).
#
# Install the app into a NON-developer workspace to drop the "Created with"
# board watermark.
#
# Usage:
#   ${CLAUDE_PLUGIN_ROOT}/scripts/miro-oauth-bootstrap.sh

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./miro-token-lib.sh
source "${here}/miro-token-lib.sh"

REDIRECT_PORT="${MIRO_REDIRECT_PORT:-8888}"
REDIRECT_URI="http://localhost:${REDIRECT_PORT}/callback"
TOKEN_FILE="$(miro_token_file)"

miro_resolve_client_creds client_id client_secret || exit 1

state="$(openssl rand -hex 16)"
authorize_url="https://miro.com/oauth/authorize?response_type=code&client_id=${client_id}&redirect_uri=$(jq -rn --arg v "$REDIRECT_URI" '$v|@uri')&state=${state}"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
code_file="${tmpdir}/code"

# Tiny Python server that captures the ?code=... param then exits.
python3 - "$code_file" "$state" "$REDIRECT_PORT" <<'PY' &
import http.server, socketserver, sys, urllib.parse
code_file, expected_state, port = sys.argv[1], sys.argv[2], int(sys.argv[3])

class H(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a, **k): pass
    def do_GET(self):
        q = urllib.parse.urlparse(self.path).query
        params = dict(urllib.parse.parse_qsl(q))
        # Ignore stray hits (favicon, browser preconnect) that carry neither a
        # code nor an OAuth error — keep listening for the real callback.
        if "code" not in params and "error" not in params:
            self.send_response(204); self.end_headers()
            return
        if params.get("error"):
            self.send_response(400); self.send_header("Content-Type","text/html"); self.end_headers()
            self.wfile.write(b"<h1>OAuth error</h1><p>%s</p>" % params.get("error","").encode())
            with open(code_file, "w") as f: f.write("")  # signal failure
            H.done = True
            return
        if params.get("state") != expected_state:
            self.send_response(400); self.end_headers()
            self.wfile.write(b"state mismatch")
            return
        code = params.get("code", "")
        with open(code_file, "w") as f: f.write(code)
        self.send_response(200); self.send_header("Content-Type","text/html"); self.end_headers()
        self.wfile.write(b"<h1>OK</h1><p>You can close this tab.</p>")
        H.done = True

H.done = False
with socketserver.TCPServer(("127.0.0.1", port), H) as s:
    while not H.done:
        s.handle_request()
PY
server_pid=$!

echo ""
echo "Opening this URL in your browser — pick the workspace to install into, approve:"
echo ""
echo "  $authorize_url"
echo ""
# Auto-open on macOS; harmless if it fails (URL is printed above to copy manually).
command -v open >/dev/null 2>&1 && open "$authorize_url" || true
echo "Waiting for callback on $REDIRECT_URI ..."

wait "$server_pid"

if [[ ! -s "$code_file" ]]; then
  echo "error: no code received (callback returned an OAuth error or timed out)" >&2
  exit 1
fi

code="$(cat "$code_file")"

token_response="$(curl -sS -X POST "https://api.miro.com/v1/oauth/token" \
  -d "grant_type=authorization_code" \
  -d "client_id=${client_id}" \
  -d "client_secret=${client_secret}" \
  -d "code=${code}" \
  -d "redirect_uri=${REDIRECT_URI}")"

if ! echo "$token_response" | jq -e '.access_token' >/dev/null 2>&1; then
  echo "token exchange failed:" >&2
  echo "$token_response" | jq . >&2
  exit 2
fi

access_token="$(echo "$token_response" | jq -r '.access_token')"
refresh_token="$(echo "$token_response" | jq -r '.refresh_token')"
expires_in="$(echo "$token_response" | jq -r '.expires_in // 3600')"
expires_at="$(($(date -u +%s) + expires_in))"

mkdir -p "$(dirname "$TOKEN_FILE")"
chmod 700 "$(dirname "$TOKEN_FILE")"

# Atomic write: write to tmp file in the same dir, fsync via mv.
tmp_file="$(mktemp "${TOKEN_FILE}.XXXXXX")"
jq -n \
  --arg access "$access_token" \
  --arg refresh "$refresh_token" \
  --argjson expires "$expires_at" \
  '{access_token: $access, refresh_token: $refresh, expires_epoch: $expires}' \
  > "$tmp_file"
chmod 600 "$tmp_file"
mv "$tmp_file" "$TOKEN_FILE"

echo ""
echo "Wrote tokens to ${TOKEN_FILE} (mode 600)."
echo "Access token expires at epoch ${expires_at} ($(date -u -r ${expires_at} +%Y-%m-%dT%H:%M:%SZ))."
echo ""
echo "The REST connector scripts now authenticate automatically; miro-fresh-token.sh"
echo "refreshes this token as it expires. Re-run this bootstrap only if the refresh"
echo "token is revoked."
