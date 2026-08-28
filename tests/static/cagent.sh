#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="${ROOT_DIR:?ROOT_DIR must be exported by tests/static.sh}"

case "${1:-}" in
  config)
    cagent_config="$ROOT_DIR/home/dot_config/cagent/config.yaml"
    test -f "$cagent_config"
    grep -Fq 'default_agent: codex' "$cagent_config"
    grep -Fq 'default_profile: reasoner' "$cagent_config"
    grep -Fq '  worker-codex:' "$cagent_config"
    grep -A 3 -F '  worker-codex:' "$cagent_config" | grep -Fxq '    effort: max'
    grep -Fq '  worker-opencode:' "$cagent_config"
    grep -Fq '  reasoner:' "$cagent_config"
    grep -A 3 -F '  reasoner:' "$cagent_config" | grep -Fxq '    effort: high'
    grep -Fq '  reviewer:' "$cagent_config"
    grep -A 3 -F '  reviewer:' "$cagent_config" | grep -Fxq '    effort: xhigh'
    grep -Fq '  orchestrator:' "$cagent_config"
    grep -Fq '  opencode-go:' "$cagent_config"
    grep -Fq '    start_command_template: "cagent {profile}"' "$cagent_config"
    grep -Fq '    run_command_template: "cagent run {profile} -- {prompt}"' "$cagent_config"
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
