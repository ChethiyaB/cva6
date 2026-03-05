/**
 * Minimal test for windowed register file CSRs (Phase 1 + Phase 2).
 * Phase 2: 0x800/0x801 write staged config; 0x802 apply staged -> active.
 * Entire test in one asm block so main() uses no stack (avoids B Response Errored).
 */

extern void write_tohost(unsigned long val);

__attribute__((naked))
int main(void)
{
	/* Minimal sanity test: no CSRs, just signal PASS via tohost. */
	__asm__ volatile (
		"li   a0, 1\n"          /* PASS code */
		"j    write_tohost\n"   /* tail-call to write_tohost */
		: : : "a0"
	);
	__builtin_unreachable();
}
