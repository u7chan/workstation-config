#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly ROOT_DIR

test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT

test_home="$test_dir/home"
config_home="$test_home/.config"
mkdir -p "$config_home"
cp -R "$ROOT_DIR/home/dot_config/yazi" "$config_home/yazi"

# A fresh HOME intentionally has neither downloaded plugins nor flavors.
test ! -d "$config_home/yazi/plugins"
test ! -d "$config_home/yazi/flavors"

if [[ -n ${MISE:-} ]]; then
  mise_bin="$MISE"
elif [[ -x $HOME/.local/bin/mise ]]; then
  mise_bin="$HOME/.local/bin/mise"
else
  mise_bin="$(command -v mise || true)"
fi

if [[ -n $mise_bin ]]; then
  export MISE_CONFIG_FILE="$ROOT_DIR/provisioning/mise/config.toml"
  export MISE_LOCKED=1
  yazi_bin="$($mise_bin which yazi)"
  [[ $yazi_bin == "$HOME/.local/share/mise/"* ]]
else
  # Configuration parsing remains testable in reduced environments where the
  # repository bootstrap has not installed mise yet.
  yazi_bin="${YAZI:-$(command -v yazi)}"
fi

debug_output="$(
  HOME="$test_home" \
  XDG_CONFIG_HOME="$config_home" \
  XDG_CACHE_HOME="$test_home/.cache" \
  XDG_STATE_HOME="$test_home/.local/state" \
  TERM=xterm-256color \
    "$yazi_bin" --debug
)"

grep -Fq "$config_home/yazi/yazi.toml" <<<"$debug_output"
grep -Fq "$config_home/yazi/package.toml" <<<"$debug_output"
! grep -Eiq 'failed to parse|invalid configuration' <<<"$debug_output"

printf 'yazi-smoke: ok (%s)\n' "$("$yazi_bin" --version)"
