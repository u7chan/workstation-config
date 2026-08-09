#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly ROOT_DIR
readonly BOOTSTRAP="$ROOT_DIR/bootstrap"
readonly MERGE_SCRIPT="$ROOT_DIR/scripts/merge-claude-settings"
readonly FRAGMENT="$ROOT_DIR/claude/settings.json"

line_number() {
  grep -n -m1 -F -- "$1" "$2" | cut -d: -f1
}

chezmoi_line="$(line_number 'chezmoi" apply --source' "$BOOTSTRAP")"
gate_line="$(line_number 'if [[ $CLAUDE_SELECTED == true ]]; then' "$BOOTSTRAP")"
merge_line="$(line_number '"$ROOT_DIR/scripts/merge-claude-settings"' "$BOOTSTRAP")"
trust_line="$(line_number 'Trusting mise configuration' "$BOOTSTRAP")"
[[ $chezmoi_line -lt $gate_line && $gate_line -lt $merge_line && \
  $merge_line -lt $trust_line ]] || {
  printf 'Claude settings merge must be gated after chezmoi and before mise trust.\n' >&2
  exit 1
}
grep -Fq 'CLAUDE_SELECTED=false' "$BOOTSTRAP"
grep -Fq '[[ $PROFILE == "personal" ]] && CLAUDE_SELECTED=true' "$BOOTSTRAP"
grep -Fq 'if [[ -z $WORKSTATION_PERSONAL_AI_TOOLS ]]; then' "$BOOTSTRAP"
grep -Fq 'if [[ $ai_tool == "claude" ]]; then' "$BOOTSTRAP"

jq -e 'if type == "object" then has("theme") and has("statusLine") else false end' \
  "$FRAGMENT" >/dev/null
grep -Fqx '    "command": "python3 ~/.claude/statusline.py"' \
  "$FRAGMENT"

test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT

make_fixture() {
  local name=$1
  fixture_root="$test_dir/$name/repo"
  fixture_home="$test_dir/$name/home"
  mkdir -p "$fixture_root/claude" "$fixture_root/scripts" "$fixture_home"
  cp "$MERGE_SCRIPT" "$fixture_root/scripts/merge-claude-settings"
  cp "$FRAGMENT" "$fixture_root/claude/settings.json"
  chmod 0755 "$fixture_root/scripts/merge-claude-settings"
}

run_merge() {
  HOME="$fixture_home" "$fixture_root/scripts/merge-claude-settings"
}

make_fixture existing
mkdir -p "$fixture_home/.claude"
printf '%s\n' '{"hooks":{"keep":"herdr"},"permissions":{"allow":["Bash"]},"unmanaged":{"keep":true},"theme":"light","statusLine":{"type":"command","command":"old","extra":"remove"}}' \
  >"$fixture_home/.claude/settings.json"
chmod 0640 "$fixture_home/.claude/settings.json"
run_merge
jq -e '
  .theme == "dark"
  and .statusLine.type == "command"
  and .statusLine.command == "python3 ~/.claude/statusline.py"
  and ((.statusLine | keys | sort) == ["command", "type"])
  and .permissions.allow[0] == "Bash"
  and .hooks.keep == "herdr"
  and .unmanaged.keep == true
' "$fixture_home/.claude/settings.json" >/dev/null
[[ $(stat -c '%a' "$fixture_home/.claude/settings.json") == 640 ]]
cp "$fixture_home/.claude/settings.json" "$fixture_home/settings.first"
run_merge
cmp "$fixture_home/settings.first" "$fixture_home/.claude/settings.json"

make_fixture fresh
run_merge
jq -e '
  .theme == "dark"
  and .statusLine.command == "python3 ~/.claude/statusline.py"
  and ((keys | sort) == ["statusLine", "theme"])
' "$fixture_home/.claude/settings.json" >/dev/null
[[ $(stat -c '%a' "$fixture_home/.claude/settings.json") == 600 ]]

make_fixture invalid-fragment
mkdir -p "$fixture_home/.claude"
printf '%s\n' '{"keep":true}' >"$fixture_home/.claude/settings.json"
cp "$fixture_home/.claude/settings.json" "$fixture_home/settings.before"
printf '%s\n' '{"theme":' >"$fixture_root/claude/settings.json"
if run_merge >/dev/null 2>&1; then
  printf 'Invalid settings fragment was accepted.\n' >&2
  exit 1
fi
cmp "$fixture_home/settings.before" "$fixture_home/.claude/settings.json"
[[ -z $(find "$fixture_home/.claude" -maxdepth 1 -name '.settings.json.tmp.*' -print -quit) ]]

make_fixture nonobject-fragment
printf '%s\n' '[]' >"$fixture_root/claude/settings.json"
if run_merge >/dev/null 2>&1; then
  printf 'Non-object settings fragment was accepted.\n' >&2
  exit 1
fi
[[ ! -e "$fixture_home/.claude/settings.json" ]]

make_fixture invalid-existing
mkdir -p "$fixture_home/.claude"
printf '%s\n' 'not-json' >"$fixture_home/.claude/settings.json"
if run_merge >/dev/null 2>&1; then
  printf 'Invalid existing settings were accepted.\n' >&2
  exit 1
fi
grep -Fqx 'not-json' "$fixture_home/.claude/settings.json"

make_fixture nonobject-existing
mkdir -p "$fixture_home/.claude"
printf '%s\n' '[]' >"$fixture_home/.claude/settings.json"
if run_merge >/dev/null 2>&1; then
  printf 'Non-object existing settings were accepted.\n' >&2
  exit 1
fi
grep -Fqx '[]' "$fixture_home/.claude/settings.json"

printf 'Claude settings smoke checks passed.\n'
