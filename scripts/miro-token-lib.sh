#!/usr/bin/env bash
# Shared helpers for the Miro OAuth token scripts (bootstrap + fresh-token).
# Source this; do not exec it.
#
# Portability: the plugin cannot assume any one user's secret manager, so client
# credentials are resolved in this order:
#   1. MIRO_CLIENT_ID / MIRO_CLIENT_SECRET environment variables (preferred).
#   2. 1Password CLI, if MIRO_OP_ITEM names an item (e.g.
#      "op://Automation/Miro API Key"); reads <item>/username as the client_id
#      and <item>/credential as the client_secret.
# If neither resolves, the caller errors with guidance naming both options.
#
# Token storage path:
#   MIRO_TOKEN_FILE if set, else ~/.config/<project>/miro-tokens.json, where
#   <project> is MIRO_PROJECT_NAME if set, else the basename of the git repo
#   root, else "vcw". Tokens are the user's own Miro grant — never the repo.

# Resolve the token file path. Echoes the path to stdout.
miro_token_file() {
  if [[ -n "${MIRO_TOKEN_FILE:-}" ]]; then
    printf '%s' "$MIRO_TOKEN_FILE"
    return 0
  fi
  local project="${MIRO_PROJECT_NAME:-}"
  if [[ -z "$project" ]]; then
    project="$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || true)"
  fi
  [[ -z "$project" ]] && project="vcw"
  printf '%s' "${HOME}/.config/${project}/miro-tokens.json"
}

# Resolve client_id + client_secret into the named output vars.
# Usage: miro_resolve_client_creds CLIENT_ID_VAR CLIENT_SECRET_VAR
# Returns non-zero and prints guidance to stderr if neither source resolves.
miro_resolve_client_creds() {
  local _id_out="$1" _secret_out="$2"
  local _id="" _secret=""

  if [[ -n "${MIRO_CLIENT_ID:-}" && -n "${MIRO_CLIENT_SECRET:-}" ]]; then
    _id="$MIRO_CLIENT_ID"
    _secret="$MIRO_CLIENT_SECRET"
  elif [[ -n "${MIRO_OP_ITEM:-}" ]] && command -v op >/dev/null 2>&1; then
    _id="$(op read "${MIRO_OP_ITEM}/username" 2>/dev/null || true)"
    _secret="$(op read "${MIRO_OP_ITEM}/credential" 2>/dev/null || true)"
  fi

  if [[ -z "$_id" || -z "$_secret" ]]; then
    cat >&2 <<'EOF'
error: could not resolve Miro app client credentials.

Provide them one of two ways:
  • Environment: export MIRO_CLIENT_ID and MIRO_CLIENT_SECRET
  • 1Password:   export MIRO_OP_ITEM="op://<vault>/<item>" (uses fields
                 username=client_id, credential=client_secret; needs the `op` CLI)

Create the app + credentials at https://miro.com/app/settings/user-profile/apps
(grant boards:read and boards:write, install to your team).
EOF
    return 1
  fi

  printf -v "$_id_out" '%s' "$_id"
  printf -v "$_secret_out" '%s' "$_secret"
}
