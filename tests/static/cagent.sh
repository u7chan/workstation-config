#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="${ROOT_DIR:?ROOT_DIR must be exported by tests/static.sh}"

case "${1:-}" in
  config)
    cagent_config="$ROOT_DIR/home/dot_config/cagent/config.yaml"
    test -f "$cagent_config"
    grep -Fq 'default_agent: opencode-go' "$cagent_config"
    grep -Fq 'default_profile: orchestrator' "$cagent_config"
    grep -Fq '  worker-opencode:' "$cagent_config"
    grep -Fq '  orchestrator:' "$cagent_config"
    grep -Fq '  opencode-go:' "$cagent_config"
    grep -Fq '    start_command_template: "cagent {profile}"' "$cagent_config"
    grep -Fq '    run_command_template: "cagent run {profile} -- {prompt}"' "$cagent_config"
    if grep -Fqi 'codex' "$cagent_config"; then
      printf 'cagent config must not reference the retired Codex CLI.\n' >&2
      exit 1
    fi
    if grep -Eq '^version:[[:space:]]*2$' "$cagent_config"; then
      printf 'cagent config must not declare version: 2.\n' >&2
      exit 1
    fi
    ;;
  *)
    printf 'Usage: %s <stage: config>\n' "$0" >&2
    exit 2
    ;;
esac
