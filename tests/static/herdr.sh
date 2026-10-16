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
    grep -q 'type -a herdr cagent' "$ROOT_DIR/tests/wsl-restart-smoke.sh"
    grep -q 'command -v herdr; command -v cagent' "$ROOT_DIR/tests/wsl-restart-smoke.sh"
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
    grep -Fq "when: \"'pi' in personal_ai_tools\"" "$plugin_tasks"
    grep -Fq "when: \"'pi' not in personal_ai_tools\"" "$plugin_tasks"
    # issue #211: the personal role installs the plugin, so chezmoi must not own it.
    test ! -e "$ROOT_DIR/home/dot_config/herdr/local-plugins"
    ;;
  runtime-data)
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
    ;;
  *)
    printf 'Usage: %s <stage: syntax-status|syntax-wsl-restart|wsl-restart-greps|config|plugins|runtime-data>\n' "$0" >&2
    exit 2
    ;;
esac
