#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly ROOT_DIR

bash -n "$ROOT_DIR/bootstrap"
"$ROOT_DIR/bootstrap" --help >/dev/null

grep -Fq 'Bootstrap前の初期セットアップ' "$ROOT_DIR/README.md"
grep -Fq 'Workstation構成ガイド' "$ROOT_DIR/README.md"
grep -Fq 'wsl --install Ubuntu-26.04 --name sandbox' "$ROOT_DIR/docs/bootstrap-prerequisites.md"
grep -Fq 'wsl --unregister sandbox' "$ROOT_DIR/docs/bootstrap-prerequisites.md"
grep -Fq '破壊的操作' "$ROOT_DIR/docs/bootstrap-prerequisites.md"
test -f "$ROOT_DIR/docs/workstation.md"
grep -Fq '[初期セットアップ手順](bootstrap-prerequisites.md)' "$ROOT_DIR/docs/workstation.md"

grep -q '^MISE_LOCKED=1' "$ROOT_DIR/bootstrap"
grep -q 'chezmoi.*apply.*--no-tty.*--force' "$ROOT_DIR/bootstrap"
grep -q '^node = "lts"' "$ROOT_DIR/provisioning/mise/config.toml"
grep -q '^herdr = "latest"' "$ROOT_DIR/provisioning/mise/config.toml"
grep -Fq 'cagent = "github:u7chan/code-agent-launcher"' "$ROOT_DIR/provisioning/mise/config.toml"
grep -Fq 'cagent = { version = "0.1.2", filter_bins = "cagent" }' "$ROOT_DIR/provisioning/mise/config.toml"
test -s "$ROOT_DIR/provisioning/mise/mise.lock"
grep -q '^neovim = "0.12"' "$ROOT_DIR/provisioning/mise/config.toml"
grep -q '^yazi = "latest"' "$ROOT_DIR/provisioning/mise/config.toml"
test ! -e "$ROOT_DIR/mise/config.toml"
test ! -e "$ROOT_DIR/mise/mise.lock"
grep -Fq 'src: "{{ playbook_dir }}/../provisioning/mise/config.toml"' \
  "$ROOT_DIR/ansible/roles/base/tasks/main.yml"
grep -Fq 'src: "{{ playbook_dir }}/../provisioning/mise/mise.lock"' \
  "$ROOT_DIR/ansible/roles/base/tasks/main.yml"
if grep -R -Eiq 'apt(-get)?.*(install.*)?neovim|^[[:space:]]*-[[:space:]]*neovim$' \
  "$ROOT_DIR/ansible" "$ROOT_DIR/bootstrap"; then
  printf 'Neovim must not be managed by APT.\n' >&2
  exit 1
fi

test -f "$ROOT_DIR/home/dot_config/nvim/init.lua"
test -f "$ROOT_DIR/home/dot_config/nvim/lazy-lock.json"
bash -n "$ROOT_DIR/tests/neovim-smoke.sh"
bash -n "$ROOT_DIR/tests/yazi-smoke.sh"
bash -n "$ROOT_DIR/tests/safe-chain-smoke.sh"
bash -n "$ROOT_DIR/scripts/update-ai"
bash -n "$ROOT_DIR/tests/ai-clis-smoke.sh"
bash -n "$ROOT_DIR/tests/bootstrap-ai-mise-order.sh"
bash -n "$ROOT_DIR/tests/personal-cli-smoke.sh"
bash -n "$ROOT_DIR/tests/docker-smoke.sh"
bash -n "$ROOT_DIR/tests/agent-skills-smoke.sh"
bash -n "$ROOT_DIR/tests/cagent-smoke.sh"
for personal_cli in clp gac gpc http http-lan; do
  bash -n "$ROOT_DIR/scripts/personal-bin/$personal_cli"
  grep -q -- "- $personal_cli" "$ROOT_DIR/ansible/roles/personal/tasks/main.yml"
done

