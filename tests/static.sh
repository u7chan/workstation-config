#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly ROOT_DIR

bash -n "$ROOT_DIR/bootstrap"
"$ROOT_DIR/bootstrap" --help >/dev/null

grep -q '^MISE_LOCKED=1' "$ROOT_DIR/bootstrap"
grep -q '^node = "lts"' "$ROOT_DIR/mise/config.toml"
grep -q '^herdr = "latest"' "$ROOT_DIR/mise/config.toml"
test -s "$ROOT_DIR/mise/mise.lock"

if "$ROOT_DIR/bootstrap" invalid >/dev/null 2>&1; then
  printf 'Invalid profile was accepted.\n' >&2
  exit 1
fi

if command -v shellcheck >/dev/null 2>&1; then
  shellcheck "$ROOT_DIR/bootstrap" "$ROOT_DIR/tests/static.sh"
fi

if command -v ansible-playbook >/dev/null 2>&1; then
  ANSIBLE_CONFIG="$ROOT_DIR/ansible/ansible.cfg" \
    ansible-playbook \
    --inventory "$ROOT_DIR/ansible/inventory/localhost.yml" \
    --extra-vars workstation_profile=base \
    --syntax-check \
    "$ROOT_DIR/ansible/playbook.yml"
fi

if command -v yamllint >/dev/null 2>&1; then
  yamllint --config-file "$ROOT_DIR/.yamllint.yml" "$ROOT_DIR/ansible"
fi

if command -v ansible-lint >/dev/null 2>&1; then
  ANSIBLE_CONFIG="$ROOT_DIR/ansible/ansible.cfg" \
    ansible-lint "$ROOT_DIR/ansible/playbook.yml"
fi

printf 'Static checks passed.\n'
