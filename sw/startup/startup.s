    .section .text._start, "ax"
    .global _start

_start:
    la   sp, _stack_top

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

halt:
    j    halt
