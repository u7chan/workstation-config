#!/usr/bin/env bash
# shellcheck disable=SC2016
set -euo pipefail
ROOT_DIR="${ROOT_DIR:?ROOT_DIR must be exported by tests/static.sh}"

case "${1:-}" in
  wsl-workaround)
    workaround_tasks="$ROOT_DIR/ansible/roles/base/tasks/systemd_workaround.yml"
    workaround_handlers="$ROOT_DIR/ansible/roles/base/handlers/main.yml"
    grep -Fq '/etc/systemd/system/user@.service.d/wsl-cgroup-workaround.conf' "$workaround_tasks"
    grep -Fq 'DelegateSubgroup=' "$workaround_tasks"
    grep -Fq 'distribution_version"] is version("26.04", "==")' "$workaround_tasks"
    grep -Fq '"microsoft" in ansible_facts["kernel"] | lower' "$workaround_tasks"
    grep -Fq 'systemd 259' "$workaround_tasks"
    grep -Fq 'check_mode: false' "$workaround_tasks"
    grep -Fq 'daemon_reload: true' "$workaround_handlers"
    grep -Fq 'systemctl is-active --quiet "$user_unit"' "$ROOT_DIR/tests/wsl-restart-smoke.sh"
    grep -Fq 'systemctl --user is-system-running' "$ROOT_DIR/tests/wsl-restart-smoke.sh"
    ;;
  vars-git)
    grep -q '^  - git$' "$ROOT_DIR/ansible/vars/main.yml"
    ;;
  vars-packages)
    grep -q '^  - jq$' "$ROOT_DIR/ansible/vars/main.yml"
    grep -q '^  - postgresql-client$' "$ROOT_DIR/ansible/vars/main.yml"
    ;;
  *)
    printf 'Usage: %s <stage: wsl-workaround|vars-git|vars-packages>\n' "$0" >&2
    exit 2
    ;;
esac
