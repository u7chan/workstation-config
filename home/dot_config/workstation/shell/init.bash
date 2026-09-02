# Shared interactive Bash initialization for workstation-config.
# This file must also be safe when explicitly sourced by a non-interactive shell.
case $- in
  *i*) ;;
  *) return 0 ;;
esac

# Use stable shims instead of version-specific install paths. This keeps an
# existing shell from selecting an older tool after `mise install` and keeps
# user-local binaries from shadowing mise-managed tools.
if [[ -x "$HOME/.local/bin/mise" ]]; then
  eval "$("$HOME/.local/bin/mise" activate bash --shims)"
elif command -v mise >/dev/null 2>&1; then
  eval "$(mise activate bash --shims)"
fi

if [[ -f "$HOME/.safe-chain/scripts/init-posix.sh" && -r "$HOME/.safe-chain/scripts/init-posix.sh" ]]; then
  # shellcheck disable=SC1091
  source "$HOME/.safe-chain/scripts/init-posix.sh"
fi

# Claude Code updates are owned by update-ai, not by the CLI background updater.
export DISABLE_AUTOUPDATER=1
export PATH="$HOME/.opencode/bin:$PATH"

export EDITOR=nvim
export VISUAL=nvim

alias g=git
alias h=herdr

__workstation_open() {
  local path="${1:-.}"
  local windows_path

  if [[ $# -gt 1 ]]; then
    printf 'open: expected at most one path\n' >&2
    return 2
  fi

  if ! command -v wslpath >/dev/null 2>&1 || ! command -v explorer.exe >/dev/null 2>&1; then
    printf 'open: WSL interop is unavailable; ensure wslpath and explorer.exe are available\n' >&2
    return 127
  fi

  windows_path="$(wslpath -w "$path")" || return
  command explorer.exe "$windows_path" || true
}

alias open='__workstation_open'

if [[ -f "$HOME/.config/workstation/shell/local.bash" && -r "$HOME/.config/workstation/shell/local.bash" ]]; then
  # shellcheck disable=SC1091
  source "$HOME/.config/workstation/shell/local.bash"
fi

if [[ -n ${WT_SESSION:-} && -n ${WSL_DISTRO_NAME:-} && -z ${__WORKSTATION_CWD_HOOK_INITIALIZED:-} ]] \
  && command -v wslpath >/dev/null 2>&1; then
  __workstation_report_cwd() {
    # shellcheck disable=SC1003
    printf '\e]9;9;%s\e\\' "$(wslpath -w "$PWD")"
  }

  if [[ ${PROMPT_COMMAND:-} != *"__workstation_report_cwd"* ]]; then
    if [[ $(declare -p PROMPT_COMMAND 2>/dev/null || true) == "declare -a"* ]]; then
      PROMPT_COMMAND+=(__workstation_report_cwd)
    else
      # shellcheck disable=SC2128,SC2178
      PROMPT_COMMAND="${PROMPT_COMMAND:+${PROMPT_COMMAND};}__workstation_report_cwd"
    fi
  fi
  __WORKSTATION_CWD_HOOK_INITIALIZED=1
fi

if command -v starship >/dev/null 2>&1 && [[ -z ${__WORKSTATION_STARSHIP_INITIALIZED:-} ]]; then
  __WORKSTATION_STARSHIP_INITIALIZED=1
  eval "$(starship init bash)"
fi

if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init bash)"
fi
