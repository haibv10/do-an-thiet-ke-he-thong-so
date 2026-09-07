#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
gowin_root=${GOWIN_ROOT:-}
bitstream="$repo_dir/impl/pnr/fpga_project.fs"

if [[ -z "$gowin_root" ]]; then
  echo "GOWIN_ROOT must point to the extracted Gowin installation" >&2
  exit 1
fi

programmer_bin="$gowin_root/Programmer/bin/programmer_cli"

if [[ ! -x "$programmer_bin" ]]; then
  echo "programmer_cli not found at $programmer_bin" >&2
  exit 1
fi

if [[ ! -f "$bitstream" ]]; then
  echo "bitstream not found; run bash build_fpga.sh first" >&2
  exit 1
fi

exec "$programmer_bin" \
  --device GW1NR-9C \
  --run 2 \
  --fsFile "$bitstream" \
  --cable-index 1 \
  --channel 0
