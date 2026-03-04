/**
 * Define global symbol 'tohost' for DTM/tracer (must be in ELF for read_symbol).
 * Actual store is done via write_tohost() in start.S to avoid HI20 relocation.
 */
	.section .tohost,"aw",@nobits
	.align 3
	.globl tohost
tohost:
	.space 8
