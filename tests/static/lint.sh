#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="${ROOT_DIR:?ROOT_DIR must be exported by tests/static.sh}"

if command -v shellcheck >/dev/null 2>&1; then
  shellcheck \
    "$ROOT_DIR/bootstrap" \
    "$ROOT_DIR/home/modify_dot_bashrc" \
    "$ROOT_DIR/home/modify_dot_gitconfig" \
    "$ROOT_DIR/home/dot_config/workstation/shell/init.bash" \
    "$ROOT_DIR/home/dot_config/herdr/scripts/executable_status-agents.sh" \
    "$ROOT_DIR/home/dot_config/herdr/scripts/executable_status-datetime.sh" \
    "$ROOT_DIR/home/dot_config/herdr/scripts/executable_status-resources.sh" \
    "$ROOT_DIR/scripts/update-ai" \
    "$ROOT_DIR/tests/ai-clis-smoke.sh" \
    "$ROOT_DIR/tests/pi-packages-smoke.sh" \
    "$ROOT_DIR/tests/bootstrap-herdr-integration-order.sh" \
    "$ROOT_DIR/tests/wsl-restart-smoke.sh" \
    "$ROOT_DIR/tests/safe-chain-smoke.sh" \
    "$ROOT_DIR/tests/personal-cli-smoke.sh" \
    "$ROOT_DIR/tests/docker-smoke.sh" \
    "$ROOT_DIR/tests/cagent-smoke.sh" \
    "$ROOT_DIR/scripts/personal-bin/myupdate" \
    "$ROOT_DIR/tests/workstation-update-smoke.sh" \
    "$ROOT_DIR/scripts/personal-bin/myclaude" \
    "$ROOT_DIR/scripts/personal-bin/gac" \
    "$ROOT_DIR/scripts/personal-bin/gpc" \
    "$ROOT_DIR/scripts/personal-bin/http" \
    "$ROOT_DIR/scripts/personal-bin/http-lan" \
    "$ROOT_DIR/tests/static.sh" \
    "$ROOT_DIR/tests/static/"*.sh
else
  printf 'shellcheck is not installed; skipping shell checks.\n'
fi

if command -v ansible-playbook >/dev/null 2>&1; then
  ANSIBLE_CONFIG="$ROOT_DIR/ansible/ansible.cfg" \
    ansible-playbook \
    --inventory "$ROOT_DIR/ansible/inventory/localhost.yml" \
    --extra-vars workstation_profile=base \
    --syntax-check \
    "$ROOT_DIR/ansible/playbook.yml"
else
  printf 'ansible-playbook is not installed; skipping Ansible syntax check.\n'
fi

if command -v yamllint >/dev/null 2>&1; then
  yamllint --config-file "$ROOT_DIR/.yamllint.yml" "$ROOT_DIR/ansible"
else
  printf 'yamllint is not installed; skipping YAML lint.\n'
fi

if command -v ansible-lint >/dev/null 2>&1; then
  ANSIBLE_CONFIG="$ROOT_DIR/ansible/ansible.cfg" \
    ansible-lint "$ROOT_DIR/ansible/playbook.yml"
else
  printf 'ansible-lint is not installed; skipping Ansible lint.\n'
fi
