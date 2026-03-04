/**
 * Minimal test for windowed register file CSRs (Phase 1).
 * CSRs: 0x800 = window base, 0x801 = window size.
 * Reset values: base=0, size=32.
 *
 * Compile for 64-bit (default CVA6 target). Uses inline asm for CSR access.
 */

#define CSR_WINDOW_BASE  0x800
#define CSR_WINDOW_SIZE  0x801

static volatile unsigned long test_fail;

static inline unsigned long csr_read(unsigned int csr)
{
	unsigned long val;
	__asm__ volatile ("csrr %0, %1" : "=r"(val) : "i"(csr));
	return val;
}

static inline void csr_write(unsigned int csr, unsigned long val)
{
	__asm__ volatile ("csrw %0, %1" : : "i"(csr), "r"(val));
}

int main(void)
{
	unsigned long base, size;

	test_fail = 0;

	/* Check reset values: base=0, size=32 */
	base = csr_read(CSR_WINDOW_BASE);
	size = csr_read(CSR_WINDOW_SIZE);
	if (base != 0 || size != 32)
		test_fail = 1;

	/* Write and read back window base */
	csr_write(CSR_WINDOW_BASE, 32);
	base = csr_read(CSR_WINDOW_BASE);
	if (base != 32)
		test_fail = 2;

	/* Write and read back window size (e.g. 16) */
	csr_write(CSR_WINDOW_SIZE, 16);
	size = csr_read(CSR_WINDOW_SIZE);
	if (size != 16)
		test_fail = 3;

	/* Restore default window (base=0, size=32) */
	csr_write(CSR_WINDOW_BASE, 0);
	csr_write(CSR_WINDOW_SIZE, 32);
	base = csr_read(CSR_WINDOW_BASE);
	size = csr_read(CSR_WINDOW_SIZE);
	if (base != 0 || size != 32)
		test_fail = 4;

	/* Use a few GPRs so the windowed RF is exercised (window 0) */
	__asm__ volatile (
		"addi sp, sp, -16\n"
		"addi a0, zero, 1\n"
		"addi a1, zero, 2\n"
		"add  a2, a0, a1\n"
		"addi sp, sp, 16\n"
		: : : "a0", "a1", "a2"
	);

	/* If we get here without trap, and test_fail==0, CSRs and RF path are OK */
	while (1)
		__asm__ volatile ("nop");
}
