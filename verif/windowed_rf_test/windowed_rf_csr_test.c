/**
 * Minimal test for windowed register file CSRs (Phase 1 + Phase 2).
 * Phase 2: 0x800/0x801 write staged config; 0x802 apply staged -> active.
 * Entire test in one asm block so main() uses no stack (avoids B Response Errored).
 */

extern void write_tohost(unsigned long val);

__attribute__((naked))
int main(void)
{
	/* Full Phase 2 test: staged/active CSRs, 0x802 apply. Ends with j write_tohost. */
	__asm__ volatile (
		"addi a0, zero, 0\n"
		/* Check reset: 0x800==0, 0x801==32 */
		"csrr t0, 0x800\n"
		"csrr t1, 0x801\n"
		"bne t0, zero, 1f\n"
		"li   t2, 32\n"
		"bne  t1, t2, 1f\n"
		/* Staged base=32, apply, read, restore; check read==32 */
		"li   t0, 32\n"
		"csrw 0x800, t0\n"
		"csrw 0x802, t0\n"
		"csrr t1, 0x800\n"
		"li   t0, 0\n"
		"csrw 0x800, t0\n"
		"li   t0, 32\n"
		"csrw 0x801, t0\n"
		"csrw 0x802, t0\n"
		"li   t2, 32\n"
		"bne  t1, t2, 2f\n"
		/* Staged size=16, apply, read, restore; check read==16 */
		"li   t0, 16\n"
		"csrw 0x801, t0\n"
		"csrw 0x802, t0\n"
		"csrr t1, 0x801\n"
		"li   t0, 0\n"
		"csrw 0x800, t0\n"
		"li   t0, 32\n"
		"csrw 0x801, t0\n"
		"csrw 0x802, t0\n"
		"li   t2, 16\n"
		"bne  t1, t2, 3f\n"
		/* Final: active (0, 32) */
		"csrr t0, 0x800\n"
		"csrr t1, 0x801\n"
		"bne t0, zero, 4f\n"
		"li   t2, 32\n"
		"bne  t1, t2, 4f\n"
		"j    5f\n"
		"1: addi a0, zero, 1\n"
		"j    5f\n"
		"2: addi a0, zero, 2\n"
		"j    5f\n"
		"3: addi a0, zero, 3\n"
		"j    5f\n"
		"4: addi a0, zero, 4\n"
		"5: li   t0, 1\n"
		"li   t1, 3\n"
		"bne  a0, zero, 6f\n"
		"mv   a0, t0\n"
		"j    write_tohost\n"
		"6: mv  a0, t1\n"
		"j    write_tohost\n"
		: : : "t0", "t1", "t2", "a0"
	);
	__builtin_unreachable();
}
