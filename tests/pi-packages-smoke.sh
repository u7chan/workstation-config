#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly ROOT_DIR

test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT

make_common_commands() {
  local fixture_bin=$1

  cat >"$fixture_bin/npm" <<'EOF'
#!/usr/bin/env bash
printf 'direct npm %s\n' "$*" >>"$TEST_INSTALL_LOG"
exit 99
EOF
  cat >"$fixture_bin/node" <<'EOF'
#!/usr/bin/env bash
if [[ ${1:-} == --version ]]; then
  printf 'v24.18.0\n'
else
  exit 99
fi
EOF
  cat >"$fixture_bin/curl" <<'EOF'
#!/usr/bin/env bash
exit 99
EOF
  cat >"$fixture_bin/mise" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ ${1:-} == exec && ${2:-} == node && ${3:-} == -- ]]
shift 3
exec "$@"
EOF
  cat >"$fixture_bin/safe-chain" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ ${1:-} == npm ]]
printf 'safe-chain %s exclusion=%s\n' "$*" \
  "${SAFE_CHAIN_MINIMUM_PACKAGE_AGE_EXCLUSIONS:-}" >>"$TEST_INSTALL_LOG"
EOF
  chmod +x "$fixture_bin/npm" "$fixture_bin/node" "$fixture_bin/curl" \
    "$fixture_bin/mise" "$fixture_bin/safe-chain"
}

fixture_home="$test_dir/home"
fixture_bin="$test_dir/bin"
fixture_log="$test_dir/commands.log"
mkdir -p "$fixture_home/.safe-chain/scripts" "$fixture_home/.local/bin" "$fixture_bin"
make_common_commands "$fixture_bin"

cat >"$fixture_home/.safe-chain/scripts/init-posix.sh" <<'EOF'
npm() {
  printf 'core npm exclusion=%s args=%s\n' \
    "${SAFE_CHAIN_MINIMUM_PACKAGE_AGE_EXCLUSIONS:-}" "$*" >>"$TEST_INSTALL_LOG"
}
EOF

cat >"$fixture_bin/pi" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
package_settings="$HOME/.pi/agent/settings.json"
case "${1:-}" in
  --version)
    printf '0.84.2\n'
    ;;
  list)
    if [[ -f $package_settings ]] && \
      jq -e '((.packages? // []) | type == "array" and length > 0)' \
        "$package_settings" >/dev/null; then
      printf 'User packages:\n'
      jq -r '.packages[] | "  " + .' "$package_settings"
    else
      printf 'No packages installed.\n'
    fi
    ;;
  install|update)
    case "${2:-}" in
      npm:pi-web-access|npm:pi-codex-image-gen|npm:@howaboua/pi-codex-conversion) ;;
      *)
        printf 'unexpected Pi package source: %s\n' "${2:-}" >&2
        exit 1
        ;;
    esac
    printf 'pi %s\n' "$*" >>"$TEST_INSTALL_LOG"
    mise exec node -- safe-chain npm install "${2#npm:}"
    mkdir -p -- "${package_settings%/*}"
    temporary_path="$(mktemp "${package_settings}.tmp.XXXXXXXXXX")"
    if [[ -f $package_settings ]]; then
      jq --arg source "${2}" '
        .packages = (
          if (.packages? | type) == "array" then .packages else [] end
          | if index($source) == null then . + [$source] else . end
        )
      ' "$package_settings" >"$temporary_path"
    else
      jq -n --arg source "${2}" '{packages: [$source]}' >"$temporary_path"
    fi
    mv -- "$temporary_path" "$package_settings"
    ;;
  *)
    printf 'unexpected Pi command: %s\n' "$*" >&2
    exit 1
    ;;
esac
EOF
chmod +x "$fixture_bin/pi"

mkdir -p "$fixture_home/.pi/agent/extensions"
printf '%s\n' '{"packages":["npm:existing"],"unmanaged":{"keep":true}}' \
  >"$fixture_home/.pi/agent/settings.json"
printf '%s\n' 'export default {}' \
  >"$fixture_home/.pi/agent/extensions/herdr-agent-state.ts"
printf '%s\n' '{"unmanaged":{"keep":true},"tools":{"custom":"keep","webRun":true,"imageGeneration":true,"webRunOnly":true,"imageGenerationOnly":true}}' \
  >"$fixture_home/.pi/agent/pi-codex-conversion.json"

run_pi_update() {
  HOME="$fixture_home" \
  PATH="$fixture_bin:$fixture_home/.local/bin:$PATH" \
  TEST_INSTALL_LOG="$fixture_log" \
  UPDATE_AI_MISE_ACTIVE=1 \
    "$ROOT_DIR/scripts/update-ai" --pi >/dev/null
}

