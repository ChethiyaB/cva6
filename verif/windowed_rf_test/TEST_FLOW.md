# Test flow for windowed register file (Phase 1) on Linux

Use this flow on a Linux machine to build the CVA6 RTL (with windowed RF), run the simulation, and verify behavior.

## Prerequisites

1. **RISC-V toolchain**  
   Set `RISCV` to your toolchain install (e.g. `/opt/riscv` or `$HOME/riscv`).  
   For the default 64-bit target you need `riscv64-unknown-elf-gcc` (and binutils) in `$RISCV/bin`.

2. **Verilator** (4.x or 5.x)  
   Install from your distro or from https://github.com/verilator/verilator.  
   Ensure `verilator` and `verilator-vlt` are on `PATH`.

3. **Standard build tools**  
   `make`, `g++`, `autoconf`, `git`.

## 1. Set environment and go to repo root

```bash
export RISCV=/path/to/your/riscv/toolchain
export CVA6_REPO_DIR=/path/to/cva6   # optional; Makefile sets it if unset
cd $CVA6_REPO_DIR
git checkout feature/windowed-regfile-phase1   # or your Phase 1 branch
```

## 2. Build RISC-V tests (required for simulation ELF)

This populates `tmp/riscv-tests/build/` with ISA tests and benchmarks (e.g. dhrystone).

```bash
ci/build-riscv-tests.sh
```

If the script fails, ensure `$RISCV/bin` is in `PATH` and that `riscv-tests` builds for the same XLEN as your CVA6 target (default target is 64-bit).

## 3. Build the Verilator model (CVA6 + windowed RF)

From repo root:

```bash
make verilate
```

This compiles the RTL (including windowed regfile and CSRs 0x800/0x801) into the executable `work-ver/Variane_testharness`.  
To use a 32-bit CVA6 target instead:

```bash
make verilate target=cv32a6_imac_sv32
```

## 4. Run simulation

### 4.1 Default run (Dhrystone benchmark)

```bash
make sim-verilator
```

This runs `work-ver/Variane_testharness` with the default ELF  
`tmp/riscv-tests/build/benchmarks/dhrystone.riscv`.  
Success: simulation runs to completion without assertion failures.

### 4.2 Run a single ISA test

```bash
make sim-verilator elf_file=tmp/riscv-tests/build/isa/rv64ui-p-add
```

Or use the Verilator asm-test target (same ELF):

```bash
make rv64ui-p-add-verilator
```

### 4.3 Run all ISA tests (Verilator)

```bash
make run-asm-tests-verilator
```

Then check results:

```bash
make check-asm-tests
```

### 4.4 Run the custom windowed-RF test

Build the minimal CSR test (see below), then run with the test ELF. The tracer needs the tohost address; if it cannot read it from the ELF, pass it explicitly:

```bash
make sim-verilator elf_file=$CVA6_REPO_DIR/verif/windowed_rf_test/build/windowed_rf_csr_test.riscv \
  SIM_ARGS="+tohost_addr=0x80001000"
```

Or from the test directory:

```bash
cd verif/windowed_rf_test
make
cd ../..
make sim-verilator elf_file=$(pwd)/verif/windowed_rf_test/build/windowed_rf_csr_test.riscv \
  SIM_ARGS="+tohost_addr=0x80001000"
```

If you see `tohost_addr: 0000000000000000` and the run hits the cycle limit, use `SIM_ARGS="+tohost_addr=0x80001000"` so the tracer and DTM use the correct tohost address (0x80001000) and the test can finish with pass/fail.

## 5. Optional: increase simulation timeout

If a test runs long, you can raise the cycle limit (example: 20M cycles):

```bash
make sim-verilator max_cycles=20000000 elf_file=...
```

(Only if your Makefile supports `max_cycles` for the Verilator run; otherwise set the same in the testbench plusarg if available.)

## 6. Clean and rebuild

- Regenerate Verilator model after RTL changes:
  ```bash
  make verilate
  ```
- Clean Verilator build:
  ```bash
  rm -rf work-ver
  make verilate
  ```
- Clean test build:
  ```bash
  rm -rf verif/windowed_rf_test/build
  ```

## Quick reference: minimal flow

```bash
export RISCV=/path/to/riscv
cd /path/to/cva6
ci/build-riscv-tests.sh
make verilate
make sim-verilator
make rv64ui-p-add-verilator
make run-asm-tests-verilator && make check-asm-tests
```

## Custom windowed-RF CSR test

The directory `verif/windowed_rf_test/` contains a minimal test that:

- Reads CSR 0x800 (window base) and 0x801 (window size) and checks reset values (0 and 32).
- Writes new values and reads them back.
- Does a few GPR operations so the windowed RF is used.

Build it from repo root after `RISCV` is set:

```bash
cd verif/windowed_rf_test && make && cd ../..
```

Then run with `elf_file` and `SIM_ARGS="+tohost_addr=0x80001000"` as in 4.4 above. That tells the tracer where the test writes the exit status so the run can finish with pass/fail instead of timing out. Passing the CSR read/write checks indicates the window CSRs are working.
**32-bit target:** If you use `target=cv32a6_imac_sv32`, build with `make ELF32=1` in this directory, then run with `elf_file=.../build/windowed_rf_csr_test_32.riscv`.
