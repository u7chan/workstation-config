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
    # 常看板（u7chan.status-board）の廃止でキー2件とタブバー行を外した（issue #221）
    if grep -Eq '^key[[:space:]]*=[[:space:]]*"prefix\+(m|shift\+m|[hr])"' "$herdr_config" \
      || grep -Fq 'status-board' "$herdr_config"; then
      printf 'Removed Herdr keybindings and the retired status board must not be managed.\n' >&2
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
    grep -Fqx '  - id: u7chan.file-viewer' "$local_plugin_defaults"
    grep -Fqx '    binary: bin/herdr-file-viewer' "$local_plugin_defaults"
    grep -Fq '/workspace/herdr-file-viewer' "$local_plugin_defaults"
    # 常看板（u7chan.status-board）は廃止したため、link/enableの宣言に残さない。
    if grep -Fq 'status-board' "$local_plugin_defaults"; then
      printf 'The retired status board plugin must not be declared.\n' >&2
      exit 1
    fi
    grep -Fq 'ansible.builtin.stat:' "$local_plugin_task"
    grep -Fq 'when: not herdr_local_plugin_binary.stat.exists' "$local_plugin_task"
    grep -Fqx '      - --enabled' "$local_plugin_task"
    grep -Fq 'ansible.builtin.assert:' "$local_plugin_task"
    # 秘密情報（トークン・webhook）はリポジトリに置かない。Herdr所有のplugin config / stateも管理しない。
    grep -Fqx '.config/herdr/.secrets' "$ROOT_DIR/home/.chezmoiignore"
    test ! -e "$ROOT_DIR/home/dot_config/herdr/plugins"
    # 廃止した常看板の説明をchezmoi sourceへ残さない。
    if grep -r -F -q '看板' "$ROOT_DIR/home/"; then
      printf 'The retired status board description must not remain in the chezmoi source.\n' >&2
      exit 1
    fi
    grep -Fq 'personal_herdr_local_plugins' "$ROOT_DIR/docs/workstation.md"
    grep -Fq 'prefix+f' "$ROOT_DIR/docs/workstation.md"
    grep -Fq 'herdr plugin unlink' "$ROOT_DIR/docs/workstation.md"
    # 常看板の廃止を1行で説明し、clone/build手順（repo slug）は残さない。既存linkの整理も書く。
    grep -Fq '常看板' "$ROOT_DIR/docs/workstation.md"
    grep -Fq 'Webコンソールへ一本化' "$ROOT_DIR/docs/workstation.md"
    if grep -Fq 'github.com/u7chan/herdr-status-board' "$ROOT_DIR/docs/workstation.md"; then
      printf 'The retired status board clone instructions must not come back.\n' >&2
      exit 1
    fi
    grep -Fq 'herdr plugin unlink u7chan.status-board' "$ROOT_DIR/docs/workstation.md"
    grep -Fq 'rm -rf ~/.config/herdr/local-plugins/herdr-status-board' "$ROOT_DIR/docs/workstation.md"
    # fresh workstation向けの手順順序: 最初のbootstrapがmise/makeを導入するため、clone/buildはその後で行い、
    # linkはもう一度bootstrapを実行して行う（roleの警告メッセージと同じ順序）。
    first_bootstrap_line="$(grep -n -F -m1 '# 1. 最初のbootstrap' "$ROOT_DIR/docs/workstation.md" | cut -d: -f1)"
    plugin_url='https://github.com/u7chan/herdr-file-viewer'
    plugin_clone_line="$(grep -n -F -m1 "git clone $plugin_url" "$ROOT_DIR/docs/workstation.md" | cut -d: -f1)"
    relink_line="$(grep -n -F -m1 '# 3. もう一度bootstrap' "$ROOT_DIR/docs/workstation.md" | cut -d: -f1)"
    [[ -n $first_bootstrap_line && -n $plugin_clone_line && -n $relink_line && \
      $first_bootstrap_line -lt $plugin_clone_line && $plugin_clone_line -lt $relink_line ]] || {
      printf 'The fresh-install steps must clone and build the plugin after the first bootstrap.\n' >&2
      exit 1
    }
    grep -Fq 'mise exec go@' "$ROOT_DIR/docs/workstation.md"
    grep -Fq 'No version is set for shim: go' "$ROOT_DIR/docs/workstation.md"
    # secretsとplugin本体は配布対象外であることをsourceの説明にも書く（clone/buildの詳細はdocsを正とする）。
    grep -Fq '.config/herdr/.secrets' "$ROOT_DIR/home/README.md"
    grep -Fq '../docs/workstation.md' "$ROOT_DIR/home/README.md"
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
