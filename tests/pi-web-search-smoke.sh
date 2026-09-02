#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly ROOT_DIR

if ! command -v jq >/dev/null 2>&1; then
  printf 'pi-web-search-smoke: jq is required.\n' >&2
  exit 1
fi
if ! command -v chezmoi >/dev/null 2>&1; then
  printf 'pi-web-search-smoke: chezmoi is required.\n' >&2
  exit 1
fi

# The managed default carries exactly the non-secret workflow preference.
# API keys and other secrets are user runtime, added manually to the target
# file, and must survive every later chezmoi apply (create attribute).
managed_file="$ROOT_DIR/home/dot_pi/create_web-search.json"
readonly managed_file
jq -e '.workflow == "auto-summary" and (keys | length) == 1' "$managed_file" >/dev/null

expected_content='{
  "workflow": "auto-summary"
}
'
cmp <(printf '%s' "$expected_content") "$managed_file"

# .chezmoiignore keeps the file managed only when bootstrap selects Pi.
# Without the variable the file stays unmanaged so a bare chezmoi apply never
# creates Pi configuration outside of bootstrap.
ignore_template="$ROOT_DIR/home/.chezmoiignore"
readonly ignore_template

for selection in unset false; do
  rendered="$(env -u WORKSTATION_PI_SELECTED chezmoi execute-template <"$ignore_template")"
  if [[ $selection == false ]]; then
    rendered="$(env WORKSTATION_PI_SELECTED=false chezmoi execute-template <"$ignore_template")"
  fi
  grep -Fxq '.pi/web-search.json' <<<"$rendered" || {
    printf '%s: .pi/web-search.json must stay unmanaged.\n' "$selection" >&2
    exit 1
  }
done

rendered_selected="$(env WORKSTATION_PI_SELECTED=true chezmoi execute-template <"$ignore_template")"
if grep -Fxq '.pi/web-search.json' <<<"$rendered_selected"; then
  printf 'Selected Pi: .pi/web-search.json must be managed.\n' >&2
  exit 1
fi

test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT

apply_source() {
  local selection=$1
  local destination=$2
  WORKSTATION_PI_SELECTED="$selection" HOME="$destination" \
    chezmoi apply --source "$ROOT_DIR/home" --destination "$destination" --no-tty --force
}

# Selected Pi without an existing file: the create attribute deploys the
# non-secret default exactly once.
selected_home="$test_dir/selected"
mkdir -p "$selected_home"
apply_source true "$selected_home"
cmp "$managed_file" "$selected_home/.pi/web-search.json"

# Selected Pi with an existing user-owned file: the create attribute must not
# overwrite manual additions such as API keys.
existing_content='{"workflow":"none","exaApiKey":"sk-test-local-only"}'
kept_home="$test_dir/kept"
mkdir -p "$kept_home/.pi"
printf '%s\n' "$existing_content" >"$kept_home/.pi/web-search.json"
apply_source true "$kept_home"
grep -Fxq "$existing_content" "$kept_home/.pi/web-search.json" || {
  printf 'Existing web-search.json must be kept as user runtime (create attribute).\n' >&2
  exit 1
}

# Unselected Pi: chezmoi leaves existing files untouched (unmanaged).
# Removing them on downgrade is bootstrap's responsibility.
unselected_home="$test_dir/unselected"
mkdir -p "$unselected_home/.pi"
printf '%s\n' "$existing_content" >"$unselected_home/.pi/web-search.json"
apply_source false "$unselected_home"
grep -Fxq "$existing_content" "$unselected_home/.pi/web-search.json" || {
  printf 'Unselected Pi must keep the existing web-search.json unmanaged.\n' >&2
  exit 1
}

printf 'Pi web-search.json smoke checks passed.\n'