#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="${ROOT_DIR:?ROOT_DIR must be exported by tests/static.sh}"

case "${1:-}" in
  doc-json)
    windows_terminal_doc="$ROOT_DIR/docs/windows-terminal.md"
    test -f "$windows_terminal_doc"
    grep -Fq 'Windows Terminal設定' "$ROOT_DIR/README.md"
    grep -Fq 'wsl.exe --distribution {WSLディストリビューション名}' "$windows_terminal_doc"
    grep -Fq '"defaultProfile": "{11111111-1111-1111-1111-111111111111}"' "$windows_terminal_doc"
    grep -Fq '"commandline": "powershell.exe"' "$windows_terminal_doc"
    grep -Fq '"Windows.Terminal.Wsl"' "$windows_terminal_doc"

    test_dir="$(mktemp -d)"
    trap 'rm -rf "$test_dir"' EXIT

    windows_terminal_json_dir="$test_dir/windows-terminal-json"
    mkdir -p "$windows_terminal_json_dir"
    awk -v output_dir="$windows_terminal_json_dir" '
      /^```json[[:space:]]*$/ {
        if (in_block) {
          printf "Nested JSON code block in %s.\n", FILENAME > "/dev/stderr"
          failed = 1
          next
        }
        in_block = 1
        output_path = sprintf("%s/block-%d.json", output_dir, ++block_count)
        next
      }
      /^```[[:space:]]*$/ {
        if (in_block) {
          in_block = 0
        }
        next
      }
      in_block {
        print > output_path
      }
      END {
        if (in_block) {
          printf "Unterminated JSON code block in %s.\n", FILENAME > "/dev/stderr"
          failed = 1
        }
        if (block_count != 1) {
          printf "Expected exactly 1 JSON code block in %s, found %d.\n", FILENAME, block_count > "/dev/stderr"
          failed = 1
        }
        exit failed
      }
    ' "$windows_terminal_doc"
    for windows_terminal_json in "$windows_terminal_json_dir"/*.json; do
      jq empty "$windows_terminal_json"
    done
    ;;
  *)
    printf 'Usage: %s <stage: doc-json>\n' "$0" >&2
    exit 2
    ;;
esac
