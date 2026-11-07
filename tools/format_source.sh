#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_dir"

mode=${1:---write}
if [[ $# -gt 1 || ("$mode" != --write && "$mode" != --check) ]]; then
  echo "Usage: bash tools/format_source.sh [--write|--check]" >&2
  exit 2
fi

resolve_tool() {
  local tool=$1
  if command -v "$tool" >/dev/null 2>&1; then
    command -v "$tool"
  elif [[ "$tool" != */* && -x "$repo_dir/build/format-tools/bin/$tool" ]]; then
    printf '%s\n' "$repo_dir/build/format-tools/bin/$tool"
  else
    echo "$tool is required; see README.md for formatter setup" >&2
    return 1
  fi
}

verible=$(resolve_tool "${VERIBLE_FORMAT:-verible-verilog-format}")
clang_format=$(resolve_tool "${CLANG_FORMAT:-clang-format}")
shfmt=$(resolve_tool "${SHFMT:-shfmt}")

shopt -s globstar nullglob
rtl_files=(source/**/*.v tb/**/*.sv)
c_files=(sw/**/*.c sw/**/*.h)
shell_files=(tools/*.sh)

if [[ "$mode" == --check ]]; then
  status=0
  for file in "${rtl_files[@]}"; do
    "$verible" --flagfile="$repo_dir/.verible-format.flags" --verify "$file" || status=1
  done
  "$clang_format" --style=file --dry-run --Werror "${c_files[@]}" || status=1
  "$shfmt" -ln bash -i 2 -d "${shell_files[@]}" || status=1
  exit "$status"
fi

"$verible" --flagfile="$repo_dir/.verible-format.flags" --inplace "${rtl_files[@]}"
"$clang_format" --style=file -i "${c_files[@]}"
"$shfmt" -ln bash -i 2 -w "${shell_files[@]}"