test -f "$ROOT_DIR/home/dot_config/yazi/yazi.toml"
test -f "$ROOT_DIR/home/dot_config/yazi/package.toml"
test -f "$ROOT_DIR/home/dot_config/yazi/.gitignore"
if find "$ROOT_DIR/home/dot_config/yazi" -mindepth 1 \( \
  -type d \( -name plugins -o -name flavors -o -name cache -o -name history -o -name preview -o -name state \) -o \
  -type f -name '*.log' \
\) | grep -q .; then
  printf 'Yazi package bodies and runtime data must not be managed by chezmoi.\n' >&2
  exit 1
fi

bash -n "$ROOT_DIR/home/modify_dot_bashrc"
bash -n "$ROOT_DIR/home/modify_dot_gitconfig"
bash -n "$ROOT_DIR/home/dot_config/workstation/shell/init.bash"
bash -n "$ROOT_DIR/tests/wsl-restart-smoke.sh"

workaround_tasks="$ROOT_DIR/ansible/roles/base/tasks/main.yml"
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

grep -q 'mise.*activate bash' "$ROOT_DIR/home/dot_config/workstation/shell/init.bash"
grep -q 'init-posix.sh' "$ROOT_DIR/home/dot_config/workstation/shell/init.bash"
grep -q '^safe_chain_version:' "$ROOT_DIR/ansible/vars/main.yml"
grep -q '^safe_chain_installer_url:' "$ROOT_DIR/ansible/vars/main.yml"
grep -q '^safe_chain_installer_checksum:' "$ROOT_DIR/ansible/vars/main.yml"
# Regression check: AikidoSec/safe-chain release tags do not use a "v" prefix.
if grep -q 'v{{ safe_chain_version }}' "$ROOT_DIR/ansible/vars/main.yml"; then
  printf 'safe_chain_installer_url must not use a v-prefixed release tag.\n' >&2
  exit 1
fi
safe_chain_version="$(awk -F'"' '/^safe_chain_version:/{print $2}' "$ROOT_DIR/ansible/vars/main.yml")"
safe_chain_url="https://github.com/AikidoSec/safe-chain/releases/download/${safe_chain_version}/install-safe-chain.sh"
if ! curl -sI --fail --max-time 10 "$safe_chain_url" >/dev/null; then
  printf 'Safe-chain installer URL is not reachable: %s\n' "$safe_chain_url" >&2
  exit 1
