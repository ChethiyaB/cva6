/**
 * Minimal linker script for windowed RF test (32-bit).
 * RAM at 0x80000000 for CVA6 testbench.
 */

OUTPUT_ARCH(riscv)
ENTRY(_start)

MEMORY
{
	ram (rwx) : ORIGIN = 0x80000000, LENGTH = 0x400000
}

__stack_top = ORIGIN(ram) + LENGTH(ram);

SECTIONS
{
	.text : {
		*(.text.start)
		*(.text .text.*)
	} > ram
	.data : { *(.data .data.*) } > ram
	.bss  : { *(.bss .bss.*) } > ram
	_end = .;
}
