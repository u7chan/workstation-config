#!/usr/bin/env bash
# shellcheck disable=SC2016
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

    grep -Fq 'src: "{{ playbook_dir }}/../scripts/personal-bin/myupdate"' \
      "$ROOT_DIR/ansible/roles/personal/tasks/update_ai.yml"
    grep -Fq 'dest: "{{ ansible_facts['\''user_dir'\''] }}/.local/bin/myupdate"' \
      "$ROOT_DIR/ansible/roles/personal/tasks/update_ai.yml"
    grep -Fq 'src: myupdate.conf.j2' "$ROOT_DIR/ansible/roles/personal/tasks/update_ai.yml"
    grep -Fq 'dest: "{{ ansible_facts['\''user_dir'\''] }}/.config/workstation/myupdate.conf"' \
      "$ROOT_DIR/ansible/roles/personal/tasks/update_ai.yml"

    grep -Fq 'import_tasks: agent_harness.yml' \
      "$ROOT_DIR/ansible/roles/personal/tasks/main.yml"
    grep -Fq 'personal_agent_harness_sha: bde7b2f7399dbc13f601aa4ac7730903e197fb29' \
      "$ROOT_DIR/ansible/roles/personal/defaults/main.yml"
    grep -Fq 'personal_agent_harness_migrate_pi: false' \
      "$ROOT_DIR/ansible/roles/personal/defaults/main.yml"
    agent_harness_tasks="$ROOT_DIR/ansible/roles/personal/tasks/agent_harness.yml"
    grep -Fq 'personal_agent_harness_current.stat.exists' "$agent_harness_tasks"
    grep -Fq 'scripts/skill-distribution/dist.sh' "$agent_harness_tasks"
    grep -Fq -- '--replace-links' "$agent_harness_tasks"
    grep -Fq 'personal_herdr_env' "$agent_harness_tasks"
    grep -Fq 'pi remove git:github.com/u7chan/agent-harness' "$agent_harness_tasks"
    grep -Fq '.claude/skills' "$agent_harness_tasks"
    grep -Fq 'run_agent_harness' "$ROOT_DIR/scripts/personal-bin/myupdate"
    grep -Fq 'current/scripts/skill-distribution/dist.sh' "$ROOT_DIR/scripts/personal-bin/myupdate"
    grep -Fq '"$dist" status' "$ROOT_DIR/scripts/personal-bin/myupdate"
    ;;
  *)
    printf 'Usage: %s <stage: syntax|role>\n' "$0" >&2
    exit 2
    ;;
esac
