#!/usr/bin/env python3
"""Report linked memory use and a direct-call stack estimate from GCC artifacts."""
import pathlib
import re
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
print(f"RAM static: {static_ram}/{ram_capacity} bytes (.data {data}, .bss {bss}, including padding)")
print(f"RAM available for stack: {ram_capacity - static_ram} bytes")

frames = {}
for path in build.glob("*.su"):
    for line in path.read_text().splitlines():
        location, size, kind = line.split("\t")
        name = location.rsplit(":", 1)[-1]
        frames[name] = (int(size), kind)
        # GCC .su omits the numeric suffix on optimized clones.
        for symbol in symbols:
            if re.fullmatch(re.escape(name) + r"\.\d+", symbol):
                frames[symbol] = (int(size), kind)

calls = {}
current = None
unknown = set()
for line in (build / "firmware.asm").read_text().splitlines():
    header = re.match(r"^[0-9a-f]+ <([^>]+)>:", line)
    if header:
        current = header[1]
        calls.setdefault(current, set())
        continue
    if current is None:
        continue
    instruction = re.match(r"\s*[0-9a-f]+:\s+[0-9a-f]+\s+(\w+)\s*(.*)", line)
    if not instruction:
        continue
    op, operands = instruction.groups()
    if op in ("jalr", "jr"):
        unknown.add(current)
    if op in ("jal", "j"):
        target = re.search(r"<([^>]+)>", operands)
        if target and "+" not in target[1] and (target[1] != current or op == "jal"):
            calls[current].add(target[1])


def estimate(name, active):
    if name in active:
        raise ValueError(f"recursive call path at {name}")
    if name in unknown:
        raise ValueError(f"indirect call/jump in {name}")
    if name not in frames:
        raise ValueError(f"missing stack frame for {name}")
    size, kind = frames[name]
    if kind != "static":
        raise ValueError(f"non-static stack frame in {name}")
    descendants = [estimate(child, active | {name}) for child in calls.get(name, ())]
    return size + max(descendants, default=0)

try:
    stack = estimate("main", set())
    print(f"Conservative direct-call stack estimate from main: {stack} bytes")
    print(f"RAM margin after estimated stack: {ram_capacity - static_ram - stack} bytes")
except ValueError as error:
    print(f"Stack estimate unavailable: {error}")
print("Stack estimate sums GCC frames along linked direct calls, including tail calls.")
print("It is not a runtime high-water measurement; interrupts/indirect calls are not covered.")
