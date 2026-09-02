#!/usr/bin/env bash
# shellcheck disable=SC2016
set -euo pipefail
ROOT_DIR="${ROOT_DIR:?ROOT_DIR must be exported by tests/static.sh}"

case "${1:-}" in
  keybindings)
    grep -Fxq '.pi/' "$ROOT_DIR/.gitignore"
    test -f "$ROOT_DIR/home/dot_pi/agent/keybindings.json"
    grep -Fqx '  "app.clipboard.pasteImage": ["alt+v"],' "$ROOT_DIR/home/dot_pi/agent/keybindings.json"
    grep -Fqx '  "app.message.dequeue": ["alt+up"]' "$ROOT_DIR/home/dot_pi/agent/keybindings.json"
    grep -Fq 'WORKSTATION_PI_SELECTED="$PI_SELECTED"' "$ROOT_DIR/bootstrap"
    grep -Fq 'rm -f -- "$HOME/.pi/agent/keybindings.json"' "$ROOT_DIR/bootstrap"
    grep -Fq 'ne (env "WORKSTATION_PI_SELECTED")' "$ROOT_DIR/home/.chezmoiignore"
    grep -Fqx '.pi/agent/keybindings.json' "$ROOT_DIR/home/.chezmoiignore"
    ;;
  web-search)
    # issue #182: pi-web-accessのweb-search.jsonはcreate属性で非機密デフォルトのみ配布
    test -f "$ROOT_DIR/home/dot_pi/create_web-search.json"
    grep -Fqx '  "workflow": "auto-summary"' "$ROOT_DIR/home/dot_pi/create_web-search.json"
    grep -Fq 'rm -f -- "$HOME/.pi/web-search.json"' "$ROOT_DIR/bootstrap"
    grep -Fq 'ne (env "WORKSTATION_PI_SELECTED")' "$ROOT_DIR/home/.chezmoiignore"
    grep -Fqx '.pi/web-search.json' "$ROOT_DIR/home/.chezmoiignore"
    ;;
  config)
    # ~/.pi/config.json はpiが読まない。modelOverridesは~/.pi/agent/models.jsonが正規パス
    test -f "$ROOT_DIR/home/dot_pi/agent/models.json"
    grep -Fqx '        "gpt-5.6-sol": { "contextWindow": 256384 },' "$ROOT_DIR/home/dot_pi/agent/models.json"
    grep -Fqx '        "gpt-5.6-luna": { "contextWindow": 256384 },' "$ROOT_DIR/home/dot_pi/agent/models.json"
    grep -Fqx '        "gpt-5.6-terra": { "contextWindow": 256384 }' "$ROOT_DIR/home/dot_pi/agent/models.json"
    grep -Fq 'rm -f -- "$HOME/.pi/agent/models.json"' "$ROOT_DIR/bootstrap"
    grep -Fq 'for ai_config_dir in .codex .claude .config/opencode .pi' "$ROOT_DIR/bootstrap"
    grep -Fqx '.pi/agent/models.json' "$ROOT_DIR/home/.chezmoiignore"
    ;;
  base-role-guard)
    for pi_package in pi-web-access pi-codex-image-gen pi-codex-conversion @ogulcancelik/pi-session-recall; do
      if grep -R -Fq "$pi_package" "$ROOT_DIR/ansible/roles/base"; then
        printf 'Pi package must not be managed by the base role: %s\n' "$pi_package" >&2
        exit 1
      fi
    done
    ;;
  runtime-data)
    # home/dot_pi/agent/keybindings.json と models.json、home/dot_pi/create_web-search.json のみがPiのGit管理対象ユーザー設定。
    if git -C "$ROOT_DIR" ls-files | grep -Fvx 'home/dot_pi/agent/keybindings.json' \
      | grep -Fvx 'home/dot_pi/agent/models.json' \
      | grep -Fvx 'home/dot_pi/create_web-search.json' \
      | grep -Eiq '(^|/)(web-search\.json|codex-image-gen\.json|pi-codex-conversion\.json|generated-images|dot_pi|pi/)(/|$)'; then
      printf 'Pi package settings, generated images, and runtime state must not be Git-managed.\n' >&2
      exit 1
    fi
    ;;
  *)
    printf 'Usage: %s <stage: keybindings|config|web-search|base-role-guard|runtime-data>\n' "$0" >&2
    exit 2
    ;;
esac
