#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
output="$repo_dir/satchel"
mode="${1:-build}"

case "$mode" in
  build|--check) ;;
  *)
    printf 'usage: %s [--check]\n' "${0##*/}" >&2
    exit 2
    ;;
esac

build_tmp="$(mktemp "$repo_dir/.satchel-build.XXXXXX")"
cleanup() { rm -f -- "$build_tmp"; }
trap cleanup EXIT

source_files=("$repo_dir"/src/[0-9][0-9]-*.sh)
[ -e "${source_files[0]}" ] || {
  printf 'no Satchel source modules found under %s/src\n' "$repo_dir" >&2
  exit 1
}

for source_file in "${source_files[@]}"; do
  command cat "$source_file" >> "$build_tmp"
done

bash -n "$build_tmp"

if [ "$mode" = --check ]; then
  if ! cmp -s "$output" "$build_tmp"; then
    printf 'satchel is out of date; run: bash scripts/build.sh\n' >&2
    exit 1
  fi
  exit 0
fi

chmod 755 "$build_tmp"
mv "$build_tmp" "$output"
trap - EXIT
