import sys

def convert_bin_to_hex(bin_path, hex_path):
    with open(bin_path, "rb") as f:
        data = f.read()

    # Pad up to a multiple of 4 bytes
    while len(data) % 4 != 0:
        data += b'\x00'

    with open(hex_path, "w") as f:
        for i in range(0, len(data), 4):
            # RISC-V is little-endian: pack 4 bytes into one 32-bit word
            word = (data[i+3] << 24) | (data[i+2] << 16) | (data[i+1] << 8) | data[i]
            f.write(f"{word:08X}\n")

if __name__ == "__main__":
    convert_bin_to_hex(sys.argv[1], sys.argv[2])
