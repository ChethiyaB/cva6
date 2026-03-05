/**
 * Define global symbols 'tohost' and 'fromhost' for DTM/tracer.
 * Match riscv-tests convention: writable PROGBITS objects, 8 bytes each.
 * Actual store to 'tohost' is still done via write_tohost() in start.S.
 */
	.section .tohost,"aw",@progbits
	.align 3
	.globl tohost
tohost:
	.dword 0

	.section .fromhost,"aw",@progbits
	.align 3
	.globl fromhost
fromhost:
	.dword 0
