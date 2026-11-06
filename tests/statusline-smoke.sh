#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly ROOT_DIR
readonly STATUSLINE="$ROOT_DIR/home/dot_claude/statusline/statusline.sh"
readonly STATUSLINE_JQ="$ROOT_DIR/home/dot_claude/statusline/statusline.jq"

strip_ansi() {
  sed $'s/\033\\[[0-9;]*m//g'
}

# jq プログラムとして単体でコンパイルできること（$branch は statusline.sh が --arg で渡す）
jq -n --arg branch '' -f "$STATUSLINE_JQ" >/dev/null

# 入力が空でもモデル名だけは出す
plain_output="$(printf '%s\n' '{}' | bash "$STATUSLINE" | strip_ansi)"
[[ $plain_output == 'Claude' ]]

output="$(printf '%s\n' '{"model":{"display_name":"deepseek-v4-flash"},"effort":{"level":"high"},"context_window":{"used_percentage":13}}' | bash "$STATUSLINE")"
plain_output="$(printf '%s' "$output" | strip_ansi)"
[[ $plain_output == *'deepseek-v4-flash'* && $plain_output == *'high'* ]]
[[ $plain_output == *'▋░░░░ 13%'* ]]

now="$(date +%s)"
future=$((now + 7200))
rate_output="$(printf '{"rate_limits":{"five_hour":{"used_percentage":20,"resets_at":%s},"seven_day":{"used_percentage":30,"resets_at":%s}}}\n' "$future" "$future" | bash "$STATUSLINE")"
plain_rate_output="$(printf '%s' "$rate_output" | strip_ansi)"
[[ $plain_rate_output == *'5h '* && $plain_rate_output == *' 20%'* ]]
[[ $plain_rate_output == *'7d '* && $plain_rate_output == *' 30%'* ]]
# 5h は残り時間、7d はリセット曜日を括弧で添える
grep -Eq '\([0-9]+h[0-9]+m\)' <<<"$plain_rate_output"
grep -Eq '\([A-Z][a-z]{2}\)' <<<"$plain_rate_output"

# prompt cache: warm は残り時間、cold は復帰コスト、compact 直後はカウント停止
cache_output="$(printf '{"prompt_cache":{"warm":true,"ttl":"5m","expires_at":%s,"recache_tokens_if_cold":1000}}\n' "$((now + 200))" | bash "$STATUSLINE" | strip_ansi)"
[[ $cache_output == *'3m'[0-9][0-9]'s'* ]]

cold_output="$(printf '%s\n' '{"prompt_cache":{"warm":false,"ttl":"5m","expires_at":1,"recache_tokens_if_cold":45000}}' | bash "$STATUSLINE" | strip_ansi)"
[[ $cold_output == *'45k'* ]]

compacted_output="$(printf '%s\n' '{"prompt_cache":{"warm":true,"ttl":"5m","expires_at":4102444800,"recache_tokens_if_cold":null}}' | bash "$STATUSLINE" | strip_ansi)"
[[ $compacted_output == *'compacted'* ]]

# PR と Issue は OSC 8 ハイパーリンクにする
pr_output="$(printf '%s\n' '{"pr":{"number":7,"url":"https://github.com/u7chan/workstation-config/pull/7"}}' | bash "$STATUSLINE")"
[[ $(printf '%s' "$pr_output" | strip_ansi) == *'PR#7'* ]]
[[ $pr_output == *$'\033]8;;https://github.com/u7chan/workstation-config/pull/7'* ]]

repo_dir="$(mktemp -d)"
trap 'rm -rf "$repo_dir"' EXIT
git -C "$repo_dir" init -q
git -C "$repo_dir" checkout -q -b fix/863-status-line
git -C "$repo_dir" remote add origin https://github.com/u7chan/workstation-config

github_json="$(jq -cn --arg dir "$repo_dir" '{workspace:{current_dir:$dir,repo:{host:"github.com",owner:"u7chan",name:"workstation-config"}}}')"
issue_output="$(printf '%s\n' "$github_json" | bash "$STATUSLINE")"
[[ $(printf '%s' "$issue_output" | strip_ansi) == *'#863'* ]]
[[ $issue_output == *$'\033]8;;https://github.com/u7chan/workstation-config/issues/863'* ]]

# GitLab は issues のパスが /-/issues になる。issue マーカーの直前は区切り文字でもよい
git -C "$repo_dir" checkout -q -B fix/issue-820
gitlab_json="$(jq -cn --arg dir "$repo_dir" '{workspace:{current_dir:$dir,repo:{host:"gitlab.com",owner:"group/sub",name:"proj"}}}')"
gitlab_output="$(printf '%s\n' "$gitlab_json" | bash "$STATUSLINE")"
[[ $gitlab_output == *$'\033]8;;https://gitlab.com/group/sub/proj/-/issues/820'* ]]

# issue(s) を含む単語の途中や、prefix 直後の先頭ゼロは issue 番号として拾わない
for branch in fix/reissue-401-token feature/tissue-42 feature/02-parts-rename; do
  git -C "$repo_dir" checkout -q -B "$branch"
  plain_output="$(printf '%s\n' "$github_json" | bash "$STATUSLINE" | strip_ansi)"
  [[ $plain_output == 'Claude' ]]
done

printf 'Status line smoke checks passed.\n'
