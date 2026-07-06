# Shared interactive Bash initialization for workstation-config.
# This file must also be safe when explicitly sourced by a non-interactive shell.
case $- in
  *i*) ;;
  *) return 0 ;;
esac

if [[ -x "$HOME/.local/bin/mise" ]]; then
  eval "$("$HOME/.local/bin/mise" activate bash)"
elif command -v mise >/dev/null 2>&1; then
  eval "$(mise activate bash)"
fi

if [[ -f "$HOME/.safe-chain/scripts/init-posix.sh" && -r "$HOME/.safe-chain/scripts/init-posix.sh" ]]; then
  # shellcheck disable=SC1091
  source "$HOME/.safe-chain/scripts/init-posix.sh"
fi

# Claude Code updates are owned by update-ai, not by the CLI background updater.
export DISABLE_AUTOUPDATER=1
export PATH="$HOME/.opencode/bin:$PATH"

alias g=git
alias h=herdr

if [[ -f "$HOME/.config/workstation/shell/local.bash" && -r "$HOME/.config/workstation/shell/local.bash" ]]; then
  # shellcheck disable=SC1091
  source "$HOME/.config/workstation/shell/local.bash"
fi

if [[ -n ${WT_SESSION:-} && -n ${WSL_DISTRO_NAME:-} && -z ${__WORKSTATION_CWD_HOOK_INITIALIZED:-} ]] \
  && command -v wslpath >/dev/null 2>&1; then
  __workstation_report_cwd() {
    printf '\e]9;9;%s\e\\' "$(wslpath -w "$PWD")"
  }

  if [[ ${PROMPT_COMMAND:-} != *"__workstation_report_cwd"* ]]; then
    if [[ $(declare -p PROMPT_COMMAND 2>/dev/null || true) == "declare -a"* ]]; then
      PROMPT_COMMAND+=(__workstation_report_cwd)
    else
      PROMPT_COMMAND="${PROMPT_COMMAND:+${PROMPT_COMMAND};}__workstation_report_cwd"
    fi
  fi
  __WORKSTATION_CWD_HOOK_INITIALIZED=1
fi

if command -v starship >/dev/null 2>&1 && [[ -z ${__WORKSTATION_STARSHIP_INITIALIZED:-} ]]; then
  __WORKSTATION_STARSHIP_INITIALIZED=1
  eval "$(starship init bash)"
fi
