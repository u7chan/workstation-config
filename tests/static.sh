#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
export ROOT_DIR

# Static checks are split into per-area files under tests/static/. Each area
# file exposes named stages, and this runner schedules every stage in the
# exact statement order of the original single-file script, so fail-fast
# still surfaces the same first failure as before. Comments reference the
# original tests/static.sh line ranges (6b80f01).
run() {
  local file="$1" stage="$2"
  printf '[static] %s %s\n' "$file" "$stage"
  "$ROOT_DIR/tests/static/$file" "$stage"
}

run bootstrap.sh syntax                  # 旧L7-8: bash -n bootstrap / --help
run docs.sh links                        # 旧L10-20: README/docsリンク
run bootstrap.sh vars                    # 旧L22-24: MISE_LOCKED等
run claude.sh settings                   # 旧L25-29: Claude設定
run mise.sh config                       # 旧L30-49: mise config/lock + rg
run pi.sh keybindings                    # 旧L50-57: keybindings/chezmoiignore
run bootstrap.sh ci-workflow             # 旧L58: CIのpinned chezmoi
run mise.sh ansible-base                 # 旧L59-69: base role mise srcs + nvim
run smoke.sh syntax-tools                # 旧L70-72: bash -n neovim/yazi/safe-chain
run update-ai.sh syntax                  # 旧L73: bash -n scripts/update-ai
run smoke.sh syntax-ai                   # 旧L74-78: bash -n AI/Pi/bootstrap系smoke
run claude.sh syntax                     # 旧L79: bash -n merge-claude-settings
run smoke.sh syntax-more                 # 旧L80-86: bash -n その他smoke
run personal.sh syntax                   # 旧L87: bash -n myupdate
run smoke.sh syntax-update               # 旧L88: bash -n workstation-update-smoke
run personal.sh role                     # 旧L89-97: personal-bin + personal role
run mise.sh yazi                         # 旧L99-107: yazi設定 + runtime guard
run shell-init.sh syntax-bashrc          # 旧L109: bash -n modify_dot_bashrc
run gitconfig.sh syntax                  # 旧L110: bash -n modify_dot_gitconfig
run shell-init.sh syntax-init            # 旧L111: bash -n init.bash
run herdr.sh syntax-status               # 旧L112-113: bash -n status-* (+resources)
run herdr.sh syntax-wsl-restart          # 旧L114: bash -n wsl-restart-smoke
run ansible.sh wsl-workaround            # 旧L116-126: WSL systemd workaround
run shell-init.sh mise-activate          # 旧L128-129: init.bash mise activate
run update-ai.sh safe-chain-and-greps    # 旧L131-165: safe-chain + update-ai
run pi.sh base-role-guard                # 旧L166-171: Pi package base role guard
run mise.sh base-role-order              # 旧L172-174: base role mise順序
run smoke.sh run                         # 旧L175-181: smokeスクリプト実行
run shell-init.sh autoupdate             # 旧L182-183: autoupdate設定
run docs.sh pi-packages                  # 旧L184-221: Pi Packagesドキュメント
run herdr.sh wsl-restart-greps           # 旧L222-227: wsl-restart-smoke内容
run herdr.sh config                      # 旧L228-242: herdr config.toml
run codex.sh config                      # 旧L243-245: codex config
run cagent.sh config                     # 旧L246-260: cagent config
run herdr.sh runtime-data                # 旧L261-270: Herdr runtime data guard
run pi.sh runtime-data                   # 旧L271-275: Pi runtime data guard
run ansible.sh vars                      # 旧L277-280: ansible vars
run mise.sh gh                           # 旧L281: gh = latest
run docker.sh docker                     # 旧L282-288: Docker
run bootstrap.sh sudo-env                # 旧L289-302: sudo/env透過
run windows-terminal.sh doc-json         # 旧L304-345: Windows Terminal
run gitconfig.sh suite                   # 旧L347-453: gitconfig冪等性
run shell-init.sh bashrc-suite           # 旧L455-490: bashrc/init.bash冪等性
run bootstrap.sh invalid-profile         # 旧L492-496: 不正profile拒否
run lint.sh lint                         # 旧L498-542: shellcheck/syntax/yamllint/ansible-lint

printf 'Static checks passed.\n'
