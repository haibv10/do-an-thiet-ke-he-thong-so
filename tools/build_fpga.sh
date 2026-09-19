#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
build_dir="$repo_dir/build/gowin"
gowin_root=${GOWIN_ROOT:-}
system_libstdcpp=${SYSTEM_LIBSTDCXX:-/usr/lib/x86_64-linux-gnu/libstdc++.so.6}
system_libfreetype=${SYSTEM_FREETYPE:-/lib/x86_64-linux-gnu/libfreetype.so.6}

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

if [[ ! -f "$system_libfreetype" ]]; then
  echo "system libfreetype not found at $system_libfreetype" >&2
  exit 1
fi

mkdir -p "$build_dir"
# mem_instruction_rom.v reads $readmemh("sw/firmware.hex") relative to the synthesis working directory
ln -sfn "$repo_dir/sw" "$build_dir/sw"
cd "$build_dir"

exec env -u DISPLAY \
  QT_QPA_PLATFORM=offscreen \
  QT_OPENGL=software \
  QT_QUICK_BACKEND=software \
  LIBGL_ALWAYS_SOFTWARE=1 \
  LD_LIBRARY_PATH="$gowin_lib_dir${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
  LD_PRELOAD="$system_libstdcpp:$system_libfreetype${LD_PRELOAD:+:$LD_PRELOAD}" \
  "$gw_sh_bin" "$repo_dir/tools/build_gowin.tcl"
