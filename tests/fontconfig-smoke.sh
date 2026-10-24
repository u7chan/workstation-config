#!/usr/bin/env bash
set -euo pipefail

# Chromium 系は fontconfig の問い合わせにページの lang を渡さないため、CJK の
# フォールバック先は lang 無しで解決した generic family の並び順で決まる。
# fonts-wqy-zenhei の 64-wqy-zenhei.conf はその並びの先頭に中国語フォント
# (WenQuanYi Zen Hei) を挿すので、日本語フォントがそれより前に来ていることを
# 確認する。この test は読み取り専用で、設定もフォントも変更しない。

if ! command -v fc-match >/dev/null 2>&1; then
  printf 'fc-match is not installed. Install fontconfig first.\n' >&2
  exit 1
fi

fonts_conf="${XDG_CONFIG_HOME:-$HOME/.config}/fontconfig/fonts.conf"
if [ ! -f "$fonts_conf" ]; then
  printf '%s is missing. Run ./bootstrap or chezmoi apply first.\n' "$fonts_conf" >&2
  exit 1
fi

fail=0
chinese_pattern='"WenQuanYi Zen Hei( Mono)?"'

check_family() {
  local family="$1" japanese_family="$2"
  local listing japanese_line chinese_line

  listing="$(fc-match -s "$family")"

  # 期待する family を generic family ごとに固定する。serif / monospace の対応が
  # 入れ替わっていても、緩い正規表現だと通ってしまうため。
  japanese_line="$(printf '%s\n' "$listing" \
    | grep -nF -e "\"$japanese_family\"" \
    | head -n 1 | cut -d: -f1 || true)"
  chinese_line="$(printf '%s\n' "$listing" \
    | grep -nE "$chinese_pattern" \
    | head -n 1 | cut -d: -f1 || true)"

  if [ -z "$japanese_line" ]; then
    printf '%s: %s is not resolved. Is fonts-noto-cjk installed?\n' \
      "$family" "$japanese_family" >&2
    fail=1
    return
  fi

  if [ -n "$chinese_line" ] && [ "$japanese_line" -gt "$chinese_line" ]; then
    printf '%s: WenQuanYi Zen Hei is resolved before %s (line %s vs %s).\n' \
      "$family" "$japanese_family" "$chinese_line" "$japanese_line" >&2
    fail=1
    return
  fi

  printf '%s: OK (%s line %s)\n' "$family" "$japanese_family" "$japanese_line"
}

check_family sans-serif "Noto Sans CJK JP"
check_family serif "Noto Serif CJK JP"
check_family monospace "Noto Sans Mono CJK JP"

# lang=ja の結果だけでは判断できない。lang を条件にしたルールが効かない環境では、
# ここが Noto を返しても描画が中国語字形のままになる場合がある。
printf 'lang=ja resolution (informational): %s\n' "$(fc-match sans-serif:lang=ja)"

if [ "$fail" -ne 0 ]; then
  exit 1
fi
