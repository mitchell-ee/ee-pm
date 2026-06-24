#!/usr/bin/env bash
# Doctor/verify for the Miro auth paths. Prints a status table and exits non-zero
# if anything required for a full board round-trip is missing.
#
# Checks the REST-token path (connectors) only — the hosted-MCP OAuth is owned by
# the LLM harness and can't be probed from a shell. Setup triggers/verifies the
# MCP separately by spawning a board worker.
#
# Usage: ${CLAUDE_PLUGIN_ROOT}/scripts/miro-verify.sh

set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./miro-token-lib.sh
source "${here}/miro-token-lib.sh"

ok=0
fail=0
pass() { printf '  [ ok ] %s\n' "$1"; }
warn() { printf '  [warn] %s\n' "$1"; }
bad()  { printf '  [FAIL] %s\n' "$1"; fail=$((fail+1)); }

echo "Miro REST-token path"

# 1. Client credentials resolvable?
if miro_resolve_client_creds _cid _csec 2>/dev/null; then
  pass "client credentials resolve (env or 1Password)"
else
  bad "client credentials not resolvable — set MIRO_CLIENT_ID/MIRO_CLIENT_SECRET or MIRO_OP_ITEM"
fi

# 2. Token file present?
token_file="$(miro_token_file)"
if [[ -r "$token_file" ]]; then
  pass "token file present: ${token_file}"

  # 3. Refresh works and token is usable?
  if tok="$("${here}/miro-fresh-token.sh" 2>/tmp/miro-verify.err)" && [[ -n "$tok" ]]; then
    pass "miro-fresh-token.sh returns a usable token"
    exp="$(jq -r '.expires_epoch // 0' "$token_file")"
    now="$(date -u +%s)"
    rem=$((exp - now))
    if [[ "$rem" -gt 0 ]]; then
      pass "access token valid for ~$((rem/60)) min"
    else
      warn "stored token expired — next use will refresh"
    fi
  else
    bad "miro-fresh-token.sh failed: $(tr -d '\n' </tmp/miro-verify.err)"
  fi
else
  bad "no token file at ${token_file} — run miro-oauth-bootstrap.sh"
fi

echo
echo "Hosted Miro MCP (layout_create/read/update)"
warn "OAuth-at-connect is harness-owned and can't be probed here."
warn "Run a board operation interactively once to authorize; setup also probes it."

echo
if [[ "$fail" -gt 0 ]]; then
  echo "RESULT: ${fail} blocking issue(s). Connectors will fail until resolved."
  exit 1
fi
echo "RESULT: REST-token path OK. Confirm the hosted MCP is authorized (interactive)."
exit 0
