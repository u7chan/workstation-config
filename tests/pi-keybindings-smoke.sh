#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly ROOT_DIR

if ! command -v jq >/dev/null 2>&1; then
  printf 'pi-keybindings-smoke: jq is required.\n' >&2
  exit 1
fi
if ! command -v chezmoi >/dev/null 2>&1; then
  printf 'pi-keybindings-smoke: chezmoi is required.\n' >&2
  exit 1
fi

expected_file="$ROOT_DIR/home/dot_pi/agent/keybindings.json"
readonly expected_file

# The managed file declares exactly two bindings.
jq -e '
  length == 2 and
  .["app.clipboard.pasteImage"] == ["alt+v"] and
  .["app.message.dequeue"] == ["alt+up"]
' "$expected_file" >/dev/null

expected_content='{
  "app.clipboard.pasteImage": ["alt+v"],
  "app.message.dequeue": ["alt+up"]
}
'
cmp <(printf '%s' "$expected_content") "$expected_file"

# .chezmoiignore keeps the file managed only when bootstrap selects Pi.
# Without the variable the file stays unmanaged so a bare chezmoi apply never
# creates Pi configuration outside of bootstrap.
ignore_template="$ROOT_DIR/home/.chezmoiignore"
readonly ignore_template

assert_ignore_pattern() {
  local label=$1
  local expected_presence=$2
  shift 2
  local rendered
  rendered="$("$@" chezmoi execute-template <"$ignore_template")"
  if [[ $expected_presence == present ]]; then
    grep -Fxq '.pi/agent/keybindings.json' <<<"$rendered" || {
      printf '%s: .pi/agent/keybindings.json must stay unmanaged.\n' "$label" >&2
      exit 1
    }
  else
    if grep -Fxq '.pi/agent/keybindings.json' <<<"$rendered"; then
      printf '%s: .pi/agent/keybindings.json must be managed.\n' "$label" >&2
      exit 1
    fi
  fi
}

assert_ignore_pattern variable-unset present env -u WORKSTATION_PI_SELECTED
assert_ignore_pattern variable-false present env WORKSTATION_PI_SELECTED=false
assert_ignore_pattern variable-true absent env WORKSTATION_PI_SELECTED=true

test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT

apply_source() {
  local selection=$1
  local destination=$2
  WORKSTATION_PI_SELECTED="$selection" HOME="$destination" \
    chezmoi apply --source "$ROOT_DIR/home" --destination "$destination" --no-tty --force
}

# Selected Pi: chezmoi places the exact managed content.
selected_home="$test_dir/selected"
mkdir -p "$selected_home"
apply_source true "$selected_home"
cmp "$expected_file" "$selected_home/.pi/agent/keybindings.json"

# Unselected Pi: chezmoi leaves an existing file untouched (unmanaged).
# Removing it on downgrade is bootstrap's responsibility.
existing_content='{"app.clipboard.pasteImage": ["ctrl+shift+v"], "user.custom": true}'
unselected_home="$test_dir/unselected"
mkdir -p "$unselected_home/.pi/agent"
printf '%s\n' "$existing_content" >"$unselected_home/.pi/agent/keybindings.json"
apply_source false "$unselected_home"
grep -Fxq "$existing_content" "$unselected_home/.pi/agent/keybindings.json" || {
  printf 'Unselected Pi must keep the existing keybindings.json unmanaged.\n' >&2
  exit 1
}

printf 'Pi keybindings smoke checks passed.\n'
