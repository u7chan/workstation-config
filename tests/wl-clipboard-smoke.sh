#!/usr/bin/env bash
set -euo pipefail

# issue #178: WSLg Wayland clipboard fallback for Pi image paste (Alt+V).
# Pi reads pasted images via wl-paste first, so wl-clipboard must be installed
# and the WSLg compositor must be reachable. Windows screenshots (Win+Shift+S)
# arrive over the WSLg clipboard bridge as image/bmp; Pi converts them to PNG.
# This test is read-only: it never replaces the user's clipboard content.

for tool in wl-paste wl-copy; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    printf '%s is not installed.\n' "$tool" >&2
    exit 1
  fi
done

if [ -z "${WAYLAND_DISPLAY:-}" ]; then
  printf 'WAYLAND_DISPLAY is not set. WSLg compositor is not reachable.\n' >&2
  exit 1
fi

types="$(wl-paste --list-types 2>/dev/null)" || {
  printf 'wl-paste --list-types failed. WSLg clipboard bridge is not reachable.\n' >&2
  exit 1
}

# Mirror Pi's selection: read the first available image type if one is offered.
image_type="$(printf '%s\n' "$types" | grep -E '^image/(png|jpeg|webp|gif|bmp)' | head -n 1 || true)"
if [ -n "$image_type" ]; then
  bytes="$(wl-paste --type "$image_type" --no-newline 2>/dev/null | wc -c)" || bytes=0
  if [ "$bytes" -eq 0 ]; then
    printf 'wl-paste offered %s but reading it failed.\n' "$image_type" >&2
    exit 1
  fi
  printf 'wl-clipboard smoke checks passed (image type %s, %s bytes readable).\n' "$image_type" "$bytes"
  exit 0
fi

printf 'wl-clipboard smoke checks passed (no image in the clipboard; take a screenshot with Win+Shift+S to verify image paste).\n'
