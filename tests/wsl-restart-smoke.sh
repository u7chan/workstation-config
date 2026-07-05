#!/usr/bin/env bash
set -euo pipefail

[[ -n ${WSL_DISTRO_NAME:-} ]] || {
  printf 'wsl-restart-smoke: run this after restarting WSL\n' >&2
  exit 1
}

resolution="$(bash --login -ic 'type -a herdr codex' 2>&1)" || {
  printf '%s\n' "$resolution" >&2
  exit 1
}
printf '%s\n' "$resolution"

paths_output="$(bash --login -ic 'command -v herdr; command -v codex' 2>/dev/null)"
mapfile -t paths <<<"$paths_output"
for path in "${paths[@]}"; do
  [[ $path == "$HOME/.local/share/mise/"* ]] || {
    printf 'wsl-restart-smoke: expected mise-managed Linux path, got %s\n' "$path" >&2
    exit 1
  }
  [[ $path != /mnt/* ]] || {
    printf 'wsl-restart-smoke: Windows shim resolved: %s\n' "$path" >&2
    exit 1
  }
done

status="$("${paths[0]}" integration status)"
for integration in codex claude opencode; do
  if ! grep -Eq "^${integration}: current \\(v[0-9]+\\) " <<<"$status"; then
    printf 'wsl-restart-smoke: %s integration is not current\n' "$integration" >&2
    exit 1
  fi
done

"${paths[1]}" features list >/dev/null
printf 'WSL restart smoke checks passed.\n'
