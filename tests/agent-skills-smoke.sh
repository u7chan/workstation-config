#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly ROOT_DIR
readonly LOCKED_GIT="$ROOT_DIR/scripts/workstation-update-locked-git"

test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT

playbook="$test_dir/playbook.yml"
cat >"$playbook" <<EOF
---
- name: Test agent-skills configuration
  hosts: localhost
  connection: local
  gather_facts: true
  vars:
    agent_skills_repo_url: "https://github.com/u7chan/agent-skills.git"
    agent_skills_dest: "{{ test_home }}/workspace/agent-skills"
  tasks:
    - name: Use isolated home
      ansible.builtin.set_fact:
        ansible_facts: "{{ ansible_facts | combine({'user_dir': test_home}) }}"

    - name: Configure agent skills
      ansible.builtin.include_tasks: "$ROOT_DIR/ansible/roles/personal/tasks/agent_skills.yml"
EOF

run_playbook() {
  mkdir -p "$1/.local/bin"
  cp "$LOCKED_GIT" "$1/.local/bin/workstation-update-locked-git"
  chmod +x "$1/.local/bin/workstation-update-locked-git"
  ANSIBLE_LOCAL_TEMP="$test_dir/ansible-local" \
    ANSIBLE_REMOTE_TEMP="$test_dir/ansible-remote" \
    ansible-playbook \
      --inventory localhost, \
      --extra-vars "test_home=$1" \
      "$playbook"
}

normal_home="$test_dir/normal-home"
first_output="$(run_playbook "$normal_home")"
grep -Eq 'changed=[1-9][0-9]*([[:space:]]|$)' <<<"$first_output"
[[ $(git -C "$normal_home/workspace/agent-skills" remote get-url origin) == \
  https://github.com/u7chan/agent-skills.git ]]
[[ -n "$(ls -1A "$normal_home/.claude/skills/")" ]]
[[ -n "$(ls -1A "$normal_home/.codex/skills/")" ]]

second_output="$(run_playbook "$normal_home")"
grep -Eq 'changed=0([[:space:]]|$)' <<<"$second_output"

file_home="$test_dir/existing-file-home"
mkdir -p "$file_home/.claude"
printf 'keep me\n' >"$file_home/.claude/skills"
if file_output="$(run_playbook "$file_home" 2>&1)"; then
  printf 'Existing skills file caused setup-skills.py to fail.\n' >&2
  exit 1
fi
grep -Fqx 'keep me' "$file_home/.claude/skills"

directory_home="$test_dir/existing-directory-home"
mkdir -p "$directory_home/.codex/skills"
printf 'keep me too\n' >"$directory_home/.codex/skills/git-branch-create"
if directory_output="$(run_playbook "$directory_home" 2>&1)"; then
  printf 'Existing skills directory was unexpectedly overwritten.\n' >&2
  exit 1
fi
grep -Fq '[skip]' <<<"$directory_output"
grep -Fqx 'keep me too' "$directory_home/.codex/skills/git-branch-create"

printf 'Agent skills smoke checks passed.\n'
