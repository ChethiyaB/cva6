/**
 * Minimal linker script for windowed RF test (64-bit).
 * Matches typical CVA6 testbench: RAM at 0x80000000.
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
	/* fesvr/DTM/tracer read_symbol("tohost") - must be at 0x80001000 */
	.tohost 0x80001000 (NOLOAD) : { *(.tohost) } > ram
	_end = .;
}
