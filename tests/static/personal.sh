#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="${ROOT_DIR:?ROOT_DIR must be exported by tests/static.sh}"

case "${1:-}" in
  syntax)
    bash -n "$ROOT_DIR/scripts/personal-bin/myupdate"
    ;;
  role)
    for personal_cli in myclaude gac gpc http http-lan; do
      bash -n "$ROOT_DIR/scripts/personal-bin/$personal_cli"
      grep -q -- "- $personal_cli" "$ROOT_DIR/ansible/roles/personal/tasks/personal_cli.yml"
    done

    grep -Fq 'path: "{{ ansible_facts['\''user_dir'\''] }}/.local/bin/clp"' \
      "$ROOT_DIR/ansible/roles/personal/tasks/personal_cli.yml"
    grep -Fq 'state: absent' "$ROOT_DIR/ansible/roles/personal/tasks/personal_cli.yml"
    grep -Fq 'src: "{{ playbook_dir }}/../scripts/personal-bin/myupdate"' \
      "$ROOT_DIR/ansible/roles/personal/tasks/update_ai.yml"
    grep -Fq 'dest: "{{ ansible_facts['\''user_dir'\''] }}/.local/bin/myupdate"' \
      "$ROOT_DIR/ansible/roles/personal/tasks/update_ai.yml"
    grep -Fq 'src: myupdate.conf.j2' "$ROOT_DIR/ansible/roles/personal/tasks/update_ai.yml"
    grep -Fq 'dest: "{{ ansible_facts['\''user_dir'\''] }}/.config/workstation/myupdate.conf"' \
      "$ROOT_DIR/ansible/roles/personal/tasks/update_ai.yml"
    ;;
  *)
    printf 'Usage: %s <stage: syntax|role>\n' "$0" >&2
    exit 2
    ;;
esac
