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

expected_tools=("$@")
if ((${#expected_tools[@]} == 0)); then
  expected_tools=(codex claude opencode pi)
fi

codex_selected=false
for tool in "${expected_tools[@]}"; do
  case "$tool" in
    codex) codex_selected=true ;;
    claude|opencode|pi) ;;
    *)
      printf 'wsl-restart-smoke: unsupported AI CLI: %s\n' "$tool" >&2
      exit 1
      ;;
  esac
done

resolution="$(MISE_TRUSTED_CONFIG_PATHS="$HOME/.config/mise/config.toml" bash --login -ic 'type -a herdr cagent' 2>&1)" || {
  printf '%s\n' "$resolution" >&2
  exit 1
}
printf '%s\n' "$resolution"

paths_output="$(MISE_TRUSTED_CONFIG_PATHS="$HOME/.config/mise/config.toml" bash --login -ic 'command -v herdr; command -v cagent' 2>/dev/null)"
mapfile -t paths <<<"$paths_output"
for path in "${paths[@]:0:2}"; do
  [[ $path == "$HOME/.local/share/mise/"* ]] || {
    printf 'wsl-restart-smoke: expected mise-managed Linux path, got %s\n' "$path" >&2
    exit 1
  }
  [[ $path != /mnt/* ]] || {
    printf 'wsl-restart-smoke: Windows shim resolved: %s\n' "$path" >&2
    exit 1
  }
done

for tool in "${expected_tools[@]}"; do
  tool_path="$(MISE_TRUSTED_CONFIG_PATHS="$HOME/.config/mise/config.toml" \
    bash --login -ic 'command -v "$1"' _ "$tool" 2>/dev/null)"
  case "$tool" in
    codex|pi)
      [[ $tool_path == "$HOME/.local/share/mise/"* ]] || {
        printf 'wsl-restart-smoke: unexpected %s path: %s\n' "$tool" "$tool_path" >&2
        exit 1
      }
      [[ $tool_path != /mnt/* ]] || {
        printf 'wsl-restart-smoke: Windows %s shim resolved: %s\n' "$tool" "$tool_path" >&2
        exit 1
      }
      ;;
    claude)
      [[ $tool_path == "$HOME/.local/bin/claude" ]] || {
        printf 'wsl-restart-smoke: unexpected Claude path: %s\n' "$tool_path" >&2
        exit 1
      }
      ;;
    opencode)
      [[ $tool_path == "$HOME/.opencode/bin/opencode" ]] || {
        printf 'wsl-restart-smoke: unexpected OpenCode path: %s\n' "$tool_path" >&2
        exit 1
      }
      ;;
  esac
done

integration_status="$(MISE_TRUSTED_CONFIG_PATHS="$HOME/.config/mise/config.toml" bash --login -ic 'herdr integration status' 2>&1)" || {
  printf 'wsl-restart-smoke: herdr integration status failed\n' >&2
  exit 1
}
printf '%s\n' "$integration_status"
for tool in "${expected_tools[@]}"; do
  grep -Eq "^${tool}: current " <<<"$integration_status" || {
    printf 'wsl-restart-smoke: %s integration is not current\n' "$tool" >&2
    exit 1
  }
done

if [[ $codex_selected == true ]]; then
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
fi
printf 'WSL restart smoke checks passed.\n'
