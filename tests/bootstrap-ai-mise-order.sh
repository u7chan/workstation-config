#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly ROOT_DIR

base_tasks="$ROOT_DIR/ansible/roles/base/tasks/main.yml"
personal_tasks="$ROOT_DIR/ansible/roles/personal/tasks/main.yml"
playbook="$ROOT_DIR/ansible/playbook.yml"

line_number() {
  grep -n -m1 -F -- "$1" "$2" | cut -d: -f1
}

config_line="$(line_number '- name: Install mise global configuration' "$base_tasks")"
lockfile_line="$(line_number '- name: Install mise lockfile' "$base_tasks")"
trust_line="$(line_number '- name: Trust mise global configuration' "$base_tasks")"
herdr_upgrade_line="$(line_number '- name: Resolve latest Herdr release before locked mise install' "$base_tasks")"
herdr_binary_line="$(line_number '- name: Resolve installed Herdr binary' "$base_tasks")"
herdr_plugins_line="$(line_number '- name: Install Herdr plugins' "$base_tasks")"
install_line="$(line_number '- name: Install locked mise tools before personal role tasks' "$base_tasks")"
[[ $config_line -lt $lockfile_line && $lockfile_line -lt $trust_line && \
  $trust_line -lt $herdr_upgrade_line && $herdr_upgrade_line -lt $herdr_binary_line && \
  $herdr_binary_line -lt $herdr_plugins_line && $herdr_plugins_line -lt $install_line ]] || {
  printf 'bootstrap-ai-mise-order: mise configuration, lock, trust, Herdr resolution, plugin install, and locked install must be ordered.\n' >&2
  exit 1
}

herdr_upgrade_task="$(awk '
  $0 == "- name: Resolve latest Herdr release before locked mise install" { capture = 1 }
  capture && /^- name: / && $0 != "- name: Resolve latest Herdr release before locked mise install" { exit }
  capture { print }
' "$base_tasks")"
grep -Fqx '      - /usr/bin/env' <<<"$herdr_upgrade_task" &&
grep -Fqx '      - -u' <<<"$herdr_upgrade_task" &&
grep -Fqx '      - MISE_LOCKED' <<<"$herdr_upgrade_task" &&
grep -Fqx '      - /usr/bin/flock' <<<"$herdr_upgrade_task" &&
grep -Fqx '      - "{{ ansible_facts['\''user_dir'\''] }}/.local/state/workstation-update/update.lock"' \
  <<<"$herdr_upgrade_task" &&
grep -Fqx '      - "{{ ansible_facts['\''user_dir'\''] }}/.local/bin/mise"' <<<"$herdr_upgrade_task" &&
grep -Fqx '      - upgrade' <<<"$herdr_upgrade_task" &&
grep -Fqx '      - herdr' <<<"$herdr_upgrade_task" || {
  printf 'bootstrap-ai-mise-order: Herdr must be upgraded through mise before locked install.\n' >&2
  exit 1
}

herdr_binary_task="$(awk '
  $0 == "- name: Resolve installed Herdr binary" { capture = 1 }
  capture && /^- name: / && $0 != "- name: Resolve installed Herdr binary" { exit }
  capture { print }
' "$base_tasks")"
grep -Fqx '      - /usr/bin/env' <<<"$herdr_binary_task" &&
grep -Fqx '      - -u' <<<"$herdr_binary_task" &&
grep -Fqx '      - MISE_LOCKED' <<<"$herdr_binary_task" &&
grep -Fqx '      - "{{ ansible_facts['\''user_dir'\''] }}/.local/bin/mise"' <<<"$herdr_binary_task" &&
grep -Fqx '      - which' <<<"$herdr_binary_task" &&
grep -Fqx '      - herdr' <<<"$herdr_binary_task" || {
  printf 'bootstrap-ai-mise-order: Herdr binary must be resolved after upgrade without locked mode.\n' >&2
  exit 1
}

herdr_plugins_task="$(awk '
  $0 == "- name: Install Herdr plugins" { capture = 1 }
  capture && /^- name: / && $0 != "- name: Install Herdr plugins" { exit }
  capture { print }
' "$base_tasks")"
grep -Fqx '      - "{{ herdr_binary.stdout | trim }}"' <<<"$herdr_plugins_task" &&
grep -Fqx '    MISE_CONFIG_FILE: "{{ ansible_facts['\''user_dir'\''] }}/.config/mise/config.toml"' \
  <<<"$herdr_plugins_task" || {
  printf 'bootstrap-ai-mise-order: Herdr plugins must use the resolved binary and mise config.\n' >&2
  exit 1
}

locked_install_task="$(awk '
  $0 == "- name: Install locked mise tools before personal role tasks" { capture = 1 }
  capture && /^- name: / && $0 != "- name: Install locked mise tools before personal role tasks" { exit }
  capture { print }
