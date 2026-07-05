#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly ROOT_DIR

expected_safe_chain_version="$(awk -F'"' '/^safe_chain_version:/{print $2}' "$ROOT_DIR/ansible/vars/main.yml")"
readonly expected_safe_chain_version

smoke_output="$(EXPECTED_SAFE_CHAIN_VERSION="$expected_safe_chain_version" bash --noprofile --norc <<'SMOKE' 2>&1
set -euo pipefail
if [[ -x "$HOME/.local/bin/mise" ]]; then
  eval "$("$HOME/.local/bin/mise" activate bash)"
elif command -v mise >/dev/null 2>&1; then
  eval "$(mise activate bash)"
fi
source "$HOME/.safe-chain/scripts/init-posix.sh"

if ! command -v safe-chain >/dev/null 2>&1; then
  printf 'safe-chain-smoke: safe-chain is not installed\n' >&2
  exit 1
fi

safe_chain_path="$(command -v safe-chain)"
[[ $safe_chain_path == "$HOME/.safe-chain/bin/safe-chain" ]] || {
  printf 'safe-chain-smoke: expected %s, got %s\n' "$HOME/.safe-chain/bin/safe-chain" "$safe_chain_path" >&2
  exit 1
}

version_output="$(safe-chain --version)"
printf '%s\n' "$version_output"
[[ $version_output == *"$EXPECTED_SAFE_CHAIN_VERSION"* ]] || {
  printf 'safe-chain-smoke: expected version %s, got %s\n' "$EXPECTED_SAFE_CHAIN_VERSION" "$version_output" >&2
  exit 1
}

verify_output="$(npm safe-chain-verify 2>&1)"
printf '%s\n' "$verify_output"
grep -q 'OK: Safe-chain works!' <<<"$verify_output"

printf 'Safe-chain smoke checks passed.\n'
SMOKE
)"
printf '%s\n' "$smoke_output"
