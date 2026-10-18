#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="${ROOT_DIR:?ROOT_DIR must be exported by tests/static.sh}"

case "${1:-}" in
  syntax-status)
    bash -n "$ROOT_DIR/home/dot_config/herdr/scripts/executable_status-agents.sh"
    bash -n "$ROOT_DIR/home/dot_config/herdr/scripts/executable_status-datetime.sh"
    bash -n "$ROOT_DIR/home/dot_config/herdr/scripts/executable_status-resources.sh"
    ;;
  syntax-wsl-restart)
    bash -n "$ROOT_DIR/tests/wsl-restart-smoke.sh"
    ;;
  wsl-restart-greps)
    grep -q 'type -a herdr' "$ROOT_DIR/tests/wsl-restart-smoke.sh"
    grep -q 'command -v herdr' "$ROOT_DIR/tests/wsl-restart-smoke.sh"
    grep -q 'command -v gh' "$ROOT_DIR/tests/wsl-restart-smoke.sh"
    grep -q 'expected_tools' "$ROOT_DIR/tests/wsl-restart-smoke.sh"
    grep -q 'herdr integration status' "$ROOT_DIR/tests/wsl-restart-smoke.sh"
    ;;
  config)
    herdr_config="$ROOT_DIR/home/dot_config/herdr/config.toml"
    test -f "$herdr_config"
    grep -Fqx 'command = "u7chan.file-viewer.open-file-viewer"' "$herdr_config"
    grep -Fq 'key     = "prefix+y"' "$herdr_config"
    grep -Fq 'command = "yazi"' "$herdr_config"
    grep -Fq 'key     = "prefix+d"' "$herdr_config"
    grep -Fq 'command = "lazydocker"' "$herdr_config"
    grep -Fq 'key     = "prefix+g"' "$herdr_config"
    grep -Fq 'command = "lazygit"' "$herdr_config"
    grep -Fqx 'new_worktree   = "prefix+p"' "$herdr_config"
    grep -Fqx 'previous_tab   = ""' "$herdr_config"
    grep -Fq 'herdr-status-board/bin/herdr-status-board summary' "$herdr_config"
    # issue #221: 看板ボード（u7chan.status-board）のキーバインド2件
    grep -Fqx 'key     = "prefix+m"' "$herdr_config"
    grep -Fqx 'command = "u7chan.status-board.open-board"' "$herdr_config"
    grep -Fqx 'key     = "prefix+shift+m"' "$herdr_config"
    grep -Fqx 'command = "u7chan.status-board.glance-board"' "$herdr_config"
    if grep -Eq '^key[[:space:]]*=[[:space:]]*"prefix\+[hr]"' "$herdr_config"; then
      printf 'Removed Herdr keybindings must not be managed.\n' >&2
      exit 1
    fi
    test ! -e "$ROOT_DIR/home/dot_config/herdr/plugins/config/herdr-file-viewer/config.toml"
    ;;
  plugins)
    plugin_dir="$ROOT_DIR/ansible/roles/personal/files/herdr-plugins/worktree-pi"
    plugin_tasks="$ROOT_DIR/ansible/roles/personal/tasks/herdr_plugins.yml"
    test -f "$plugin_dir/herdr-plugin.toml"
    test -f "$plugin_dir/config.sh"
    test -x "$plugin_dir/hook.sh"
    grep -Fqx 'id = "u7chan.worktree-pi"' "$plugin_dir/herdr-plugin.toml"
    grep -Fqx 'on = "worktree.created"' "$plugin_dir/herdr-plugin.toml"
    grep -Fqx 'command = ["./hook.sh"]' "$plugin_dir/herdr-plugin.toml"
    grep -Fq 'HERDR_PLUGIN_EVENT_JSON' "$plugin_dir/hook.sh"
    grep -Fq 'HERDR_PANE_ID' "$plugin_dir/hook.sh"
    grep -Fq 'WORKTREE_PI_REPOS' "$plugin_dir/config.sh"
    grep -Fq 'WORKTREE_PI_AGENT_NAME_PREFIX' "$plugin_dir/config.sh"
    grep -Fq '.data.worktree.branch' "$plugin_dir/hook.sh"
    grep -Fq 'agent_name_taken' "$plugin_dir/hook.sh"
    test -f "$plugin_tasks"
    grep -Fq 'ansible.builtin.import_tasks: herdr_plugins.yml' "$ROOT_DIR/ansible/roles/personal/tasks/main.yml"
    grep -Fq 'herdr-plugins/worktree-pi/' "$plugin_tasks"
    grep -Fqx '      - plugin' "$plugin_tasks"
    grep -Fqx '      - link' "$plugin_tasks"
    grep -Fqx '      - unlink' "$plugin_tasks"
    grep -Fqx '      - u7chan.worktree-pi' "$plugin_tasks"
    grep -Fq 'server_not_running' "$plugin_tasks"
    grep -Fq "when: \"'pi' in personal_ai_tools\"" "$plugin_tasks"
    grep -Fq "when: \"'pi' not in personal_ai_tools\"" "$plugin_tasks"
    # issue #211: the personal role installs the plugin, so chezmoi must not own it.
    test ! -e "$ROOT_DIR/home/dot_config/herdr/local-plugins"
    ;;
  local-plugins)
    # issue #221: ビルド済みの自作プラグインだけをpersonal roleがリンクする。clone / build は各プラグインの
    # リポジトリが所有し、workstation-configはプラグインのファイルもバイナリも管理しない。
    local_plugin_task="$ROOT_DIR/ansible/roles/personal/tasks/herdr_local_plugin.yml"
    local_plugin_tasks="$ROOT_DIR/ansible/roles/personal/tasks/herdr_plugins.yml"
    local_plugin_defaults="$ROOT_DIR/ansible/roles/personal/defaults/main.yml"
    test -f "$local_plugin_task"
    grep -Fq 'ansible.builtin.include_tasks: herdr_local_plugin.yml' "$local_plugin_tasks"
    grep -Fq 'loop: "{{ personal_herdr_local_plugins }}"' "$local_plugin_tasks"
    grep -Fq 'loop_var: herdr_local_plugin' "$local_plugin_tasks"
    grep -Fq 'personal_herdr_local_plugins:' "$local_plugin_defaults"
    grep -Fqx '  - id: u7chan.status-board' "$local_plugin_defaults"
    grep -Fqx '  - id: u7chan.file-viewer' "$local_plugin_defaults"
    grep -Fqx '    binary: bin/herdr-status-board' "$local_plugin_defaults"
    grep -Fqx '    binary: bin/herdr-file-viewer' "$local_plugin_defaults"
    grep -Fq '.config/herdr/local-plugins/herdr-status-board' "$local_plugin_defaults"
    grep -Fq '/workspace/herdr-file-viewer' "$local_plugin_defaults"
    grep -Fq 'ansible.builtin.stat:' "$local_plugin_task"
    grep -Fq 'when: not herdr_local_plugin_binary.stat.exists' "$local_plugin_task"
    grep -Fqx '      - --enabled' "$local_plugin_task"
    grep -Fq 'ansible.builtin.assert:' "$local_plugin_task"
    # 秘密情報（トークン・webhook）はリポジトリに置かない。Herdr所有のplugin config / stateも管理しない。
    grep -Fqx '.config/herdr/.secrets' "$ROOT_DIR/home/.chezmoiignore"
    test ! -e "$ROOT_DIR/home/dot_config/herdr/plugins"
    grep -Fq 'personal_herdr_local_plugins' "$ROOT_DIR/docs/workstation.md"
    grep -Fq 'prefix+m' "$ROOT_DIR/docs/workstation.md"
    grep -Fq 'herdr plugin unlink' "$ROOT_DIR/docs/workstation.md"
    # fresh workstation向けの手順: miseはGoをpinしていないため`go build`だけでは通らない。
    grep -Fq 'mise exec go@' "$ROOT_DIR/docs/workstation.md"
    grep -Fq 'No version is set for shim: go' "$ROOT_DIR/docs/workstation.md"
    # secretsとplugin本体は配布対象外であることをsourceの説明にも書く。
    grep -Fq '.config/herdr/.secrets' "$ROOT_DIR/home/README.md"
    ;;
  runtime-data)
    if find "$ROOT_DIR/home" -type f \( \
      -name 'herdr-agent-state.*' -o \
      -name 'hooks.json' -o \
      -name 'auth.json' -o \
      -name 'history.jsonl' -o \
      -name '*.db' -o \
      -name 'session.json' -o \
      -name '.secrets' -o \
      -name '*.secrets' -o \
      -name '*.log' \
    \) | grep -q .; then
      printf 'Herdr-generated runtime data and secrets must not be managed by chezmoi.\n' >&2
      exit 1
    fi
    ;;
  *)
    stages='syntax-status|syntax-wsl-restart|wsl-restart-greps|config|plugins|local-plugins|runtime-data'
    printf 'Usage: %s <stage: %s>\n' "$0" "$stages" >&2
    exit 2
    ;;
esac