fi
grep -q 'SAFE_CHAIN_MINIMUM_PACKAGE_AGE_EXCLUSIONS="@openai/codex"' "$ROOT_DIR/scripts/update-ai"
grep -q 'npm install --global @openai/codex@latest' "$ROOT_DIR/scripts/update-ai"
grep -q 'https://claude.ai/install.sh' "$ROOT_DIR/scripts/update-ai"
grep -q 'https://opencode.ai/install' "$ROOT_DIR/scripts/update-ai"
grep -q -- '--no-modify-path' "$ROOT_DIR/scripts/update-ai"
grep -q 'scripts/update-ai' "$ROOT_DIR/ansible/roles/personal/tasks/main.yml"
grep -Fq 'exec "$mise_bin" exec node -- "$0" "$@"' "$ROOT_DIR/scripts/update-ai"
grep -Fq 'MISE_LOCKED: "1"' "$ROOT_DIR/ansible/roles/personal/tasks/main.yml"
grep -Fq 'Trust mise global configuration' "$ROOT_DIR/ansible/roles/base/tasks/main.yml"
grep -Fq 'Install locked mise tools before personal role tasks' "$ROOT_DIR/ansible/roles/base/tasks/main.yml"
"$ROOT_DIR/tests/bootstrap-ai-mise-order.sh"
grep -q 'DISABLE_AUTOUPDATER=1' "$ROOT_DIR/home/dot_config/workstation/shell/init.bash"
grep -q '"autoupdate": false' "$ROOT_DIR/home/dot_config/opencode/opencode.json"
grep -q 'type -a herdr cagent codex claude opencode' "$ROOT_DIR/tests/wsl-restart-smoke.sh"
grep -q 'command -v herdr; command -v cagent; command -v codex; command -v claude; command -v opencode' "$ROOT_DIR/tests/wsl-restart-smoke.sh"
grep -q 'codex features list' "$ROOT_DIR/tests/wsl-restart-smoke.sh"
test -f "$ROOT_DIR/home/dot_config/herdr/config.toml"
test -f "$ROOT_DIR/home/dot_codex/config.toml"
test -f "$ROOT_DIR/home/dot_config/cagent/config.yaml"
grep -Fq 'default_agent: codex' "$ROOT_DIR/home/dot_config/cagent/config.yaml"
grep -Fq 'default_level: mid' "$ROOT_DIR/home/dot_config/cagent/config.yaml"
grep -A 1 -F 'models: [gpt-5.6-luna]' "$ROOT_DIR/home/dot_config/cagent/config.yaml" | grep -Fxq '        effort: xhigh'
grep -A 1 -F 'models: [gpt-5.6-terra]' "$ROOT_DIR/home/dot_config/cagent/config.yaml" | grep -Fxq '        effort: high'
grep -A 1 -F 'models: [gpt-5.6-sol]' "$ROOT_DIR/home/dot_config/cagent/config.yaml" | grep -Fxq '        effort: xhigh'
grep -Fq '  opencode-go:' "$ROOT_DIR/home/dot_config/cagent/config.yaml"
grep -Fq '    start_command_template: "cagent {level}"' "$ROOT_DIR/home/dot_config/cagent/config.yaml"
grep -Fq '    run_command_template: "cagent run {level} -- {prompt}"' "$ROOT_DIR/home/dot_config/cagent/config.yaml"
if grep -Eq '^version:[[:space:]]*2$' "$ROOT_DIR/home/dot_config/cagent/config.yaml"; then
  printf 'cagent config must not declare version: 2.\n' >&2
  exit 1
fi
if find "$ROOT_DIR/home" -type f \( \
  -name 'herdr-agent-state.*' -o \
  -name 'hooks.json' -o \
  -name 'auth.json' -o \
  -name 'history.jsonl' -o \
  -name '*.db' -o \
  -name 'session.json' -o \
  -name '*.log' \
\) | grep -q .; then
  printf 'Herdr-generated runtime data must not be managed by chezmoi.\n' >&2
  exit 1
fi

grep -q '^  - git$' "$ROOT_DIR/ansible/vars/main.yml"
grep -q '^  - gh$' "$ROOT_DIR/ansible/vars/main.yml"
grep -q '^  - jq$' "$ROOT_DIR/ansible/vars/main.yml"

agent_skills_tasks="$ROOT_DIR/ansible/roles/personal/tasks/agent_skills.yml"
grep -Fq 'agent_skills_repo_url: "https://github.com/u7chan/agent-skills.git"' \
  "$ROOT_DIR/ansible/vars/main.yml"
grep -Fq "agent_skills_dest: \"{{ ansible_facts['user_dir'] }}/workspace/agent-skills\"" \
  "$ROOT_DIR/ansible/vars/main.yml"
grep -Fq 'repo: "{{ agent_skills_repo_url }}"' "$agent_skills_tasks"
grep -Fq 'src: "{{ agent_skills_dest }}"' "$agent_skills_tasks"
grep -Fq 'dest: "{{ ansible_facts['"'"'user_dir'"'"'] }}/.{{ item }}/skills"' "$agent_skills_tasks"
grep -Fq 'force: false' "$agent_skills_tasks"

docker_tasks="$ROOT_DIR/ansible/roles/docker_ce/tasks/main.yml"
grep -Fq 'download.docker.com/linux/ubuntu' "$ROOT_DIR/ansible/vars/main.yml"
for docker_package in docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin; do
  grep -Fq -- "- $docker_package" "$ROOT_DIR/ansible/vars/main.yml"
