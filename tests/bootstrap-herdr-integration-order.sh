#!/usr/bin/env bash
# shellcheck disable=SC2015,SC2016
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly ROOT_DIR

personal_tasks_dir="$ROOT_DIR/ansible/roles/personal/tasks"
personal_main="$personal_tasks_dir/main.yml"
update_ai_tasks="$personal_tasks_dir/update_ai.yml"
herdr_tasks="$personal_tasks_dir/herdr_integration.yml"
base_tasks_dir="$ROOT_DIR/ansible/roles/base/tasks"

line_number() {
  grep -n -m1 -F -- "$1" "$2" | cut -d: -f1
}

task_block() {
  local task_name=$1
  local task_file=$2
  awk -v task_name="$task_name" '
    $0 == "- name: " task_name { capture = 1 }
    capture && /^- name: / && $0 != "- name: " task_name { exit }
    capture { print }
  ' "$task_file"
}

update_line="$(line_number '- name: Update selected AI CLI tools' "$update_ai_tasks")"
update_include_line="$(line_number 'ansible.builtin.import_tasks: update_ai.yml' "$personal_main")"
herdr_include_line="$(line_number 'ansible.builtin.import_tasks: herdr_integration.yml' "$personal_main")"
directories_line="$(line_number '- name: Ensure Herdr integration config directories exist for selected AI CLI tools' "$herdr_tasks")"
install_line="$(line_number '- name: Install selected Herdr integrations' "$herdr_tasks")"
status_line="$(line_number '- name: Check selected Herdr integration status' "$herdr_tasks")"
assert_line="$(line_number '- name: Verify selected Herdr integrations are current' "$herdr_tasks")"

[[ $update_line -gt 0 && $update_include_line -gt 0 && \
  $update_include_line -lt $herdr_include_line && $herdr_include_line -gt 0 && \
  $directories_line -lt $install_line && $install_line -lt $status_line && \
  $status_line -lt $assert_line ]] || {
  printf 'bootstrap-herdr-integration-order: AI CLI update, directories, install, status, and assertion must be ordered.\n' >&2
  exit 1
}

directories_task="$(task_block 'Ensure Herdr integration config directories exist for selected AI CLI tools' "$herdr_tasks")"
for config_path in .codex .claude .config/opencode .pi/agent; do
  grep -Fqx "      path: $config_path" <<<"$directories_task" || {
    printf 'bootstrap-herdr-integration-order: missing Herdr config directory %s.\n' "$config_path" >&2
    exit 1
  }
done
grep -Fq 'when: item.name in personal_ai_tools' <<<"$directories_task" || {
  printf 'bootstrap-herdr-integration-order: config directories must be limited to selected AI CLI tools.\n' >&2
  exit 1
}
grep -Fq 'mode: "0700"' <<<"$directories_task" || {
  printf 'bootstrap-herdr-integration-order: AI CLI config directories must not be made world-readable.\n' >&2
  exit 1
}

install_task="$(task_block 'Install selected Herdr integrations' "$herdr_tasks")"
grep -Fqx '      - integration' <<<"$install_task" &&
grep -Fqx '      - install' <<<"$install_task" &&
grep -Fqx '      - "{{ item }}"' <<<"$install_task" &&
grep -Fq 'loop: "{{ personal_ai_tools | unique | list }}"' <<<"$install_task" &&
grep -Fq 'personal_ai_tools | length > 0' <<<"$install_task" &&
grep -Fq '/usr/bin/flock' <<<"$install_task" || {
  printf 'bootstrap-herdr-integration-order: selected Herdr integration install task is incomplete.\n' >&2
  exit 1
}
grep -Fq 'herdr_binary.stdout | trim' <<<"$install_task" || {
  printf 'bootstrap-herdr-integration-order: integration install must use the resolved Herdr binary.\n' >&2
  exit 1
}

