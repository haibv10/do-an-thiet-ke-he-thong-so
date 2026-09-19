.section .text
.global _start

_start:
    # 1. Point the stack pointer at the top of RAM (0x20000FFC, 4 KB region)
    lui  sp, 0x20001
    addi sp, sp, -4

    # 2. Jump into the C entry point
    jal  ra, main

    # 3. Spin forever if main ever returns
halt:
    j halt
