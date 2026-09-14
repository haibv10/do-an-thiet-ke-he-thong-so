#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
build_dir="$repo_dir/build/gowin"
gowin_root=${GOWIN_ROOT:-}
system_libstdcpp=${SYSTEM_LIBSTDCXX:-/usr/lib/x86_64-linux-gnu/libstdc++.so.6}

if [[ -z "$gowin_root" ]]; then
  echo "GOWIN_ROOT must point to the extracted Gowin installation" >&2
  exit 1
fi

gw_sh_bin="$gowin_root/IDE/bin/gw_sh"
gowin_lib_dir="$gowin_root/IDE/lib"

if [[ ! -x "$gw_sh_bin" ]]; then
  echo "gw_sh not found at $gw_sh_bin" >&2
  exit 1
fi

if [[ ! -f "$system_libstdcpp" ]]; then
  echo "system libstdc++ not found at $system_libstdcpp" >&2
  exit 1
fi

mkdir -p "$build_dir"
ln -sfn "$repo_dir/src" "$build_dir/src"
cd "$build_dir"

exec env -u DISPLAY \
  QT_QPA_PLATFORM=offscreen \
  QT_OPENGL=software \
  QT_QUICK_BACKEND=software \
  LIBGL_ALWAYS_SOFTWARE=1 \
  LD_LIBRARY_PATH="$gowin_lib_dir${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
  LD_PRELOAD="$system_libstdcpp${LD_PRELOAD:+:$LD_PRELOAD}" \
  "$gw_sh_bin" "$repo_dir/tools/build_gowin.tcl"