done
grep -Fq 'containerd.service' "$docker_tasks"
grep -Fq 'docker.service' "$docker_tasks"
grep -Fq 'groups:' "$docker_tasks"
grep -Fq 'personal_docker_ce_enabled | bool' "$ROOT_DIR/ansible/playbook.yml"
grep -Fq 'docker context show' "$ROOT_DIR/tests/docker-smoke.sh"
grep -Fq 'docker buildx version' "$ROOT_DIR/tests/docker-smoke.sh"
grep -Fq 'docker compose' "$ROOT_DIR/tests/docker-smoke.sh"
grep -Fq 'env \' "$ROOT_DIR/bootstrap"
grep -Fq 'ANSIBLE_BECOME_EXE="$SUDO_EXE"' "$ROOT_DIR/bootstrap"
grep -Fq 'ANSIBLE_BECOME_ASK_PASS="$ASK_PASS"' "$ROOT_DIR/bootstrap"
grep -q '^"${SUDO_EXE:-sudo}" -v$' "$ROOT_DIR/bootstrap"
grep -q '\[\[ -n \$SUDO_EXE \]\]' "$ROOT_DIR/bootstrap"

ansible_env_output="$(
  env \
    ANSIBLE_CONFIG="$ROOT_DIR/ansible/ansible.cfg" \
    ANSIBLE_BECOME_EXE=/usr/bin/sudo.ws \
    ANSIBLE_BECOME_ASK_PASS=True \
    bash -c 'printf "%s\n%s\n%s\n" "$ANSIBLE_CONFIG" "$ANSIBLE_BECOME_EXE" "$ANSIBLE_BECOME_ASK_PASS"'
)"
[[ $ansible_env_output == "$ROOT_DIR/ansible/ansible.cfg"$'\n'/usr/bin/sudo.ws$'\n'True ]]

test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT

windows_terminal_doc="$ROOT_DIR/docs/windows-terminal.md"
test -f "$windows_terminal_doc"
grep -Fq 'Windows Terminal設定' "$ROOT_DIR/README.md"
grep -Fq 'wsl.exe --distribution {WSLディストリビューション名}' "$windows_terminal_doc"
grep -Fq '"defaultProfile": "{11111111-1111-1111-1111-111111111111}"' "$windows_terminal_doc"
grep -Fq '"commandline": "powershell.exe"' "$windows_terminal_doc"
grep -Fq '"Windows.Terminal.Wsl"' "$windows_terminal_doc"
windows_terminal_json_dir="$test_dir/windows-terminal-json"
mkdir -p "$windows_terminal_json_dir"
awk -v output_dir="$windows_terminal_json_dir" '
  /^```json[[:space:]]*$/ {
    if (in_block) {
      printf "Nested JSON code block in %s.\n", FILENAME > "/dev/stderr"
      failed = 1
      next
    }
    in_block = 1
    output_path = sprintf("%s/block-%d.json", output_dir, ++block_count)
    next
  }
  /^```[[:space:]]*$/ {
    if (in_block) {
      in_block = 0
    }
    next
  }
  in_block {
    print > output_path
  }
  END {
    if (in_block) {
      printf "Unterminated JSON code block in %s.\n", FILENAME > "/dev/stderr"
      failed = 1
    }
    if (block_count != 1) {
      printf "Expected exactly 1 JSON code block in %s, found %d.\n", FILENAME, block_count > "/dev/stderr"
      failed = 1
    }
    exit failed
  }
