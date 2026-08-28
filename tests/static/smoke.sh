#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="${ROOT_DIR:?ROOT_DIR must be exported by tests/static.sh}"

case "${1:-}" in
  syntax-tools)
    bash -n "$ROOT_DIR/tests/neovim-smoke.sh"
    bash -n "$ROOT_DIR/tests/yazi-smoke.sh"
    bash -n "$ROOT_DIR/tests/safe-chain-smoke.sh"
    ;;
  syntax-ai)
    bash -n "$ROOT_DIR/tests/ai-clis-smoke.sh"
    bash -n "$ROOT_DIR/tests/pi-packages-smoke.sh"
    bash -n "$ROOT_DIR/tests/pi-keybindings-smoke.sh"
    bash -n "$ROOT_DIR/tests/bootstrap-ai-mise-order.sh"
    bash -n "$ROOT_DIR/tests/bootstrap-herdr-integration-order.sh"
    ;;
  syntax-more)
    bash -n "$ROOT_DIR/tests/claude-settings-smoke.sh"
    bash -n "$ROOT_DIR/tests/statusline-smoke.sh"
    bash -n "$ROOT_DIR/tests/personal-cli-smoke.sh"
    bash -n "$ROOT_DIR/tests/docker-smoke.sh"
    bash -n "$ROOT_DIR/tests/psql-smoke.sh"
    bash -n "$ROOT_DIR/tests/cagent-smoke.sh"
    bash -n "$ROOT_DIR/tests/playwright-cli-smoke.sh"
    ;;
  syntax-update)
    bash -n "$ROOT_DIR/tests/workstation-update-smoke.sh"
    ;;
  run)
    "$ROOT_DIR/tests/bootstrap-ai-mise-order.sh"
    "$ROOT_DIR/tests/bootstrap-herdr-integration-order.sh"
    "$ROOT_DIR/tests/ai-clis-smoke.sh"
    "$ROOT_DIR/tests/pi-packages-smoke.sh"
    "$ROOT_DIR/tests/pi-keybindings-smoke.sh"
    "$ROOT_DIR/tests/claude-settings-smoke.sh"
    "$ROOT_DIR/tests/statusline-smoke.sh"
    ;;
  *)
    printf 'Usage: %s <stage: syntax-tools|syntax-ai|syntax-more|syntax-update|run>\n' "$0" >&2
    exit 2
    ;;
esac
