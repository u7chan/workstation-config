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

export MISE_CONFIG_DIR="$ROOT_DIR/provisioning/mise"
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

# playwright-cli runs headless unless --headed is supplied. Use a unique
# session so this smoke does not interfere with another CLI session, and do
# not install a browser here: a missing or mismatched revision must fail.
smoke_session="workstation-config-playwright-smoke-$$"
smoke_opened=false
cleanup() {
  if [[ $smoke_opened == true ]]; then
    "$playwright_cli_bin" "-s=$smoke_session" close >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

"$playwright_cli_bin" "-s=$smoke_session" open about:blank --browser=chromium >/dev/null
smoke_opened=true
"$playwright_cli_bin" "-s=$smoke_session" close >/dev/null
smoke_opened=false
trap - EXIT

printf 'playwright-cli smoke checks passed: %s\n' "$("$playwright_cli_bin" --version)"
