#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly ROOT_DIR

if [[ -n ${MISE:-} ]]; then
  mise_bin="$MISE"
elif [[ -x $HOME/.local/bin/mise ]]; then
  mise_bin="$HOME/.local/bin/mise"
else
  mise_bin="$(command -v mise || true)"
fi
[[ -n $mise_bin ]] || {
  printf 'playwright-cli-smoke: mise is not installed\n' >&2
  exit 1
}

export MISE_CONFIG_FILE="$ROOT_DIR/provisioning/mise/config.toml"
export MISE_LOCKED=1
playwright_cli_bin="$("$mise_bin" which playwright-cli)"
[[ -x $playwright_cli_bin ]] || {
  printf 'playwright-cli-smoke: mise did not resolve an executable playwright-cli binary: %s\n' "$playwright_cli_bin" >&2
  exit 1
}

[[ $playwright_cli_bin == "$HOME/.local/share/mise/"* ]] || {
  printf 'playwright-cli-smoke: expected mise-managed path, got %s\n' "$playwright_cli_bin" >&2
  exit 1
}

"$playwright_cli_bin" --help >/dev/null

printf 'playwright-cli smoke checks passed: %s\n' "$("$playwright_cli_bin" --version)"
