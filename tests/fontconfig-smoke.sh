#!/usr/bin/env bash
set -euo pipefail

# Chromium 系は fontconfig の問い合わせにページの lang を渡さないため、CJK の
# フォールバック先は lang 無しで解決した generic family の並び順で決まる。
# fonts-wqy-zenhei の 64-wqy-zenhei.conf はその並びの先頭に中国語フォント
# (WenQuanYi Zen Hei) を挿すので、日本語フォントがそれより前に来ていることを
# 確認する。この test は読み取り専用で、設定もフォントも変更しない。

fonts_conf="${XDG_CONFIG_HOME:-$HOME/.config}/fontconfig/fonts.conf"
if [ ! -f "$fonts_conf" ]; then
  printf '%s is missing. Run ./bootstrap or chezmoi apply first.\n' "$fonts_conf" >&2
  exit 1
fi

fail=0

check_family() {
  local family="$1" listing japanese_line chinese_line
  listing="$(fc-match -s "$family")"

  japanese_line="$(printf '%s\n' "$listing" \
    | grep -nE '"(Noto (Sans|Serif|Sans Mono) CJK JP)"' \
    | head -n 1 | cut -d: -f1 || true)"
  chinese_line="$(printf '%s\n' "$listing" \
    | grep -nE '"WenQuanYi Zen Hei( Mono)?"' \
    | head -n 1 | cut -d: -f1 || true)"

  if [ -z "$japanese_line" ]; then
    printf '%s: Japanese font (Noto CJK JP) is not resolved. Is fonts-noto-cjk installed?\n' \
      "$family" >&2
    fail=1
    return
  fi

  if [ -n "$chinese_line" ] && [ "$japanese_line" -gt "$chinese_line" ]; then
    printf '%s: WenQuanYi Zen Hei is resolved before Noto CJK JP (line %s vs %s).\n' \
      "$family" "$chinese_line" "$japanese_line" >&2
    fail=1
    return
  fi

  printf '%s: OK (Noto CJK JP line %s)\n' "$family" "$japanese_line"
}

for family in sans-serif serif monospace; do
  check_family "$family"
done

# lang=ja の結果だけでは判断できない。Chromium が lang を渡さないため、
# ここが Noto を返しても描画が中国語字形のままになる場合がある。
printf 'lang=ja resolution (informational): %s\n' "$(fc-match sans-serif:lang=ja)"

if [ "$fail" -ne 0 ]; then
  exit 1
fi
