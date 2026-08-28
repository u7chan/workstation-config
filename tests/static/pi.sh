#!/usr/bin/env bash
# shellcheck disable=SC2016
set -euo pipefail
ROOT_DIR="${ROOT_DIR:?ROOT_DIR must be exported by tests/static.sh}"

grep -Fxq '.pi/' "$ROOT_DIR/.gitignore"
test -f "$ROOT_DIR/home/dot_pi/agent/keybindings.json"
grep -Fqx '  "app.clipboard.pasteImage": ["alt+v"],' "$ROOT_DIR/home/dot_pi/agent/keybindings.json"
grep -Fqx '  "app.message.dequeue": ["alt+up"]' "$ROOT_DIR/home/dot_pi/agent/keybindings.json"
grep -Fq 'WORKSTATION_PI_SELECTED="$PI_SELECTED"' "$ROOT_DIR/bootstrap"
grep -Fq 'rm -f -- "$HOME/.pi/agent/keybindings.json"' "$ROOT_DIR/bootstrap"
grep -Fq 'ne (env "WORKSTATION_PI_SELECTED")' "$ROOT_DIR/home/.chezmoiignore"
grep -Fqx '.pi/agent/keybindings.json' "$ROOT_DIR/home/.chezmoiignore"

for pi_package in pi-web-access pi-codex-image-gen pi-codex-conversion @ogulcancelik/pi-session-recall; do
  if grep -R -Fq "$pi_package" "$ROOT_DIR/ansible/roles/base"; then
    printf 'Pi package must not be managed by the base role: %s\n' "$pi_package" >&2
    exit 1
  fi
done

# home/dot_pi/agent/keybindings.json is the only allowed Pi user config in Git.
if git -C "$ROOT_DIR" ls-files | grep -Fvx 'home/dot_pi/agent/keybindings.json' \
  | grep -Eiq '(^|/)(web-search\.json|codex-image-gen\.json|pi-codex-conversion\.json|generated-images|dot_pi|pi/)(/|$)'; then
  printf 'Pi package settings, generated images, and runtime state must not be Git-managed.\n' >&2
  exit 1
fi