' "$windows_terminal_doc"
for windows_terminal_json in "$windows_terminal_json_dir"/*.json; do
  jq empty "$windows_terminal_json"
done

gitconfig_input="$test_dir/gitconfig.input"
gitconfig_first="$test_dir/gitconfig.first"
gitconfig_second="$test_dir/gitconfig.second"
cat >"$gitconfig_input" <<'EOF'
[credential "https://github.com"]
	helper = !/usr/bin/gh auth git-credential
EOF
"$ROOT_DIR/home/modify_dot_gitconfig" <"$gitconfig_input" >"$gitconfig_first"
"$ROOT_DIR/home/modify_dot_gitconfig" <"$gitconfig_first" >"$gitconfig_second"
cmp "$gitconfig_first" "$gitconfig_second"
[[ $(git config --file "$gitconfig_second" init.defaultBranch) == main ]]
[[ $(git config --file "$gitconfig_second" core.excludesFile) == '~/.config/git/ignore' ]]
[[ $(git config --file "$gitconfig_second" --get-all 'url.https://github.com/.insteadOf' | wc -l) -eq 2 ]]
[[ $(GIT_CONFIG_GLOBAL="$gitconfig_second" GIT_CONFIG_NOSYSTEM=1 git ls-remote --get-url git@github.com:u7chan/workstation-config.git) == https://github.com/u7chan/workstation-config.git ]]
[[ $(GIT_CONFIG_GLOBAL="$gitconfig_second" GIT_CONFIG_NOSYSTEM=1 git ls-remote --get-url ssh://git@github.com/u7chan/workstation-config.git) == https://github.com/u7chan/workstation-config.git ]]
git config --file "$gitconfig_second" --get-all credential.https://github.com.helper |
  grep -Fqx '!/usr/bin/gh auth git-credential'
! grep -Eiq 'token|private.?key|sshcommand' "$gitconfig_second"

[[ $(git config --file "$gitconfig_second" alias.s) == status ]]
[[ $(git config --file "$gitconfig_second" alias.ss) == 'status -s' ]]
[[ $(git config --file "$gitconfig_second" alias.b) == branch ]]
[[ $(git config --file "$gitconfig_second" alias.sw) == switch ]]
[[ $(git config --file "$gitconfig_second" alias.swc) == 'switch -c' ]]
[[ $(git config --file "$gitconfig_second" alias.swm) == 'switch main' ]]
[[ $(git config --file "$gitconfig_second" alias.f) == 'fetch --verbose' ]]
[[ $(git config --file "$gitconfig_second" alias.fa) == 'fetch --all --verbose' ]]
[[ $(git config --file "$gitconfig_second" alias.fp) == 'fetch --prune --verbose' ]]
[[ $(git config --file "$gitconfig_second" alias.fap) == 'fetch --all --prune --verbose' ]]
[[ $(git config --file "$gitconfig_second" alias.pl) == 'pull --verbose' ]]
[[ $(git config --file "$gitconfig_second" alias.plr) == 'pull --rebase --verbose' ]]
[[ $(git config --file "$gitconfig_second" alias.plm) == '!git fetch origin main --verbose' ]]
[[ $(git config --file "$gitconfig_second" alias.p) == 'push --verbose' ]]
[[ $(git config --file "$gitconfig_second" alias.puo) == 'push -u origin HEAD' ]]
[[ $(git config --file "$gitconfig_second" alias.cm) == commit ]]
[[ $(git config --file "$gitconfig_second" alias.cma) == 'commit --amend --no-edit' ]]
[[ $(git config --file "$gitconfig_second" alias.lg) == 'log --oneline --graph --decorate' ]]
[[ $(git config --file "$gitconfig_second" alias.last) == 'log -1 HEAD' ]]
[[ $(git config --file "$gitconfig_second" alias.unstage) == 'restore --staged .' ]]
[[ $(git config --file "$gitconfig_second" alias.discard) == 'restore .' ]]

expected_aliases=(
  alias.s alias.ss alias.b alias.sw alias.swc alias.swm
  alias.f alias.fa alias.fp alias.fap
  alias.pl alias.plr alias.plm
  alias.p alias.puo
  alias.cm alias.cma
  alias.lg alias.last
  alias.unstage alias.discard
)
mapfile -t actual_aliases < <(git config --file "$gitconfig_second" --get-regexp '^alias\.' 2>/dev/null | awk '{print $1}')
for key in "${actual_aliases[@]}"; do
  if ! printf '%s\n' "${expected_aliases[@]}" | grep -Fqx "$key"; then
    printf 'Unexpected alias %s found; only allowlisted aliases may be managed.\n' "$key" >&2
    exit 1
  fi
done

if git config --file "$gitconfig_second" --get-all safe.directory 2>/dev/null | grep -Fqx '*'; then
  printf 'safe.directory=* must not be set by chezmoi.\n' >&2
  exit 1
fi

test_bashrc="$test_dir/bashrc"
test_home="$test_dir/home"
test_bin="$test_dir/bin"
mkdir -p "$test_home/.config/workstation/shell" "$test_bin"
printf '#!/usr/bin/env bash\nprintf "C:\\\\mock"\n' >"$test_bin/wslpath"
chmod +x "$test_bin/wslpath"
printf 'alias g=echo\n' >"$test_home/.config/workstation/shell/local.bash"
printf '# Ubuntu default\n' >"$test_bashrc"
"$ROOT_DIR/home/modify_dot_bashrc" <"$test_bashrc" >"${test_bashrc}.first"
"$ROOT_DIR/home/modify_dot_bashrc" <"${test_bashrc}.first" >"${test_bashrc}.second"
cmp "${test_bashrc}.first" "${test_bashrc}.second"
[[ $(grep -c '^# BEGIN workstation-config$' "${test_bashrc}.second") -eq 1 ]]
[[ $(grep -c 'source "$HOME/.config/workstation/shell/init.bash"' "${test_bashrc}.second") -eq 1 ]]

noninteractive_output="$(bash -c 'source "$1"' _ "$ROOT_DIR/home/dot_config/workstation/shell/init.bash" 2>&1)"
[[ -z $noninteractive_output ]]

interactive_output="$({
  HOME="$test_home" \
  PATH="$test_bin:$PATH" \
  WT_SESSION=test \
  WSL_DISTRO_NAME=test \
    bash --noprofile --norc -ic '
      set -e
      PROMPT_COMMAND="existing_hook"
      source "$1"
      source "$1"
      prompt_state="${PROMPT_COMMAND};${STARSHIP_PROMPT_COMMAND:-}"
      [[ $prompt_state == *existing_hook* ]]
      [[ $(grep -o "__workstation_report_cwd" <<<"$prompt_state" | wc -l) -eq 1 ]]
      [[ $(grep -o "starship_precmd" <<<"$PROMPT_COMMAND" | wc -l) -le 1 ]]
      alias g | grep -q "alias g=.*echo"
      alias h | grep -q "alias h=.*herdr"
    ' _ "$ROOT_DIR/home/dot_config/workstation/shell/init.bash"
} 2>&1)" || {
  printf '%s\n' "$interactive_output" >&2
  exit 1
}

if "$ROOT_DIR/bootstrap" invalid >/dev/null 2>&1; then
  printf 'Invalid profile was accepted.\n' >&2
  exit 1
fi

if command -v shellcheck >/dev/null 2>&1; then
  shellcheck \
    "$ROOT_DIR/bootstrap" \
    "$ROOT_DIR/home/modify_dot_bashrc" \
    "$ROOT_DIR/home/modify_dot_gitconfig" \
    "$ROOT_DIR/home/dot_config/workstation/shell/init.bash" \
    "$ROOT_DIR/scripts/update-ai" \
    "$ROOT_DIR/tests/ai-clis-smoke.sh" \
    "$ROOT_DIR/tests/wsl-restart-smoke.sh" \
    "$ROOT_DIR/tests/safe-chain-smoke.sh" \
    "$ROOT_DIR/tests/personal-cli-smoke.sh" \
    "$ROOT_DIR/tests/docker-smoke.sh" \
    "$ROOT_DIR/tests/agent-skills-smoke.sh" \
    "$ROOT_DIR/tests/cagent-smoke.sh" \
    "$ROOT_DIR/scripts/personal-bin/clp" \
    "$ROOT_DIR/scripts/personal-bin/gac" \
    "$ROOT_DIR/scripts/personal-bin/gpc" \
    "$ROOT_DIR/scripts/personal-bin/http" \
    "$ROOT_DIR/scripts/personal-bin/http-lan" \
    "$ROOT_DIR/tests/static.sh"
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
