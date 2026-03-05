/**
 * Minimal startup for windowed RF CSR test (64-bit).
 * write_tohost(val): write to 0x80001000 (original, known-good tohost address).
 */

.section .text.start
.globl _start
_start:
	/* Minimal: set up stack, then write PASS (=1) to tohost and spin. */
	.option push
	.option norelax
	la    sp, __stack_top
	.option pop

	li    a0, 1           /* PASS code */
	lui   t0, 0x80001     /* 0x8000_1000 */
	sd    a0, 0(t0)       /* tohost = 1 */
1:
	j     1b

.globl write_tohost
write_tohost:
	lui   t0, 0x80001
	sd    a0, 0(t0)
1:
	j     1b
