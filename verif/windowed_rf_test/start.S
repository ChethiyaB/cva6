/**
 * Minimal startup for windowed RF CSR test (64-bit).
 * write_tohost(val): write to 0x80001000 (original, known-good tohost address).
 */

.section .text.start
.globl _start
_start:
	.option push
	.option norelax
	la    sp, __stack_top
	.option pop
	call  main
1:
	j     1b

.globl write_tohost
write_tohost:
	lui   t0, 0x80001
	sd    a0, 0(t0)
1:
	j     1b
