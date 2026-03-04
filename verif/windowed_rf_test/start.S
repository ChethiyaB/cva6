/**
 * Minimal startup for windowed RF CSR test (64-bit).
 * Sets stack and jumps to main. No exit; main loops forever.
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
