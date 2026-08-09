#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly ROOT_DIR
readonly STATUSLINE="$ROOT_DIR/home/dot_claude/statusline.py"

strip_ansi() {
  sed $'s/\033\\[[0-9;]*m//g'
}

output="$(printf '%s\n' '{"model":{"display_name":"deepseek-v4-flash"},"effort":{"level":"high"},"context_window":{"used_percentage":13}}' | python3 "$STATUSLINE")"
plain_output="$(printf '%s' "$output" | strip_ansi)"
[[ $plain_output == 'deepseek-v4-flash high │ ctx ▋░░░░ 13%' ]]

now="$(date +%s)"
future=$((now + 7200))
rate_output="$(printf '{"rate_limits":{"five_hour":{"used_percentage":20,"resets_at":%s},"seven_day":{"used_percentage":30,"resets_at":%s}}}\n' "$future" "$future" | python3 "$STATUSLINE")"
plain_rate_output="$(printf '%s' "$rate_output" | strip_ansi)"
[[ $plain_rate_output == *'5h '* && $plain_rate_output == *' 20%'* ]]
[[ $plain_rate_output == *'7d '* && $plain_rate_output == *' 30%'* ]]

fallback_output="$(printf '%s\n' '{' | python3 "$STATUSLINE" | strip_ansi)"
[[ $fallback_output == 'Claude' ]]

printf 'Status line smoke checks passed.\n'
