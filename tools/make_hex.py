"""Convert a flat RISC-V binary into the $readmemh image that src/imem.v loads.

The output is padded to the full depth of the ROM. That keeps every word of the
image defined, so an address past the end of the program reads as zero rather
than x in simulation, and it makes the synthesised BSRAM contents deterministic.
"""
import sys

# Must match the ROM depth in src/imem.v.
ROM_WORDS = 1024


def convert_bin_to_hex(bin_path, hex_path, rom_words=ROM_WORDS):
    with open(bin_path, "rb") as f:
        data = f.read()

    # Pad up to a multiple of 4 bytes
    while len(data) % 4 != 0:
        data += b'\x00'

    words = len(data) // 4
    if words > rom_words:
        raise SystemExit(
            f"{bin_path} is {words} words, but the ROM holds {rom_words}. "
            "Shrink the firmware or grow the ROM in src/imem.v."
        )

    with open(hex_path, "w") as f:
        for i in range(0, len(data), 4):
            # RISC-V is little-endian: pack 4 bytes into one 32-bit word
            word = (data[i+3] << 24) | (data[i+2] << 16) | (data[i+1] << 8) | data[i]
            f.write(f"{word:08X}\n")
        # Pad the remainder of the ROM with zeros
        for _ in range(words, rom_words):
            f.write("00000000\n")


if __name__ == "__main__":
    convert_bin_to_hex(sys.argv[1], sys.argv[2])
