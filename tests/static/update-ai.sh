#!/usr/bin/env bash
# shellcheck disable=SC2016
set -euo pipefail
ROOT_DIR="${ROOT_DIR:?ROOT_DIR must be exported by tests/static.sh}"

grep -q '^safe_chain_version:' "$ROOT_DIR/ansible/vars/main.yml"
grep -q '^safe_chain_installer_url:' "$ROOT_DIR/ansible/vars/main.yml"
grep -q '^safe_chain_installer_checksum:' "$ROOT_DIR/ansible/vars/main.yml"
# Regression check: AikidoSec/safe-chain release tags do not use a "v" prefix.
if grep -q 'v{{ safe_chain_version }}' "$ROOT_DIR/ansible/vars/main.yml"; then
  printf 'safe_chain_installer_url must not use a v-prefixed release tag.\n' >&2
  exit 1
fi
safe_chain_version="$(awk -F'"' '/^safe_chain_version:/{print $2}' "$ROOT_DIR/ansible/vars/main.yml")"
safe_chain_url="https://github.com/AikidoSec/safe-chain/releases/download/${safe_chain_version}/install-safe-chain.sh"
if ! curl -sI --fail --max-time 10 "$safe_chain_url" >/dev/null; then
  printf 'Safe-chain installer URL is not reachable: %s\n' "$safe_chain_url" >&2
  exit 1
fi

bash -n "$ROOT_DIR/scripts/update-ai"
grep -q 'SAFE_CHAIN_MINIMUM_PACKAGE_AGE_EXCLUSIONS="@openai/codex"' "$ROOT_DIR/scripts/update-ai"
grep -q 'SAFE_CHAIN_MINIMUM_PACKAGE_AGE_EXCLUSIONS="@earendil-works/\*"' "$ROOT_DIR/scripts/update-ai"
grep -Fq 'SAFE_CHAIN_MINIMUM_PACKAGE_AGE_EXCLUSIONS="$npm_package"' "$ROOT_DIR/scripts/update-ai"
grep -q 'npm install --global @openai/codex@latest' "$ROOT_DIR/scripts/update-ai"
grep -Fq '"npm:pi-web-access"' "$ROOT_DIR/scripts/update-ai"
grep -Fq '"npm:pi-codex-image-gen"' "$ROOT_DIR/scripts/update-ai"
grep -Fq '"npm:@howaboua/pi-codex-conversion"' "$ROOT_DIR/scripts/update-ai"
grep -Fq '"npm:@ogulcancelik/pi-session-recall"' "$ROOT_DIR/scripts/update-ai"
grep -Fq 'pi install "$source"' "$ROOT_DIR/scripts/update-ai"
grep -Fq 'pi update "$source"' "$ROOT_DIR/scripts/update-ai"
grep -Fq 'pi list --no-approve' "$ROOT_DIR/scripts/update-ai"
grep -Fq 'require_supported_node' "$ROOT_DIR/scripts/update-ai"
grep -Fq -- '--no-approve' "$ROOT_DIR/scripts/update-ai"
grep -Fq 'PI_MINIMUM_VERSION_MINOR=84' "$ROOT_DIR/scripts/update-ai"
grep -Fq 'PI_MINIMUM_VERSION_PATCH=2' "$ROOT_DIR/scripts/update-ai"
grep -Fq 'NODE_MINIMUM_VERSION_MINOR=19' "$ROOT_DIR/scripts/update-ai"
grep -Fq 'expected_npm_command=' "$ROOT_DIR/scripts/update-ai"
grep -Fq 'config_path="$pi_agent_dir/pi-codex-conversion.json"' "$ROOT_DIR/scripts/update-ai"
grep -Fq '.tools.webRun = false' "$ROOT_DIR/scripts/update-ai"
grep -Fq '.tools.imageGeneration = false' "$ROOT_DIR/scripts/update-ai"
grep -Fq '.tools.webRunOnly = false' "$ROOT_DIR/scripts/update-ai"
grep -Fq '.tools.imageGenerationOnly = false' "$ROOT_DIR/scripts/update-ai"
grep -Fq 'safe-chain","npm' "$ROOT_DIR/scripts/update-ai"
grep -q 'https://claude.ai/install.sh' "$ROOT_DIR/scripts/update-ai"
grep -q 'https://opencode.ai/install' "$ROOT_DIR/scripts/update-ai"
grep -q -- '--no-modify-path' "$ROOT_DIR/scripts/update-ai"
grep -q 'scripts/update-ai' "$ROOT_DIR/ansible/roles/personal/tasks/main.yml"
grep -Fq 'exec "$mise_bin" exec node -- "$0" "$@"' "$ROOT_DIR/scripts/update-ai"
grep -Fq 'MISE_LOCKED: "1"' "$ROOT_DIR/ansible/roles/personal/tasks/main.yml"
grep -Fq "personal_ai_tools | map('regex_replace', '^', '--')" \
  "$ROOT_DIR/ansible/roles/personal/tasks/main.yml"
grep -Fq "when: personal_ai_tools | length > 0" \
  "$ROOT_DIR/ansible/roles/personal/tasks/main.yml"
