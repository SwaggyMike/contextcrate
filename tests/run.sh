#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"

bash -n satchel
bash -n install.sh
git diff --check
git diff --cached --check

for test_file in tests/test_*.sh; do
  printf 'RUN %s\n' "$test_file"
  bash "$test_file"
done
