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

    # fonts.conf が XML として well-formed か確かめる。fontconfig は壊れた設定を
    # 黙って読み飛ばす（fc-match は exit 0 のまま stderr に出すだけ）ため、
    # CI（ubuntu-slim）のように fc-match が無い環境でも検出できるよう python3 で見る。
    # python3 は ansible-core の前提でもあるので static job には必ず存在する。
    if ! command -v python3 >/dev/null 2>&1; then
      printf 'python3 is required for the fonts.conf well-formedness check.\n' >&2
      exit 1
    fi
    python3 -c 'import sys, xml.etree.ElementTree as ET; ET.parse(sys.argv[1])' "$fonts_conf"

    # fontconfig が実際に読めるかは fc-match のある環境でだけ確かめる。
    # 無い場合は XML チェックだけになり、ここはスキップされる。
    if command -v fc-match >/dev/null 2>&1; then
      verification_home="$(mktemp -d)"
      trap 'rm -rf "$verification_home"' EXIT
      mkdir -p "$verification_home/.config/fontconfig"
      cp "$fonts_conf" "$verification_home/.config/fontconfig/fonts.conf"
      if ! fontconfig_error="$(HOME="$verification_home" \
        XDG_CONFIG_HOME="$verification_home/.config" \
        fc-match -s sans-serif 2>&1 >/dev/null)"; then
        printf 'fc-match failed for the managed fonts.conf.\n' >&2
        exit 1
      fi
      if [ -n "$fontconfig_error" ]; then
        printf 'fontconfig reported an error for the managed fonts.conf:\n%s\n' \
          "$fontconfig_error" >&2
        exit 1
      fi
    else
      printf 'fc-match is not installed; the runtime fontconfig check was skipped.\n' >&2
    fi
    ;;
  *)
    printf 'Usage: %s <stage: config>\n' "$0" >&2
    exit 2
    ;;
esac
