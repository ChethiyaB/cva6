/**
 * Startup for windowed RF full CSR test (64-bit).
 * _start sets sp, calls main; main tail-calls write_tohost(1/3).
 * write_tohost(val): store val to 0x80001000 then spin (no ret).
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