status_task="$(task_block 'Check selected Herdr integration status' "$herdr_tasks")"
grep -Fqx '      - integration' <<<"$status_task" &&
grep -Fqx '      - status' <<<"$status_task" &&
grep -Fq 'register: herdr_integration_status' <<<"$status_task" &&
grep -Fq 'personal_ai_tools | length > 0' <<<"$status_task" || {
  printf 'bootstrap-herdr-integration-order: selected Herdr integration status task is incomplete.\n' >&2
  exit 1
}

assert_task="$(task_block 'Verify selected Herdr integrations are current' "$herdr_tasks")"
grep -Fq "': current '" <<<"$assert_task" &&
grep -Fq 'herdr_integration_status.stdout_lines' <<<"$assert_task" &&
grep -Fq 'personal_ai_tools | unique | list' <<<"$assert_task" || {
  printf 'bootstrap-herdr-integration-order: selected Herdr integrations must be asserted as current.\n' >&2
  exit 1
}

if grep -Eq 'integration[[:space:]]+(install|uninstall|status)' "$base_tasks_dir"/*.yml; then
  printf 'bootstrap-herdr-integration-order: base role must not manage AI CLI integrations.\n' >&2
  exit 1
fi
if grep -Eq 'integration[[:space:]]+uninstall' "$personal_tasks_dir"/*.yml; then
  printf 'bootstrap-herdr-integration-order: personal role must not remove non-selected integrations.\n' >&2
  exit 1
fi

chezmoi_apply_line="$(line_number 'chezmoi" apply --source "$ROOT_DIR/home" --no-tty --force' "$ROOT_DIR/bootstrap")"
restrict_directories_line="$(awk -v apply_line="$chezmoi_apply_line" '
  NR > apply_line && $0 == "restrict_ai_config_directories" { print NR; exit }
' "$ROOT_DIR/bootstrap")"
[[ -n $restrict_directories_line && $chezmoi_apply_line -lt $restrict_directories_line ]] || {
  printf 'bootstrap-herdr-integration-order: AI CLI config directories must be restricted after chezmoi apply.\n' >&2
  exit 1
}
grep -Fq 'for ai_config_dir in .codex .claude .config/opencode .pi/agent' "$ROOT_DIR/bootstrap" || {
  printf 'bootstrap-herdr-integration-order: post-chezmoi directory restriction list is incomplete.\n' >&2
  exit 1
}
grep -Fq 'ansible_extra_vars=(--extra-vars "{\"workstation_profile\":\"$PROFILE\"}")' "$ROOT_DIR/bootstrap" || {
  printf 'bootstrap-herdr-integration-order: bootstrap profile extra vars must use a JSON object.\n' >&2
  exit 1
}
grep -Fq 'ansible_extra_vars+=(--extra-vars "{\"personal_ai_tools\":$PERSONAL_AI_TOOLS_EXTRA_VAR}")' "$ROOT_DIR/bootstrap" || {
  printf 'bootstrap-herdr-integration-order: personal AI tool subset must be passed as a JSON array.\n' >&2
  exit 1
}
grep -Fq 'if [[ ${WORKSTATION_PERSONAL_AI_TOOLS+x} == x ]]; then' "$ROOT_DIR/bootstrap" || {
  printf 'bootstrap-herdr-integration-order: empty personal AI subset must be distinguishable from an unset variable.\n' >&2
  exit 1
}
grep -Fq "PERSONAL_AI_TOOLS_EXTRA_VAR='[]'" "$ROOT_DIR/bootstrap" || {
  printf 'bootstrap-herdr-integration-order: empty personal AI subset must be passed as an empty JSON array.\n' >&2
  exit 1
}
grep -Fq 'trap restrict_ai_config_directories EXIT' "$ROOT_DIR/bootstrap" || {
  printf 'bootstrap-herdr-integration-order: AI CLI config directories must be restricted if chezmoi apply fails.\n' >&2
  exit 1
}

printf 'Bootstrap Herdr integration ordering checks passed.\n'
