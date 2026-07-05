#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly ROOT_DIR
readonly MISE="${MISE:-$HOME/.local/bin/mise}"

test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT
mkdir -p "$test_dir/home/.config"
cp -a "$ROOT_DIR/home/dot_config/nvim" "$test_dir/home/.config/nvim"

export HOME="$test_dir/home"
export XDG_CACHE_HOME="$test_dir/cache"
export XDG_DATA_HOME="$test_dir/data"
export XDG_STATE_HOME="$test_dir/state"
export MISE_CONFIG_FILE="$ROOT_DIR/mise/config.toml"
export MISE_DATA_DIR="${MISE_DATA_DIR:-$test_dir/mise-data}"
export MISE_CACHE_DIR="${MISE_CACHE_DIR:-$test_dir/mise-cache}"
export MISE_STATE_DIR="${MISE_STATE_DIR:-$test_dir/mise-state}"
export MISE_LOCKED=1

"$MISE" exec neovim -- nvim --headless "+Lazy! sync" +qa
test -d "$XDG_DATA_HOME/nvim/lazy/lazy.nvim"
"$MISE" exec neovim -- nvim --headless "+checkhealth vim.deprecated" +qa

printf 'Neovim empty-state smoke test passed.\n'
