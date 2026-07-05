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
grep -q '^neovim = "0.12"' "$ROOT_DIR/mise/config.toml"
if grep -R -Eiq 'apt(-get)?.*(install.*)?neovim|^[[:space:]]*-[[:space:]]*neovim$' \
  "$ROOT_DIR/ansible" "$ROOT_DIR/bootstrap"; then
  printf 'Neovim must not be managed by APT.\n' >&2
  exit 1
fi

test -f "$ROOT_DIR/home/dot_config/nvim/init.lua"
test -f "$ROOT_DIR/home/dot_config/nvim/lazy-lock.json"
bash -n "$ROOT_DIR/tests/neovim-smoke.sh"

bash -n "$ROOT_DIR/home/modify_dot_bashrc"
bash -n "$ROOT_DIR/home/modify_dot_gitconfig"
bash -n "$ROOT_DIR/home/dot_config/workstation/shell/init.bash"

grep -q '^  - git$' "$ROOT_DIR/ansible/vars/main.yml"
grep -q '^  - gh$' "$ROOT_DIR/ansible/vars/main.yml"

test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT

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
[[ $(git config --file "$gitconfig_second" user.name) == u7chan ]]
[[ $(git config --file "$gitconfig_second" user.email) == 34462401+u7chan@users.noreply.github.com ]]
[[ $(git config --file "$gitconfig_second" init.defaultBranch) == main ]]
[[ $(git config --file "$gitconfig_second" core.excludesFile) == '~/.config/git/ignore' ]]
[[ $(git config --file "$gitconfig_second" --get-all 'url.https://github.com/.insteadOf' | wc -l) -eq 2 ]]
[[ $(GIT_CONFIG_GLOBAL="$gitconfig_second" GIT_CONFIG_NOSYSTEM=1 git ls-remote --get-url git@github.com:u7chan/workstation-config.git) == https://github.com/u7chan/workstation-config.git ]]
[[ $(GIT_CONFIG_GLOBAL="$gitconfig_second" GIT_CONFIG_NOSYSTEM=1 git ls-remote --get-url ssh://git@github.com/u7chan/workstation-config.git) == https://github.com/u7chan/workstation-config.git ]]
git config --file "$gitconfig_second" --get-all credential.https://github.com.helper |
  grep -Fqx '!/usr/bin/gh auth git-credential'
! grep -Eiq 'token|private.?key|sshcommand' "$gitconfig_second"

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
