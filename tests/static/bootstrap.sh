#!/usr/bin/env bash
# shellcheck disable=SC1003,SC2016
set -euo pipefail
ROOT_DIR="${ROOT_DIR:?ROOT_DIR must be exported by tests/static.sh}"

case "${1:-}" in
  syntax)
    bash -n "$ROOT_DIR/bootstrap"
    "$ROOT_DIR/bootstrap" --help >/dev/null
    ;;
  vars)
    grep -q '^MISE_LOCKED=1' "$ROOT_DIR/bootstrap"
    grep -Fq 'WORKSTATION_PERSONAL_AI_TOOLS' "$ROOT_DIR/bootstrap"
    grep -q 'chezmoi.*apply.*--no-tty.*--force' "$ROOT_DIR/bootstrap"
    grep -Fq 'activate bash --shims' "$ROOT_DIR/bootstrap"
    ;;
  ci-workflow)
    grep -Fq 'Install pinned chezmoi binary' "$ROOT_DIR/.github/workflows/ci.yml"
    ;;
  sudo-env)
    grep -Fq 'env \' "$ROOT_DIR/bootstrap"
    grep -Fq 'ANSIBLE_BECOME_EXE="$SUDO_EXE"' "$ROOT_DIR/bootstrap"
    grep -Fq 'ANSIBLE_BECOME_ASK_PASS="$ASK_PASS"' "$ROOT_DIR/bootstrap"
    grep -q '^"${SUDO_EXE:-sudo}" -v$' "$ROOT_DIR/bootstrap"
    grep -q '\[\[ -n \$SUDO_EXE \]\]' "$ROOT_DIR/bootstrap"

    ansible_env_output="$(
      env \
        ANSIBLE_CONFIG="$ROOT_DIR/ansible/ansible.cfg" \
        ANSIBLE_BECOME_EXE=/usr/bin/sudo.ws \
        ANSIBLE_BECOME_ASK_PASS=True \
        bash -c 'printf "%s\n%s\n%s\n" "$ANSIBLE_CONFIG" "$ANSIBLE_BECOME_EXE" "$ANSIBLE_BECOME_ASK_PASS"'
    )"
    [[ $ansible_env_output == "$ROOT_DIR/ansible/ansible.cfg"$'\n'/usr/bin/sudo.ws$'\n'True ]]
    ;;
  invalid-profile)
    if "$ROOT_DIR/bootstrap" invalid >/dev/null 2>&1; then
      printf 'Invalid profile was accepted.\n' >&2
      exit 1
    fi
    ;;
  *)
    printf 'Usage: %s <stage: syntax|vars|ci-workflow|sudo-env|invalid-profile>\n' "$0" >&2
    exit 2
    ;;
esac
