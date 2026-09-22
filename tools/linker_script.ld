/* Memory map seen by the CPU. Region 0x0 is the instruction ROM, which the
 * address decoder also exposes read-only on the data bus, and region 0x2 is
 * the on-chip RAM. See README.md for the peripheral memory map. */
MEMORY
{
    ROM (rx)  : ORIGIN = 0x00000000, LENGTH = 8K
    RAM (rwx) : ORIGIN = 0x20000000, LENGTH = 4K
}

/* The stack is full-descending and starts one word past the end of RAM, so the
 * first push lands on the last word. */
_stack_top = ORIGIN(RAM) + LENGTH(RAM);

SECTIONS
{
    .text : {
        *(.text._start)
        *(.text*)
        *(.rodata*)
        . = ALIGN(4);
    } > ROM

    /* .data runs from RAM but is stored in ROM; startup.s copies it across
     * using the symbols below. */
    .data : {
        . = ALIGN(4);
        _data_start = .;
        *(.data*)
        *(.sdata*)
        . = ALIGN(4);
        _data_end = .;
    } > RAM AT > ROM
    _data_lma = LOADADDR(.data);

    .bss (NOLOAD) : {
        . = ALIGN(4);
        _bss_start = .;
        *(.bss*)
        *(.sbss*)
        *(COMMON)
        . = ALIGN(4);
        _bss_end = .;
    } > RAM
}
