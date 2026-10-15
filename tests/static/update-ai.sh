#!/usr/bin/env bash
# shellcheck disable=SC2016
set -euo pipefail
ROOT_DIR="${ROOT_DIR:?ROOT_DIR must be exported by tests/static.sh}"

case "${1:-}" in
  syntax)
    bash -n "$ROOT_DIR/scripts/update-ai"
    ;;
  safe-chain-and-greps)
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

    grep -Fq 'compute_npm_before()' "$ROOT_DIR/scripts/update-ai"
    grep -Fq 'safe_chain_minimum_package_age_hours()' "$ROOT_DIR/scripts/update-ai"
    grep -Fq 'SAFE_CHAIN_MINIMUM_PACKAGE_AGE_HOURS:-48' "$ROOT_DIR/scripts/update-ai"
    grep -Fq 'report_pi_versions' "$ROOT_DIR/scripts/update-ai"
    grep -Fq 'report_pi_versions "$pi_packages_npm_before"' "$ROOT_DIR/scripts/update-ai"
    grep -Fq 'published_epoch > cutoff_epoch' "$ROOT_DIR/scripts/update-ai"
    grep -Fq 'published_nanoseconds' "$ROOT_DIR/scripts/update-ai"
    grep -Fq 'deferred until %s (published %s)' "$ROOT_DIR/scripts/update-ai"
    grep -Fq 'newest allowed version' "$ROOT_DIR/scripts/update-ai"
    grep -Fq 'registry lookup failed; age gate status unknown' "$ROOT_DIR/scripts/update-ai"
    grep -Fq 'registry lookup failed; update status unknown' "$ROOT_DIR/scripts/update-ai"
    # The status lookup reads the true registry state, so it skips the gate
    # whose suppression and stdout notice would hide the held-back version.
    grep -Fq 'npm view "$package_name" dist-tags time --json --safe-chain-skip-minimum-package-age' \
      "$ROOT_DIR/scripts/update-ai"
    grep -Fq 'age gate skipped' "$ROOT_DIR/scripts/update-ai"
    grep -Fq 'ensure_pi_packages "$pi_packages_npm_before"' "$ROOT_DIR/scripts/update-ai"
    grep -Fq 'npm_config_before="$npm_before"' "$ROOT_DIR/scripts/update-ai"
    # The Pi core install skips the age gate; the Pi packages keep it.
    grep -Fq 'npm install --global --ignore-scripts "$PI_PACKAGE_NAME@latest"' \
      "$ROOT_DIR/scripts/update-ai"
    grep -Fq -- '--safe-chain-skip-minimum-package-age' "$ROOT_DIR/scripts/update-ai"
    if grep -qF 'SAFE_CHAIN_MINIMUM_PACKAGE_AGE_EXCLUSIONS' "$ROOT_DIR/scripts/update-ai"; then
      printf 'update-ai must align npm resolution instead of excluding packages from the age gate.\n' >&2
      exit 1
    fi
    if grep -qF '@openai/codex' "$ROOT_DIR/scripts/update-ai"; then
      printf 'update-ai must not install the retired Codex CLI.\n' >&2
      exit 1
    fi
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
    # The myupdate coverage table prints the Pi package count, so it must match
    # the sources update-ai installs.
    pi_package_count="$(grep -c '^  "npm:' "$ROOT_DIR/scripts/update-ai")"
    grep -Fq "readonly PI_PACKAGE_COUNT=$pi_package_count" \
      "$ROOT_DIR/scripts/personal-bin/myupdate"
    grep -q 'https://claude.ai/install.sh' "$ROOT_DIR/scripts/update-ai"
    grep -q 'https://opencode.ai/install' "$ROOT_DIR/scripts/update-ai"
    grep -q -- '--no-modify-path' "$ROOT_DIR/scripts/update-ai"
    grep -q 'scripts/update-ai' "$ROOT_DIR/ansible/roles/personal/tasks/update_ai.yml"
    grep -Fq 'exec "$mise_bin" exec node -- "$0" "$@"' "$ROOT_DIR/scripts/update-ai"
    grep -Fq "'MISE_LOCKED': '1'" "$ROOT_DIR/ansible/roles/personal/vars/main.yml"
    grep -Fq "personal_ai_tools | map('regex_replace', '^', '--')" \
      "$ROOT_DIR/ansible/roles/personal/tasks/update_ai.yml"
    grep -Fq "when: personal_ai_tools | length > 0" \
      "$ROOT_DIR/ansible/roles/personal/tasks/update_ai.yml"
    ;;
  *)
    printf 'Usage: %s <stage: syntax|safe-chain-and-greps>\n' "$0" >&2
    exit 2
    ;;
esac
