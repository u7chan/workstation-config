#!/usr/bin/env bash
set -euo pipefail

plugin_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# The WORKTREE_PI_* settings come from config.sh; see that file for defaults.
# shellcheck source=/dev/null
source "$plugin_dir/config.sh"
if [[ -n ${HERDR_PLUGIN_CONFIG_DIR:-} && -r $HERDR_PLUGIN_CONFIG_DIR/config.sh ]]; then
  # shellcheck source=/dev/null
  source "$HERDR_PLUGIN_CONFIG_DIR/config.sh"
fi

[[ ${WORKTREE_PI_ENABLED:-1} == 1 ]] || exit 0

repo_root="$(jq -r '.data.workspace.worktree.repo_root // empty' <<<"${HERDR_PLUGIN_EVENT_JSON:-}")"
if [[ -n ${WORKTREE_PI_REPOS[*]:-} ]]; then
  selected=false
  for candidate in "${WORKTREE_PI_REPOS[@]}"; do
    if [[ $repo_root == "$candidate" ]]; then
      selected=true
      break
    fi
  done
  [[ $selected == true ]] || exit 0
fi

pane_id="${HERDR_PANE_ID:-}"
[[ -n $pane_id ]] || exit 0

agent_args=()
if [[ -n ${WORKTREE_PI_AGENT_ARGS[*]:-} ]]; then
  agent_args=(-- "${WORKTREE_PI_AGENT_ARGS[@]}")
fi

exec "${HERDR_BIN_PATH:-herdr}" agent start "${WORKTREE_PI_AGENT:-pi}" \
  --kind "${WORKTREE_PI_AGENT:-pi}" \
  --pane "$pane_id" \
  --timeout "${WORKTREE_PI_AGENT_TIMEOUT_MS:-60000}" \
  "${agent_args[@]}"
