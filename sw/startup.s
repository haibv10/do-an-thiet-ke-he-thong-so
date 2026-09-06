.section .text
.global _start

_start:
    # 1. Khởi tạo con trỏ Stack Pointer (sp) trỏ tới đỉnh RAM (0x20000FFC - 4KB RAM)
    lui  sp, 0x20001
    addi sp, sp, -4

    # 2. Nhảy vào hàm main của C
    jal  ra, main

    # 3. Nếu main return thì lặp vô tận
halt:
    j halt
