#!/usr/bin/env bash
set -euo pipefail

if ! command -v psql >/dev/null 2>&1; then
  printf 'psql is not installed.\n' >&2
  exit 1
fi

psql --version >/dev/null

printf 'psql smoke checks passed.\n'
