#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly ROOT_DIR
readonly HERDR="${HERDR:-$(command -v herdr)}"

test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT
export HOME="$test_dir/home"
mkdir -p "$HOME"
export HERDR_BIN="$HERDR"

"$ROOT_DIR/scripts/install-herdr-integrations" >/dev/null
find "$HOME" -type f -print0 | sort -z | xargs -0 sha256sum >"$test_dir/first.sha256"
"$ROOT_DIR/scripts/install-herdr-integrations" >/dev/null
find "$HOME" -type f -print0 | sort -z | xargs -0 sha256sum >"$test_dir/second.sha256"
cmp "$test_dir/first.sha256" "$test_dir/second.sha256"

status="$(HOME="$HOME" "$HERDR" integration status)"
for integration in codex claude opencode; do
  grep -Eq "^${integration}: current \\(v[0-9]+\\) " <<<"$status"
done

# Herdr's installer must preserve the chezmoi-owned Codex policy values.
cp "$ROOT_DIR/home/dot_codex/config.toml" "$HOME/.codex/config.toml"
"$ROOT_DIR/scripts/install-herdr-integrations" >/dev/null
cmp "$ROOT_DIR/home/dot_codex/config.toml" "$HOME/.codex/config.toml"
grep -Fqx 'approval_policy = "on-request"' "$HOME/.codex/config.toml"
grep -Fqx 'approvals_reviewer = "auto_review"' "$HOME/.codex/config.toml"
grep -Fqx 'sandbox_mode = "workspace-write"' "$HOME/.codex/config.toml"
grep -Fqx 'network_access = true' "$HOME/.codex/config.toml"
grep -Fqx 'hooks = true' "$HOME/.codex/config.toml"

printf 'Herdr integration smoke checks passed.\n'
