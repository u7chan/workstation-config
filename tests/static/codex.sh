#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="${ROOT_DIR:?ROOT_DIR must be exported by tests/static.sh}"

case "${1:-}" in
  config)
    codex_config="$ROOT_DIR/home/dot_codex/config.toml"
    test -f "$codex_config"
    grep -Fxq 'hooks = true' "$codex_config"
    grep -Fxq 'apps = false' "$codex_config"
    ;;
  *)
    printf 'Usage: %s <stage: config>\n' "$0" >&2
    exit 2
    ;;
esac
