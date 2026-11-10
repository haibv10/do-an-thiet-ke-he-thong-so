#!/usr/bin/env python3
"""Report linked ROM/RAM usage from firmware.bin and firmware.symbols."""
import pathlib
import sys

build = pathlib.Path(sys.argv[1])
symbols = {}
for line in (build / "firmware.symbols").read_text().splitlines():
    fields = line.split()
    if len(fields) == 3:
        symbols[fields[2]] = int(fields[0], 16)
rom_size = (build / "firmware.bin").stat().st_size
rom_capacity = symbols["_rom_capacity"]
ram_capacity = symbols["_ram_capacity"]
data = symbols["_data_end"] - symbols["_data_start"]
bss = symbols["_bss_end"] - symbols["_bss_start"]
static_ram = symbols["_bss_end"] - (symbols["_stack_top"] - ram_capacity)
print(f"ROM image: {rom_size}/{rom_capacity} bytes; free {rom_capacity - rom_size}")
print(f"RAM static: {static_ram}/{ram_capacity} bytes (.data {data}, .bss {bss})")
print(f"RAM available for stack: {ram_capacity - static_ram} bytes")
