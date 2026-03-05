/**
 * Minimal linker script for windowed RF test (64-bit).
 * Matches CVA6 testbench: program at 0x80000000 (only that segment is loaded).
 * Run with +boot_addr=0x80000000 so the core boots here instead of ROM.
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
	/* Host <-> target channel, match riscv-tests layout. */
	.tohost  0x80001000 : { *(.tohost) *(.fromhost) } > ram
	_end = .;
}
