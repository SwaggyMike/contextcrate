#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"

for required_command in git jq ssh-agent; do
  command -v "$required_command" >/dev/null \
    || { printf 'missing test dependency: %s\n' "$required_command" >&2; exit 1; }
done

bash scripts/build.sh --check
bash -n satchel
bash -n install.sh
bash -n scripts/build.sh
for source_file in src/[0-9][0-9]-*.sh; do
  bash -n "$source_file"
done
git diff --check
git diff --cached --check

for test_file in tests/test_*.sh; do
  printf 'RUN %s\n' "$test_file"
  bash "$test_file"
done