' "$base_tasks")"
grep -Fqx '    MISE_LOCKED: "1"' <<<"$locked_install_task" || {
  printf 'bootstrap-ai-mise-order: locked base mise install must set MISE_LOCKED=1.\n' >&2
  exit 1
}
grep -Fqx '      - /usr/bin/flock' <<<"$locked_install_task"
grep -Fqx '      - "{{ ansible_facts['\''user_dir'\''] }}/.local/state/workstation-update/update.lock"' \
  <<<"$locked_install_task"
grep -Fq '{{ ansible_facts['\''user_dir'\''] }}/.local/bin' <<<"$locked_install_task" || {
  printf 'bootstrap-ai-mise-order: locked base mise install must add ~/.local/bin to PATH.\n' >&2
  exit 1
}

grep -Fq '/.local/bin/update-ai' "$personal_tasks"
grep -Fq 'MISE_LOCKED: "1"' "$personal_tasks"
grep -Fq "['/usr/bin/flock', ansible_facts['user_dir'] + '/.local/state/workstation-update/update.lock'" \
  "$personal_tasks"
grep -Fq 'src: myupdate.conf.j2' "$personal_tasks"
grep -Fq 'dest: "{{ ansible_facts['\''user_dir'\''] }}/.config/workstation/myupdate.conf"' \
  "$personal_tasks"
grep -Fqx "WORKSTATION_UPDATE_AI_TOOLS=\"{{ personal_ai_tools | join(',') }}\"" \
  "$ROOT_DIR/ansible/roles/personal/templates/myupdate.conf.j2"
grep -Fq '/usr/bin/flock "$HOME/.local/state/workstation-update/update.lock"' \
  "$ROOT_DIR/bootstrap"

base_role_line="$(line_number '- role: base' "$playbook")"
personal_role_line="$(line_number '- role: personal' "$playbook")"
[[ $base_role_line -lt $personal_role_line ]] || {
  printf 'bootstrap-ai-mise-order: base role must precede personal role.\n' >&2
  exit 1
}

test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT
test_home="$test_dir/home"
linux_bin="$test_dir/linux-bin"
windows_bin="$test_dir/windows-npm"
log="$test_dir/commands.log"
mkdir -p "$test_home/.local/bin" "$test_home/.safe-chain/scripts" "$linux_bin" "$windows_bin"

cat >"$test_home/.local/bin/mise" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "$1" in
  exec)
    [[ $2 == node && $3 == -- ]]
    shift 3
    printf 'mise exec node\n' >>"$TEST_INSTALL_LOG"
    PATH="$TEST_LINUX_BIN:$PATH" exec "$@"
    ;;
  *)
    printf 'unexpected mise command: %s\n' "$*" >&2
    exit 1
    ;;
esac
EOF

cat >"$test_home/.safe-chain/scripts/init-posix.sh" <<'EOF'
npm() { command npm "$@"; }
EOF

cat >"$linux_bin/npm" <<'EOF'
#!/usr/bin/env bash
printf 'linux npm %s\n' "$*" >>"$TEST_INSTALL_LOG"
EOF

cat >"$linux_bin/node" <<'EOF'
#!/usr/bin/env bash
printf 'linux node %s\n' "$*" >>"$TEST_INSTALL_LOG"
EOF

cat >"$linux_bin/codex" <<'EOF'
#!/usr/bin/env bash
printf 'linux codex %s\n' "$*" >>"$TEST_INSTALL_LOG"
EOF

cat >"$linux_bin/pi" <<'EOF'
#!/usr/bin/env bash
printf 'linux pi %s\n' "$*" >>"$TEST_INSTALL_LOG"
EOF

cat >"$windows_bin/npm" <<'EOF'
#!/usr/bin/env bash
printf 'windows npm must not run\n' >&2
exit 127
EOF

cat >"$windows_bin/codex" <<'EOF'
#!/usr/bin/env bash
printf 'node: not found\n' >&2
exit 127
EOF

cat >"$windows_bin/pi" <<'EOF'
#!/usr/bin/env bash
printf 'windows pi must not run\n' >&2
exit 127
EOF
chmod +x "$test_home/.local/bin/mise" "$linux_bin/node" "$linux_bin/npm" "$linux_bin/codex" "$linux_bin/pi" \
  "$windows_bin/npm" "$windows_bin/codex" "$windows_bin/pi"

HOME="$test_home" \
PATH="$windows_bin:$PATH" \
TEST_INSTALL_LOG="$log" \
TEST_LINUX_BIN="$linux_bin" \
  "$ROOT_DIR/scripts/update-ai" --codex --pi >/dev/null

grep -Fqx 'mise exec node' "$log"
grep -Fqx 'linux npm install --global @openai/codex@latest' "$log"
grep -Fqx 'linux npm install --global --ignore-scripts @earendil-works/pi-coding-agent@latest' "$log"
grep -Fqx 'linux codex --version' "$log"
grep -Fqx 'linux pi --version' "$log"
if grep -Fq 'windows npm' "$log" || grep -Fq 'windows codex' "$log" || grep -Fq 'windows pi' "$log"; then
  printf 'bootstrap-ai-mise-order: Windows npm, Codex, or Pi shim was used.\n' >&2
  exit 1
fi

printf 'Bootstrap AI mise ordering checks passed.\n'
