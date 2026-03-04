/**
 * Minimal startup for windowed RF CSR test (64-bit).
 * Sets stack and jumps to main.
 * write_tohost(val): write val to 0x80001000 (DTM tohost) using immediates to avoid HI20 relocation.
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
	ret
