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

event_json="${HERDR_PLUGIN_EVENT_JSON:-}"
repo_root="$(jq -r '.data.workspace.worktree.repo_root // empty' <<<"$event_json")"
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

# Herdr requires an agent name unique among live agents, so a fixed name fails
# as soon as a second worktree runs pi. Derive the name from the worktree branch
# slug and fall back to the workspace id.
slugify() {
  printf '%s' "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -e 's/[^a-z0-9_-]/-/g' -e 's/--*/-/g' -e 's/^-*//' -e 's/-*$//'
}
workspace_id="${HERDR_WORKSPACE_ID:-}"
branch="$(jq -r '.data.worktree.branch // empty' <<<"$event_json")"
agent_prefix="${WORKTREE_PI_AGENT_NAME_PREFIX:-pi}"
fallback_suffix="$(slugify "${workspace_id:-$pane_id}")"
agent_name="$(slugify "$agent_prefix-${branch##*/}")"
[[ $agent_name != "$agent_prefix" ]] || agent_name="$agent_prefix-$fallback_suffix"
agent_name="${agent_name:0:32}"
agent_name="${agent_name%-}"

agent_args=()
if [[ -n ${WORKTREE_PI_AGENT_ARGS[*]:-} ]]; then
  agent_args=(-- "${WORKTREE_PI_AGENT_ARGS[@]}")
fi

herdr_bin="${HERDR_BIN_PATH:-herdr}"
start_agent() {
  "$herdr_bin" agent start "$1" \
    --kind "${WORKTREE_PI_AGENT:-pi}" \
    --pane "$pane_id" \
    --timeout "${WORKTREE_PI_AGENT_TIMEOUT_MS:-60000}" \
    "${agent_args[@]}"
}

if ! output="$(start_agent "$agent_name" 2>&1)"; then
  if jq -e '.error.code == "agent_name_taken"' <<<"$output" >/dev/null 2>&1; then
    agent_name="$agent_prefix-$fallback_suffix"
    agent_name="${agent_name:0:32}"
    output="$(start_agent "$agent_name" 2>&1)" || {
      printf '%s\n' "$output" >&2
      exit 1
    }
  else
    printf '%s\n' "$output" >&2
    exit 1
  fi
fi
printf '%s\n' "$output"
