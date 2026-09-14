#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
sw_dir="$repo_dir/sw"
build_dir="$repo_dir/build/firmware"
tool_prefix=${RISCV_TOOL_PREFIX:-riscv64-unknown-elf}

gcc_bin="$tool_prefix-gcc"
objcopy_bin="$tool_prefix-objcopy"
objdump_bin="$tool_prefix-objdump"

for tool in "$gcc_bin" "$objcopy_bin" "$objdump_bin"; do
  command -v "$tool" >/dev/null || {
    echo "$tool is required" >&2
    exit 1
  }
done

mkdir -p "$build_dir"
cd "$build_dir"

"$gcc_bin" \
  -march=rv32i \
  -mabi=ilp32 \
  -nostdlib \
  -O1 \
  -T "$sw_dir/linker.ld" \
  -Wl,-Map=firmware.map \
  "$sw_dir/startup.s" "$sw_dir/main.c" \
  -o firmware.elf

"$objcopy_bin" -O binary firmware.elf firmware.bin
"$objdump_bin" -d firmware.elf > firmware.asm
python3 "$repo_dir/tools/make_hex.py" firmware.bin firmware.hex
cp firmware.hex "$sw_dir/firmware.hex"
cp firmware.hex "$repo_dir/src/firmware.hex"
