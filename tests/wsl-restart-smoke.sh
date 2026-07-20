#!/usr/bin/env bash
set -euo pipefail

[[ -n ${WSL_DISTRO_NAME:-} ]] || {
  printf 'wsl-restart-smoke: run this after restarting WSL\n' >&2
  exit 1
}

user_unit="user@$(id -u).service"
systemctl is-active --quiet "$user_unit" || {
  printf 'wsl-restart-smoke: %s is not active\n' "$user_unit" >&2
  exit 1
}

[[ $(systemctl --user is-system-running) == running ]] || {
  printf 'wsl-restart-smoke: systemd user manager is not running\n' >&2
  exit 1
}

systemctl --user is-enabled --quiet workstation-update.service || {
  printf 'wsl-restart-smoke: workstation-update.service is not enabled\n' >&2
  exit 1
}
update_invocation_id="$(
  systemctl --user show workstation-update.service --property=InvocationID --value
)"
[[ $update_invocation_id =~ ^[0-9a-f]{32}$ && $update_invocation_id != 00000000000000000000000000000000 ]] || {
  printf 'wsl-restart-smoke: workstation-update.service did not start in this user session\n' >&2
  exit 1
}
[[ -r "$HOME/.local/state/workstation-update/state.tsv" ]] || {
  printf 'wsl-restart-smoke: workstation update state was not created\n' >&2
  exit 1
}

resolution="$(MISE_TRUSTED_CONFIG_PATHS="$HOME/.config/mise/config.toml" bash --login -ic 'type -a herdr cagent codex claude opencode' 2>&1)" || {
  printf '%s\n' "$resolution" >&2
  exit 1
}
printf '%s\n' "$resolution"

paths_output="$(MISE_TRUSTED_CONFIG_PATHS="$HOME/.config/mise/config.toml" bash --login -ic 'command -v herdr; command -v cagent; command -v codex; command -v claude; command -v opencode' 2>/dev/null)"
mapfile -t paths <<<"$paths_output"
for path in "${paths[@]:0:3}"; do
  [[ $path == "$HOME/.local/share/mise/"* ]] || {
    printf 'wsl-restart-smoke: expected mise-managed Linux path, got %s\n' "$path" >&2
    exit 1
  }
  [[ $path != /mnt/* ]] || {
    printf 'wsl-restart-smoke: Windows shim resolved: %s\n' "$path" >&2
    exit 1
  }
done

[[ ${paths[3]} == "$HOME/.local/bin/claude" ]] || {
  printf 'wsl-restart-smoke: unexpected Claude path: %s\n' "${paths[3]}" >&2
  exit 1
}
[[ ${paths[4]} == "$HOME/.opencode/bin/opencode" ]] || {
  printf 'wsl-restart-smoke: unexpected OpenCode path: %s\n' "${paths[4]}" >&2
  exit 1
}

MISE_TRUSTED_CONFIG_PATHS="$HOME/.config/mise/config.toml" bash --login -ic 'codex features list' >/dev/null
printf 'WSL restart smoke checks passed.\n'
