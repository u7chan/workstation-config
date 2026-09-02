#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2088
set -euo pipefail
ROOT_DIR="${ROOT_DIR:?ROOT_DIR must be exported by tests/static.sh}"

case "${1:-}" in
  links)
    grep -Fq 'Bootstrap前の初期セットアップ' "$ROOT_DIR/README.md"
    grep -Fq 'Workstation構成ガイド' "$ROOT_DIR/README.md"
    grep -Fq 'wsl --install Ubuntu-26.04 --name sandbox' "$ROOT_DIR/docs/bootstrap-prerequisites.md"
    grep -Fq 'wsl --unregister sandbox' "$ROOT_DIR/docs/bootstrap-prerequisites.md"
    grep -Fq '破壊的操作' "$ROOT_DIR/docs/bootstrap-prerequisites.md"
    test -f "$ROOT_DIR/docs/workstation.md"
    grep -Fq '[初期セットアップ手順](bootstrap-prerequisites.md)' "$ROOT_DIR/docs/workstation.md"
    test -f "$ROOT_DIR/docs/cli-tools.md"
    grep -Fq '[CLIツールガイド](cli-tools.md)' "$ROOT_DIR/docs/workstation.md"
    grep -Fq '[CLIツールガイド](docs/cli-tools.md)' "$ROOT_DIR/README.md"
    grep -Fq 'WSL sessionには反映されません' "$ROOT_DIR/docs/cli-tools.md"
    ;;
  pi-packages)
    grep -Fq 'herdr integration install <agent>' "$ROOT_DIR/docs/workstation.md"
    grep -Fq 'Pi Packages一覧' "$ROOT_DIR/README.md"
    grep -Fq 'Pi Packages一覧' "$ROOT_DIR/docs/workstation.md"
    grep -Fq 'dot_pi/agent/keybindings.json' "$ROOT_DIR/docs/workstation.md"
    grep -Fq 'keybindings.json' "$ROOT_DIR/docs/roles-boundary.md"
    grep -Fq 'pi-keybindings-smoke' "$ROOT_DIR/docs/workstation.md"
    grep -Fq 'pi-web-search-smoke' "$ROOT_DIR/docs/workstation.md"

    grep -Fq 'pi-web-access' "$ROOT_DIR/docs/pi-packages.md"
    grep -Fq 'web_search' "$ROOT_DIR/docs/pi-packages.md"
    grep -Fq 'fetch_content' "$ROOT_DIR/docs/pi-packages.md"
    grep -Fq 'get_search_content' "$ROOT_DIR/docs/pi-packages.md"
    grep -Fq 'source_check' "$ROOT_DIR/docs/pi-packages.md"
    grep -Fq '~/.pi/web-search.json' "$ROOT_DIR/docs/pi-packages.md"
    grep -Fq 'pi-codex-image-gen' "$ROOT_DIR/docs/pi-packages.md"
    grep -Fq '@howaboua/pi-codex-conversion' "$ROOT_DIR/docs/pi-packages.md"
    grep -Fq '@ogulcancelik/pi-session-recall' "$ROOT_DIR/docs/pi-packages.md"
    grep -Fq 'exec_command' "$ROOT_DIR/docs/pi-packages.md"
    grep -Fq 'write_stdin' "$ROOT_DIR/docs/pi-packages.md"
    grep -Fq 'codex_generate_image' "$ROOT_DIR/docs/pi-packages.md"
    grep -Fq '~/.pi/agent/generated-images/' "$ROOT_DIR/docs/pi-packages.md"
    grep -Fq '~/.pi/agent/pi-codex-conversion.json' "$ROOT_DIR/docs/pi-packages.md"
    grep -Fq 'tools.imageGeneration' "$ROOT_DIR/docs/pi-packages.md"
    grep -Fq 'tools.webRun' "$ROOT_DIR/docs/pi-packages.md"
    grep -Fq 'session_search' "$ROOT_DIR/docs/pi-packages.md"
    grep -Fq 'session_query' "$ROOT_DIR/docs/pi-packages.md"
    grep -Fq '~/.pi/agent/sessions' "$ROOT_DIR/docs/pi-packages.md"
    grep -Fq '~/.pi/agent/session-recall.json' "$ROOT_DIR/docs/pi-packages.md"
    grep -Fq 'background indexing' "$ROOT_DIR/docs/pi-packages.md"
    grep -Fq 'ripgrep' "$ROOT_DIR/docs/pi-packages.md"
    grep -Fq 'Pi Packages' "$ROOT_DIR/docs/roles-boundary.md"
    grep -Fq 'pi-packages.md' "$ROOT_DIR/docs/roles-boundary.md"
    grep -Fq 'Herdr integrationの生成hook/plugin' "$ROOT_DIR/docs/roles-boundary.md"
    test -f "$ROOT_DIR/docs/pi-packages.md"
    grep -Fq '| `npm:pi-web-access` |' "$ROOT_DIR/docs/pi-packages.md"
    grep -Fq '| `npm:pi-codex-image-gen` |' "$ROOT_DIR/docs/pi-packages.md"
    grep -Fq '| `npm:@howaboua/pi-codex-conversion` |' "$ROOT_DIR/docs/pi-packages.md"
    grep -Fq '| `npm:@ogulcancelik/pi-session-recall` |' "$ROOT_DIR/docs/pi-packages.md"
    grep -Fq '0.84.2' "$ROOT_DIR/docs/pi-packages.md"
    ;;
  *)
    printf 'Usage: %s <stage: links|pi-packages>\n' "$0" >&2
    exit 2
    ;;
esac
