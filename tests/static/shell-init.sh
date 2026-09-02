#!/usr/bin/env bash
# shellcheck disable=SC2016
set -euo pipefail
ROOT_DIR="${ROOT_DIR:?ROOT_DIR must be exported by tests/static.sh}"

case "${1:-}" in
  syntax-bashrc)
    bash -n "$ROOT_DIR/home/modify_dot_bashrc"
    ;;
  syntax-init)
    bash -n "$ROOT_DIR/home/dot_config/workstation/shell/init.bash"
    ;;
  mise-activate)
    grep -q 'mise.*activate bash' "$ROOT_DIR/home/dot_config/workstation/shell/init.bash"
    grep -q 'activate bash --shims' "$ROOT_DIR/home/dot_config/workstation/shell/init.bash"
    grep -q 'init-posix.sh' "$ROOT_DIR/home/dot_config/workstation/shell/init.bash"
    ;;
  autoupdate)
    grep -q 'DISABLE_AUTOUPDATER=1' "$ROOT_DIR/home/dot_config/workstation/shell/init.bash"
    grep -q '"autoupdate": false' "$ROOT_DIR/home/dot_config/opencode/opencode.json"
    ;;
  bashrc-suite)
    test_dir="$(mktemp -d)"
    trap 'rm -rf "$test_dir"' EXIT

    test_bashrc="$test_dir/bashrc"
    test_home="$test_dir/home"
    test_bin="$test_dir/bin"
    mkdir -p "$test_home/.config/workstation/shell" "$test_bin"
    printf '#!/usr/bin/env bash\nprintf "C:\\\\mock"\n' >"$test_bin/wslpath"
    chmod +x "$test_bin/wslpath"
    printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$1"\nexit 1\n' >"$test_bin/explorer.exe"
    chmod +x "$test_bin/explorer.exe"
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
          alias open | grep -q "alias open=.*__workstation_open"
          [[ $(open .) == C:\\mock ]]
          open . >/dev/null
        ' _ "$ROOT_DIR/home/dot_config/workstation/shell/init.bash"
    } 2>&1)" || {
      printf '%s\n' "$interactive_output" >&2
      exit 1
    }
    ;;
  *)
    printf 'Usage: %s <stage: syntax-bashrc|syntax-init|mise-activate|autoupdate|bashrc-suite>\n' "$0" >&2
    exit 2
    ;;
esac
