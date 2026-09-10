#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="${ROOT_DIR:?ROOT_DIR must be exported by tests/static.sh}"

case "${1:-}" in
  config)
    codex_config="$ROOT_DIR/home/dot_codex/config.toml"
    test -f "$codex_config"
    grep -Fxq 'hooks = true' "$codex_config"
    grep -Fxq 'apps = false' "$codex_config"
    # issue #191: model別context budgetはmodel catalogで管理する
    grep -Fxq 'model_catalog_json = "~/.codex/model-catalogs/workstation.json"' "$codex_config"
    if grep -Eq '^(model_context_window|model_auto_compact_token_limit)[[:space:]]*=' "$codex_config"; then
      printf 'Codex config must not set global model_context_window / model_auto_compact_token_limit.\n' >&2
      exit 1
    fi
    codex_catalog="$ROOT_DIR/home/dot_codex/model-catalogs/workstation.json"
    test -f "$codex_catalog"
    command -v jq >/dev/null 2>&1 || {
      printf 'codex.sh config: jq is required.\n' >&2
      exit 1
    }
    # カタログは全モデル分のメタデータを含み、budget値はdocs/ai-model-context-budget.mdと一致する
    jq -e '
      (.models | length >= 10) and
      ([.models[] | select(.slug == "gpt-6-astra" or .slug == "gpt-5.6-sol" or .slug == "gpt-5.6-terra")] | length == 3) and
      ([.models[] | select(.slug == "gpt-5.6-luna")] | length == 1) and
      ([.models[] | select(.slug == "gpt-6-astra" or .slug == "gpt-5.6-sol" or .slug == "gpt-5.6-terra") | .context_window == 272000 and .auto_compact_token_limit == 240000] | all) and
      ([.models[] | select(.slug == "gpt-5.6-luna") | .context_window == 1050000 and .auto_compact_token_limit == 945000] | all) and
      ([.models[] | .model_messages.instructions_template != null and .model_messages.instructions_template != ""] | all)
    ' "$codex_catalog" >/dev/null
    ;;
  *)
    printf 'Usage: %s <stage: config>\n' "$0" >&2
    exit 2
    ;;
esac
