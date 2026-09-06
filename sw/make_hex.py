import sys

def convert_elf_to_hex(bin_path, hex_path):
    with open(bin_path, "rb") as f:
        data = f.read()

    # Pad thêm cho đủ bội số 4 byte
    while len(data) % 4 != 0:
        data += b'\x00'

    with open(hex_path, "w") as f:
        for i in range(0, len(data), 4):
            # RISC-V là Little-Endian: ghép 4 byte thành word 32-bit
            word = (data[i+3] << 24) | (data[i+2] << 16) | (data[i+1] << 8) | data[i]
            f.write(f"{word:08X}\n")

if __name__ == "__main__":
    convert_elf_to_hex(sys.argv[1], sys.argv[2])
