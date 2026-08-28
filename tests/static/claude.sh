#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="${ROOT_DIR:?ROOT_DIR must be exported by tests/static.sh}"

test -f "$ROOT_DIR/claude/settings.json"
test -x "$ROOT_DIR/scripts/merge-claude-settings"
test -f "$ROOT_DIR/home/dot_claude/statusline.py"
grep -Fq 'python3 ~/.claude/statusline.py' "$ROOT_DIR/claude/settings.json"
grep -Fq 'scripts/merge-claude-settings' "$ROOT_DIR/bootstrap"
bash -n "$ROOT_DIR/scripts/merge-claude-settings"
