#!/usr/bin/env bash
# shellcheck disable=SC2016
set -euo pipefail
ROOT_DIR="${ROOT_DIR:?ROOT_DIR must be exported by tests/static.sh}"

case "${1:-}" in
  syntax-bashrc)
    bash -n "$ROOT_DIR/home/modify_dot_bashrc"
    ;;
  syntax-profile)
    bash -n "$ROOT_DIR/home/modify_dot_profile"
    # POSIX login shells read ~/.profile too; profile-suite also executes the
    # emitted block under sh.
    "$ROOT_DIR/home/modify_dot_profile" </dev/null | sh -n
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
    grep -q '"update": "disable"' "$ROOT_DIR/home/dot_config/opencode/opencode.json"
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
  profile-suite)
    test_dir="$(mktemp -d)"
    trap 'rm -rf "$test_dir"' EXIT

    test_profile="$test_dir/profile"
    # Ubuntu default ~/.profile: ~/.bashrc first, then $HOME/bin and
    # $HOME/.local/bin, which is why the shims need a re-prepend at the end.
    cat >"$test_profile" <<'EOF'
# Ubuntu default ~/.profile
if [ -n "$BASH_VERSION" ]; then
    if [ -f "$HOME/.bashrc" ]; then
        . "$HOME/.bashrc"
    fi
fi
if [ -d "$HOME/bin" ] ; then
    PATH="$HOME/bin:$PATH"
fi
if [ -d "$HOME/.local/bin" ] ; then
    PATH="$HOME/.local/bin:$PATH"
fi
EOF

    "$ROOT_DIR/home/modify_dot_profile" <"$test_profile" >"${test_profile}.first"
    "$ROOT_DIR/home/modify_dot_profile" <"${test_profile}.first" >"${test_profile}.second"
    cmp "${test_profile}.first" "${test_profile}.second"
    [[ $(grep -c '^# BEGIN workstation-config$' "${test_profile}.second") -eq 1 ]]
    [[ $(grep -c '^# END workstation-config$' "${test_profile}.second") -eq 1 ]]
    grep -Fq 'activate bash --shims' "${test_profile}.second"
    grep -Fq 'PATH="$HOME/.local/bin:$PATH"' "${test_profile}.second"

    # A user-local gh must not shadow the mise shim in a login shell.
    fake_home="$test_dir/fakehome"
    mkdir -p "$fake_home/.local/bin" "$fake_home/mise-data/shims"
    printf '#!/usr/bin/env bash\necho user-local\n' >"$fake_home/.local/bin/gh"
    cat >"$fake_home/.local/bin/mise" <<'EOF'
#!/usr/bin/env bash
printf 'export PATH="%s/shims:$PATH"\n' "$HOME/mise-data"
EOF
    printf '#!/usr/bin/env bash\necho mise-shim\n' >"$fake_home/mise-data/shims/gh"
    chmod +x \
      "$fake_home/.local/bin/gh" \
      "$fake_home/.local/bin/mise" \
      "$fake_home/mise-data/shims/gh"

    resolved="$(HOME="$fake_home" PATH=/usr/bin:/bin bash --noprofile --norc -c \
      '. "$1"; command -v gh' _ "${test_profile}.second" 2>&1)"
    [[ $resolved == "$fake_home/mise-data/shims/gh" ]]

    first_path="$(HOME="$fake_home" PATH=/usr/bin:/bin bash --noprofile --norc -c \
      '. "$1"; printf "%s\\n" "${PATH%%:*}"' _ "${test_profile}.second" 2>&1)"
    [[ $first_path == "$fake_home/mise-data/shims" ]]

    # POSIX login shells (dash) must run the block silently; `[[` or other
    # bash-only syntax would fail here instead of re-prepending the shims.
    sh_resolved="$(HOME="$fake_home" PATH=/usr/bin:/bin sh -c \
      '. "$1"; command -v gh' _ "${test_profile}.second" 2>&1)"
    [[ $sh_resolved == "$fake_home/mise-data/shims/gh" ]]

    # Without mise the block must be a silent no-op.
    no_mise_home="$test_dir/no-mise"
    mkdir -p "$no_mise_home/.local/bin"
    printf '#!/usr/bin/env bash\necho user-local\n' >"$no_mise_home/.local/bin/gh"
    chmod +x "$no_mise_home/.local/bin/gh"

    no_mise_resolved="$(HOME="$no_mise_home" PATH=/usr/bin:/bin bash --noprofile --norc -c \
      '. "$1"; command -v gh' _ "${test_profile}.second" 2>&1)"
    [[ $no_mise_resolved == "$no_mise_home/.local/bin/gh" ]]
    ;;
  *)
    printf 'Usage: %s <stage: syntax-bashrc|syntax-profile|syntax-init|mise-activate|autoupdate|bashrc-suite|profile-suite>\n' "$0" >&2
    exit 2
    ;;
esac
