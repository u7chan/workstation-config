#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="${ROOT_DIR:?ROOT_DIR must be exported by tests/static.sh}"

case "${1:-}" in
  settings)
    test -f "$ROOT_DIR/claude/settings.json"
    test -x "$ROOT_DIR/scripts/merge-claude-settings"
    test -f "$ROOT_DIR/home/dot_claude/statusline.py"
    grep -Fq 'python3 ~/.claude/statusline.py' "$ROOT_DIR/claude/settings.json"
    grep -Fq 'scripts/merge-claude-settings' "$ROOT_DIR/bootstrap"
    ;;
  syntax)
    bash -n "$ROOT_DIR/scripts/merge-claude-settings"
    ;;
  *)
    printf 'Usage: %s <stage: settings|syntax>\n' "$0" >&2
    exit 2
    ;;
esac
