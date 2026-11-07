import sys

ROM_WORDS = 2048

def convert_bin_to_hex(bin_path, hex_path, rom_words=ROM_WORDS):
    with open(bin_path, "rb") as f:
        data = f.read()

    while len(data) % 4 != 0:
        data += b'\x00'

    words = len(data) // 4
    if words > rom_words:
        raise SystemExit(
            f"{bin_path} is {words} words, but the ROM holds {rom_words}. "
            "Shrink the firmware or grow the ROM in source/memory/mem_instruction_rom.v."
        )

    with open(hex_path, "w") as f:
        for i in range(0, len(data), 4):

            word = (data[i+3] << 24) | (data[i+2] << 16) | (data[i+1] << 8) | data[i]
            f.write(f"{word:08X}\n")

        for _ in range(words, rom_words):
            f.write("00000000\n")

if __name__ == "__main__":
    convert_bin_to_hex(sys.argv[1], sys.argv[2])