run_pi_update
cp "$fixture_home/.pi/agent/settings.json" "$test_dir/settings.after-first"
cp "$fixture_home/.pi/agent/pi-codex-conversion.json" "$test_dir/codex-conversion.after-first"
run_pi_update

for package in pi-web-access pi-codex-image-gen @howaboua/pi-codex-conversion; do
  [[ $(grep -c "^pi install npm:${package} --no-approve$" "$fixture_log") -eq 1 ]]
  [[ $(grep -c "^pi update npm:${package} --no-approve$" "$fixture_log") -eq 1 ]]
  [[ $(grep -c "^safe-chain npm install ${package} exclusion=${package}$" "$fixture_log") -eq 2 ]]
done
[[ $(grep -c '^direct npm ' "$fixture_log") -eq 0 ]]
[[ $(grep -c '^core npm ' "$fixture_log") -eq 2 ]]
cmp "$test_dir/settings.after-first" "$fixture_home/.pi/agent/settings.json"
cmp "$test_dir/codex-conversion.after-first" \
  "$fixture_home/.pi/agent/pi-codex-conversion.json"

package_list="$(HOME="$fixture_home" PATH="$fixture_bin:$PATH" pi list)"
[[ $(grep -c '^  npm:pi-web-access$' <<<"$package_list") -eq 1 ]]
[[ $(grep -c '^  npm:pi-codex-image-gen$' <<<"$package_list") -eq 1 ]]
[[ $(grep -c '^  npm:@howaboua/pi-codex-conversion$' <<<"$package_list") -eq 1 ]]
jq -e '
  .packages == ["npm:existing", "npm:pi-web-access", "npm:pi-codex-image-gen", "npm:@howaboua/pi-codex-conversion"]
  and .unmanaged.keep == true
  and .npmCommand == ["mise", "exec", "node", "--", "safe-chain", "npm"]
' "$fixture_home/.pi/agent/settings.json" >/dev/null
jq -e '
  .unmanaged.keep == true
  and .tools.custom == "keep"
  and .tools.webRun == false
  and .tools.imageGeneration == false
  and .tools.webRunOnly == false
  and .tools.imageGenerationOnly == false
' "$fixture_home/.pi/agent/pi-codex-conversion.json" >/dev/null
[[ -e "$fixture_home/.pi/agent/extensions/herdr-agent-state.ts" ]]
[[ ! -e "$fixture_home/.pi/web-search.json" ]]
[[ ! -e "$fixture_home/.pi/agent/extensions/codex-image-gen.json" ]]
[[ ! -e "$fixture_home/.pi/agent/generated-images" ]]
if find "$fixture_home/.pi/agent" -maxdepth 1 \( \
  -name '.settings.json.tmp.*' -o -name '.pi-codex-conversion.json.tmp.*' \
\) -print -quit | grep -q .; then
  printf 'Pi settings temporary files must be removed.\n' >&2
  exit 1
fi

# A selected tool set without Pi must not create Pi settings or invoke Pi.
no_pi_home="$test_dir/no-pi-home"
no_pi_bin="$test_dir/no-pi-bin"
no_pi_log="$test_dir/no-pi.log"
mkdir -p "$no_pi_home/.safe-chain/scripts" "$no_pi_home/.local/bin" "$no_pi_bin"
make_common_commands "$no_pi_bin"
cat >"$no_pi_home/.safe-chain/scripts/init-posix.sh" <<'EOF'
npm() {
  printf 'core npm exclusion=%s args=%s\n' \
    "${SAFE_CHAIN_MINIMUM_PACKAGE_AGE_EXCLUSIONS:-}" "$*" >>"$TEST_INSTALL_LOG"
  cat >"$HOME/.local/bin/codex" <<'SCRIPT'
#!/usr/bin/env bash
printf '0.1.0\n'
SCRIPT
  chmod +x "$HOME/.local/bin/codex"
}
EOF

HOME="$no_pi_home" \
PATH="$no_pi_bin:$no_pi_home/.local/bin:$PATH" \
TEST_INSTALL_LOG="$no_pi_log" \
UPDATE_AI_MISE_ACTIVE=1 \
  "$ROOT_DIR/scripts/update-ai" --codex >/dev/null

[[ ! -e "$no_pi_home/.pi" ]]
if grep -Eq 'pi-web-access|pi-codex-image-gen|pi-codex-conversion' "$no_pi_log"; then
  printf 'Non-Pi update must not invoke Pi package management.\n' >&2
  exit 1
fi

printf 'Pi package smoke checks passed.\n'
