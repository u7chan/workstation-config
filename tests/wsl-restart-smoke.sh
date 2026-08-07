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

resolution="$(MISE_TRUSTED_CONFIG_PATHS="$HOME/.config/mise/config.toml" bash --login -ic 'type -a herdr cagent codex claude opencode pi' 2>&1)" || {
  printf '%s\n' "$resolution" >&2
  exit 1
}
printf '%s\n' "$resolution"

paths_output="$(MISE_TRUSTED_CONFIG_PATHS="$HOME/.config/mise/config.toml" bash --login -ic 'command -v herdr; command -v cagent; command -v codex; command -v claude; command -v opencode; command -v pi' 2>/dev/null)"
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
[[ ${paths[5]} == "$HOME/.local/share/mise/"* ]] || {
  printf 'wsl-restart-smoke: unexpected Pi path: %s\n' "${paths[5]}" >&2
  exit 1
}
[[ ${paths[5]} != /mnt/* ]] || {
  printf 'wsl-restart-smoke: Windows Pi shim resolved: %s\n' "${paths[5]}" >&2
  exit 1
}

features_output="$(MISE_TRUSTED_CONFIG_PATHS="$HOME/.config/mise/config.toml" bash --login -ic 'codex features list' 2>&1)" || {
  printf 'wsl-restart-smoke: codex features list failed\n' >&2
  exit 1
}
if ! grep -q 'apps' <<<"$features_output"; then
  printf 'wsl-restart-smoke: apps feature not found in codex features list\n' >&2
  exit 1
fi
if ! grep -q 'apps.*false' <<<"$features_output"; then
  printf 'wsl-restart-smoke: codex apps feature is not disabled\n' >&2
  exit 1
fi
printf 'WSL restart smoke checks passed.\n'
