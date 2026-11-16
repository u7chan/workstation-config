#!/usr/bin/env bash
set -euo pipefail

# ffmpeg/ffprobe are APT-managed through base_apt_packages. A manually
# installed mise conda:ffmpeg leaves a shim at ~/.local/share/mise/shims that
# comes first on PATH and shadows the APT build, and the shim fails with
# "No version is set" because config.toml does not declare ffmpeg.
# This test is read-only: it never transcodes or writes media files.

for tool in ffmpeg ffprobe; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    printf '%s is not installed.\n' "$tool" >&2
    exit 1
  fi
done

ffmpeg_path="$(command -v ffmpeg)"
case "$ffmpeg_path" in
  */.local/share/mise/shims/*)
    printf 'ffmpeg resolves to a mise shim (%s), not the APT build.\n' "$ffmpeg_path" >&2
    printf 'Remove the ad-hoc install, then re-check:\n' >&2
    printf '  mise uninstall conda:ffmpeg && mise reshim && hash -r && command -v ffmpeg\n' >&2
    exit 1
    ;;
esac

version="$(ffmpeg -hide_banner -version 2>/dev/null)"
version_line="${version%%$'\n'*}"
ffprobe -hide_banner -version >/dev/null

# The explain-video workflow re-encodes to H.264, so the build has to ship the
# libx264 encoder. Ubuntu's universe build enables it; a minimal build does not.
# Keep the producer and grep out of one pipeline: with pipefail, `grep -q`
# exits on the first match and ffmpeg dies with SIGPIPE, failing the check.
encoders="$(ffmpeg -hide_banner -encoders 2>/dev/null)"
if ! grep -q '^ V.* libx264' <<<"$encoders"; then
  printf 'ffmpeg build does not provide the libx264 encoder.\n' >&2
  exit 1
fi

printf 'ffmpeg smoke checks passed (%s, libx264 available).\n' "$version_line"
