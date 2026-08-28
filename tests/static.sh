#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
export ROOT_DIR

# Static checks are split into per-area files. The runner keeps a fixed
# execution order and fail-fast behavior: the first failing section aborts
# the whole run with a nonzero exit code.
sections=(
  bootstrap.sh
  docs.sh
  mise.sh
  claude.sh
  pi.sh
  herdr.sh
  cagent.sh
  codex.sh
  update-ai.sh
  personal.sh
  docker.sh
  ansible.sh
  shell-init.sh
  gitconfig.sh
  windows-terminal.sh
  smoke.sh
  lint.sh
)

for section in "${sections[@]}"; do
  printf '[static] %s\n' "$section"
  "$ROOT_DIR/tests/static/$section"
done

printf 'Static checks passed.\n'
