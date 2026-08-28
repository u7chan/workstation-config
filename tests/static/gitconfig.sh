#!/usr/bin/env bash
# shellcheck disable=SC2088,SC2251
set -euo pipefail
ROOT_DIR="${ROOT_DIR:?ROOT_DIR must be exported by tests/static.sh}"

case "${1:-}" in
  syntax)
    bash -n "$ROOT_DIR/home/modify_dot_gitconfig"
    ;;
  suite)
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
      if ! printf '%s\n' "${expected_aliases[@]}" | grep -Fx "$key" >/dev/null; then
        printf 'Unexpected alias %s found; only allowlisted aliases may be managed.\n' "$key" >&2
        exit 1
      fi
    done

    if git config --file "$gitconfig_second" --get-all safe.directory 2>/dev/null | grep -Fqx '*'; then
      printf 'safe.directory=* must not be set by chezmoi.\n' >&2
      exit 1
    fi
    ;;
  *)
    printf 'Usage: %s <stage: syntax|suite>\n' "$0" >&2
    exit 2
    ;;
esac
