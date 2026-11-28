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
    grep -Fq 'AGENT_HARNESS_HOME' "$agent_harness_tasks"
    grep -Fq 'AGENT_HARNESS_REPO_URL' "$agent_harness_tasks"
    grep -Fq '/usr/bin/flock' "$agent_harness_tasks"
    if grep -Fq -- '--link-dir' "$agent_harness_tasks"; then
      printf 'agent_harness.yml must use the recorded/default link dirs, not --link-dir\n' >&2
      exit 1
    fi
    ;;
  antigravity-cleanup)
    # Execute the task file instead of grepping it: the cleanup skips files that
    # do not exist and must also stay a no-op when antigravity is not selected.
    # A when-clause that dereferences a skipped stat result only shows up here.
    if ! command -v ansible-playbook >/dev/null 2>&1; then
      printf 'ansible-playbook is not installed; skipping the Antigravity cleanup run.\n'
      exit 0
    fi
    cleanup_test_dir="$(mktemp -d)"
    trap 'rm -rf "$cleanup_test_dir"' EXIT
    cleanup_tasks="$ROOT_DIR/ansible/roles/personal/tasks/antigravity.yml"
    cat >"$cleanup_test_dir/playbook.yml" <<'PLAYBOOK'
- hosts: localhost
  connection: local
  gather_facts: false
  vars:
    ansible_facts:
      user_dir: "{{ lookup('env', 'ANTIGRAVITY_TEST_HOME') }}"
  tasks:
    - ansible.builtin.import_tasks: TASKS
PLAYBOOK
    sed -i "s|TASKS|$cleanup_tasks|" "$cleanup_test_dir/playbook.yml"

    run_cleanup() {
      local name=$1 selection=$2
      mkdir -p "$cleanup_test_dir/$name/home"
      cat >"$cleanup_test_dir/$name/home/.bashrc" <<'BASHRC'
# user configuration
export PATH="$HOME/.local/bin:$PATH"

# Added by Antigravity CLI installer
export PATH="/home/example/.local/bin:$PATH"
BASHRC
      ANTIGRAVITY_TEST_HOME="$cleanup_test_dir/$name/home" \
      ANSIBLE_CONFIG="$ROOT_DIR/ansible/ansible.cfg" \
        ansible-playbook \
        --inventory localhost, \
        --connection local \
        --extra-vars "personal_ai_tools=$selection" \
        "$cleanup_test_dir/playbook.yml" >"$cleanup_test_dir/$name/run.out" 2>&1 || {
        printf 'Antigravity cleanup failed for personal_ai_tools=%s:\n' "$selection" >&2
        cat "$cleanup_test_dir/$name/run.out" >&2
        exit 1
      }
      if grep -Fq 'Added by Antigravity CLI installer' "$cleanup_test_dir/$name/home/.bashrc"; then
        printf 'Antigravity cleanup kept the installer block for personal_ai_tools=%s.\n' \
          "$selection" >&2
        exit 1
      fi
    }

    run_cleanup selected '["antigravity"]'
    # The unselected cases only have to stay runnable and leave the file alone.
    for selection_name in '[]' '["opencode"]'; do
      cleanup_case="unselected-${selection_name//[^[:alnum:]]/}"
      mkdir -p "$cleanup_test_dir/$cleanup_case/home"
      cat >"$cleanup_test_dir/$cleanup_case/home/.bashrc" <<'BASHRC'
# user configuration
export PATH="$HOME/.local/bin:$PATH"

# Added by Antigravity CLI installer
export PATH="/home/example/.local/bin:$PATH"
BASHRC
      cp "$cleanup_test_dir/$cleanup_case/home/.bashrc" "$cleanup_test_dir/$cleanup_case/before"
      ANTIGRAVITY_TEST_HOME="$cleanup_test_dir/$cleanup_case/home" \
      ANSIBLE_CONFIG="$ROOT_DIR/ansible/ansible.cfg" \
        ansible-playbook \
        --inventory localhost, \
        --connection local \
        --extra-vars "personal_ai_tools=$selection_name" \
        "$cleanup_test_dir/playbook.yml" >"$cleanup_test_dir/$cleanup_case/run.out" 2>&1 || {
        printf 'Antigravity cleanup failed for personal_ai_tools=%s:\n' "$selection_name" >&2
        cat "$cleanup_test_dir/$cleanup_case/run.out" >&2
        exit 1
      }
      if ! cmp -s "$cleanup_test_dir/$cleanup_case/before" \
        "$cleanup_test_dir/$cleanup_case/home/.bashrc"; then
        printf 'Antigravity cleanup modified .bashrc for personal_ai_tools=%s.\n' \
          "$selection_name" >&2
        exit 1
      fi
    done

    # The selected case must keep the user line and drop only the installer pair.
    grep -Fqx 'export PATH="$HOME/.local/bin:$PATH"' "$cleanup_test_dir/selected/home/.bashrc" || {
      printf 'Antigravity cleanup removed a user-written PATH line.\n' >&2
      exit 1
    }
    ;;
  *)
    printf 'Usage: %s <stage: syntax|role|antigravity-cleanup>\n' "$0" >&2
    exit 2
    ;;
esac
