#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="${ROOT_DIR:?ROOT_DIR must be exported by tests/static.sh}"

case "${1:-}" in
  config)
    mise_config="$ROOT_DIR/provisioning/mise/config.toml"
    mise_lock="$ROOT_DIR/provisioning/mise/mise.lock"
    grep -q '^node = "lts"' "$mise_config"
    grep -q '^herdr = "latest"' "$mise_config"
    grep -q '^ripgrep = "latest"' "$mise_config"
    command -v rg >/dev/null
    rg --version >/dev/null
    grep -Fq 'cagent = "github:u7chan/code-agent-launcher"' "$mise_config"
    grep -Fq 'cagent = { version = "1.1.0", filter_bins = "cagent" }' "$mise_config"
    grep -Fq '"npm:@playwright/cli" = "latest"' "$mise_config"
    grep -Fq 'backend = "npm:@playwright/cli"' "$mise_lock"
    test -s "$mise_lock"
    grep -q '^neovim = "0.12"' "$mise_config"
    grep -q '^hunk = "latest"' "$mise_config"
    grep -q '^lazygit = "latest"' "$mise_config"
    grep -q '^lazydocker = "latest"' "$mise_config"
    grep -Fq 'backend = "aqua:modem-dev/hunk"' "$mise_lock"
    grep -Fq 'backend = "aqua:jesseduffield/lazygit"' "$mise_lock"
    grep -Fq 'backend = "aqua:jesseduffield/lazydocker"' "$mise_lock"
    grep -q '^yazi = "latest"' "$mise_config"
    test ! -e "$ROOT_DIR/mise/config.toml"
    test ! -e "$ROOT_DIR/mise/mise.lock"
    ;;
  ansible-base)
    grep -Fq 'src: "{{ playbook_dir }}/../provisioning/mise/config.toml"' \
      "$ROOT_DIR/ansible/roles/base/tasks/toolchain.yml"
    grep -Fq 'src: "{{ playbook_dir }}/../provisioning/mise/mise.lock"' \
      "$ROOT_DIR/ansible/roles/base/tasks/toolchain.yml"
    if grep -R -Eiq 'apt(-get)?.*(install.*)?neovim|^[[:space:]]*-[[:space:]]*neovim$' \
      "$ROOT_DIR/ansible" "$ROOT_DIR/bootstrap"; then
      printf 'Neovim must not be managed by APT.\n' >&2
      exit 1
    fi
    test -f "$ROOT_DIR/home/dot_config/nvim/init.lua"
    test -f "$ROOT_DIR/home/dot_config/nvim/lazy-lock.json"
    ;;
  yazi)
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
    ;;
  base-role-order)
    grep -Fq 'Trust mise global configuration' "$ROOT_DIR/ansible/roles/base/tasks/toolchain.yml"
    grep -Fq 'Install locked mise tools before personal role tasks' \
      "$ROOT_DIR/ansible/roles/base/tasks/mise_tools.yml"
    grep -Fq '{{ ansible_facts['\''user_dir'\''] }}/.local/share/mise/shims' \
      "$ROOT_DIR/ansible/roles/base/vars/main.yml"
    ;;
  gh)
    grep -q '^gh = "latest"' "$ROOT_DIR/provisioning/mise/config.toml"
    ;;
  *)
    printf 'Usage: %s <stage: config|ansible-base|yazi|base-role-order|gh>\n' "$0" >&2
    exit 2
    ;;
esac
