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

# The managed keybindings file declares exactly two bindings.
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

# The managed models.json carries the openai-codex GPT-5.6 overrides that pi
# reads for auto-compaction (pi does not read ~/.pi/config.json).
models_file="$ROOT_DIR/home/dot_pi/agent/models.json"
readonly models_file
jq -e '
  .providers["openai-codex"].modelOverrides |
  (."gpt-5.6-sol".contextWindow == 256384) and
  (."gpt-5.6-luna".contextWindow == 256384) and
  (."gpt-5.6-terra".contextWindow == 256384)
' "$models_file" >/dev/null

# .chezmoiignore keeps the files managed only when bootstrap selects Pi.
# Without the variable the files stay unmanaged so a bare chezmoi apply never
# creates Pi configuration outside of bootstrap.
ignore_template="$ROOT_DIR/home/.chezmoiignore"
readonly ignore_template

assert_ignore_pattern() {
  local label=$1
  local target=$2
  local expected_presence=$3
  shift 3
  local rendered
  rendered="$("$@" chezmoi execute-template <"$ignore_template")"
  if [[ $expected_presence == present ]]; then
    grep -Fxq "$target" <<<"$rendered" || {
      printf '%s: %s must stay unmanaged.\n' "$label" "$target" >&2
      exit 1
    }
  else
    if grep -Fxq "$target" <<<"$rendered"; then
      printf '%s: %s must be managed.\n' "$label" "$target" >&2
      exit 1
    fi
  fi
}

for target in '.pi/agent/keybindings.json' '.pi/agent/models.json'; do
  assert_ignore_pattern "$target" "$target" present env -u WORKSTATION_PI_SELECTED
  assert_ignore_pattern "$target" "$target" present env WORKSTATION_PI_SELECTED=false
  assert_ignore_pattern "$target" "$target" absent env WORKSTATION_PI_SELECTED=true
done

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
cmp "$models_file" "$selected_home/.pi/agent/models.json"

# Unselected Pi: chezmoi leaves existing files untouched (unmanaged).
# Removing them on downgrade is bootstrap's responsibility.
existing_content='{"app.clipboard.pasteImage": ["ctrl+shift+v"], "user.custom": true}'
unselected_home="$test_dir/unselected"
mkdir -p "$unselected_home/.pi/agent"
printf '%s\n' "$existing_content" >"$unselected_home/.pi/agent/keybindings.json"
printf '%s\n' '{"providers":{"openai-codex":{"modelOverrides":{"gpt-5.6-sol":{"contextWindow":12345}}}}}' >"$unselected_home/.pi/agent/models.json"
apply_source false "$unselected_home"
grep -Fxq "$existing_content" "$unselected_home/.pi/agent/keybindings.json" || {
  printf 'Unselected Pi must keep the existing keybindings.json unmanaged.\n' >&2
  exit 1
}
grep -Fq '"contextWindow":12345' "$unselected_home/.pi/agent/models.json" || {
  printf 'Unselected Pi must keep the existing models.json unmanaged.\n' >&2
  exit 1
}

printf 'Pi keybindings and models.json smoke checks passed.\n'
