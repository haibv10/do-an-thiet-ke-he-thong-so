# Reset vector. The linker places this section at address 0, so it is the first
# thing the CPU fetches out of reset.
    .section .text._start, "ax"
    .global _start

_start:
    # 1. Point the stack pointer one word past the end of RAM; the stack is
    #    full-descending, so the first push lands inside RAM.
    la   sp, _stack_top

    # 2. Copy .data from its load address in ROM to its run address in RAM,
    #    reading through the ROM window the address decoder exposes at region 0x0.
    la   t0, _data_lma
    la   t1, _data_start
    la   t2, _data_end
copy_data:
    bge  t1, t2, zero_bss
    lw   t3, 0(t0)
    sw   t3, 0(t1)
    addi t0, t0, 4
    addi t1, t1, 4
    j    copy_data

    # 3. Zero .bss, so uninitialised globals start at zero as C requires.
zero_bss:
    la   t1, _bss_start
    la   t2, _bss_end
zero_loop:
    bge  t1, t2, call_main
    sw   zero, 0(t1)
    addi t1, t1, 4
    j    zero_loop

call_main:
    jal  ra, main

    # There is nothing to return to, so trap the CPU rather than run off the end.
halt:
    j    halt
