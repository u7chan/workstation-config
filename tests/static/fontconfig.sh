#!/usr/bin/env bash
# shellcheck disable=SC2016
set -euo pipefail
ROOT_DIR="${ROOT_DIR:?ROOT_DIR must be exported by tests/static.sh}"

case "${1:-}" in
  config)
    # Chromium 系の CJK フォールバックを日本語字形に固定する。fonts-wqy-zenhei の
    # 64-wqy-zenhei.conf が generic family の先頭へ中国語フォントを挿すため、
    # chezmoi 管理の fonts.conf で generic family の並びを上書きする。
    fonts_conf="$ROOT_DIR/home/dot_config/fontconfig/fonts.conf"
    test -f "$fonts_conf"
    grep -Fq '<family>sans-serif</family>' "$fonts_conf"
    grep -Fq '<family>serif</family>' "$fonts_conf"
    grep -Fq '<family>monospace</family>' "$fonts_conf"
    grep -Fq '<family>Noto Sans CJK JP</family>' "$fonts_conf"
    grep -Fq '<family>Noto Serif CJK JP</family>' "$fonts_conf"
    grep -Fq '<family>Noto Sans Mono CJK JP</family>' "$fonts_conf"
    # prefer は Latin 用の DejaVu を先に、CJK 用の Noto CJK JP を次に並べる。
    # この順序（DejaVu が先）を崩すと Latin の描画が Noto に変わる。
    grep -Fq "$(printf '      <family>DejaVu Sans</family>\n      <family>Noto Sans CJK JP</family>')" "$fonts_conf"
    grep -Fq "$(printf '      <family>DejaVu Serif</family>\n      <family>Noto Serif CJK JP</family>')" "$fonts_conf"
    grep -Fq "$(printf '      <family>DejaVu Sans Mono</family>\n      <family>Noto Sans Mono CJK JP</family>')" "$fonts_conf"
    grep -q '^  - fonts-noto-cjk$' "$ROOT_DIR/ansible/vars/main.yml"

    grep -Fq 'home/dot_config/fontconfig/fonts.conf' "$ROOT_DIR/home/README.md"
    grep -Fq '## 日本語フォント（CJKフォールバック）' "$ROOT_DIR/docs/workstation.md"
    grep -Fq 'fc-match -s sans-serif | grep -E' "$ROOT_DIR/docs/workstation.md"
    grep -Fq 'fontconfig/fonts.conf' "$ROOT_DIR/docs/roles-boundary.md"

    test -f "$ROOT_DIR/tests/fontconfig-smoke.sh"
    bash -n "$ROOT_DIR/tests/fontconfig-smoke.sh"

    # fonts.conf が fontconfig に読めることを確認する。壊れた XML でも fc-match は
    # 継続するため、stderr に出力が出ないことまで見る。
    if command -v fc-match >/dev/null 2>&1; then
      verification_home="$(mktemp -d)"
      trap 'rm -rf "$verification_home"' EXIT
      mkdir -p "$verification_home/.config/fontconfig"
      cp "$fonts_conf" "$verification_home/.config/fontconfig/fonts.conf"
      if ! fontconfig_error="$(HOME="$verification_home" fc-match -s sans-serif 2>&1 >/dev/null)"; then
        printf 'fc-match failed for the managed fonts.conf.\n' >&2
        exit 1
      fi
      if [ -n "$fontconfig_error" ]; then
        printf 'fontconfig reported an error for the managed fonts.conf:\n%s\n' \
          "$fontconfig_error" >&2
        exit 1
      fi
    else
      printf 'fc-match is not installed; skipping fontconfig parse check.\n' >&2
    fi
    ;;
  *)
    printf 'Usage: %s <stage: config>\n' "$0" >&2
    exit 2
    ;;
esac
