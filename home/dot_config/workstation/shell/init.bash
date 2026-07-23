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

__workstation_update_runner_liveness() {
  local state_file=$1 runner_pid runner_start_time proc_stat actual_start_time

  runner_pid="$(awk -F '\t' '$1 == "runner_pid" { print $2; exit }' "$state_file")"
  runner_start_time="$(awk -F '\t' '$1 == "runner_start_time" { print $2; exit }' "$state_file")"
  if [[ ! $runner_pid =~ ^[1-9][0-9]*$ || ! $runner_start_time =~ ^[0-9]+$ ]]; then
    printf 'unknown\n'
    return
  fi
  if [[ ! -r /proc/$runner_pid/stat ]]; then
    printf 'dead\n'
    return
  fi
  proc_stat="$(<"/proc/$runner_pid/stat")" || {
    printf 'dead\n'
    return
  }
  proc_stat=${proc_stat##*) }
  actual_start_time="$(awk '{ print $20 }' <<<"$proc_stat")"
  if [[ $actual_start_time == "$runner_start_time" ]]; then
    printf 'alive\n'
  else
    printf 'dead\n'
  fi
}

__workstation_update_state="$HOME/.local/state/workstation-update/state.tsv"
if [[ -r $__workstation_update_state ]]; then
  __workstation_update_status="$(
    awk -F '\t' '$1 == "status" { print $2; exit }' "$__workstation_update_state"
  )"
  case $__workstation_update_status in
    running)
      __workstation_update_liveness="$(__workstation_update_runner_liveness "$__workstation_update_state")"
      if [[ $__workstation_update_liveness == dead ]]; then
        printf '\033[31m✗ workstation update stopped unexpectedly — watch-update\033[0m\n' >&2
      else
        printf '\033[36m⟳ 非同期で更新中です...（watch-update で詳細を確認できます）\033[0m\n' >&2
      fi
      ;;
    failed)
      __workstation_update_failed_step="$(
        awk -F '\t' '$1 == "failed_step" { print $2; exit }' "$__workstation_update_state"
      )"
      printf '\033[31m✗ %s update failed — watch-update --verbose\033[0m\n' \
        "${__workstation_update_failed_step:-workstation}" >&2
      ;;
  esac
fi
unset __workstation_update_state __workstation_update_status
unset __workstation_update_failed_step __workstation_update_liveness
unset -f __workstation_update_runner_liveness

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

if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init bash)"
fi
