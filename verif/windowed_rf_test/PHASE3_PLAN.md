# Phase 3: Context-switch integration and OS path (windowed RF)

Branch: `feature/windowed-regfile-phase3`  
Builds on: Phase 1 (64-entry windowed RF + CSRs 0x800/0x801) and Phase 2 (staged config, 0x802 apply, mret applies staged → active).

## Goal

Move toward running a real-time kernel (e.g. FreeRTOS) on CVA6 on FPGA, using the windowed register file to reduce context-switch latency. Phase 3 focuses on **software integration and validation** of window switching across context switches.

## Scope (Phase 3)

1. **Validate Phase 2 in sim**
   - Restore and run the full CSR/window test (`windowed_rf_csr_test.c`) in Verilator; confirm staged/active and 0x802 semantics via trace or pass criteria.
   - Fix or document any remaining SimDTM vs rvfi_tracer pass/fail discrepancy for custom ELFs.

2. **Context-switch contract**
   - Document the **ABI/contract** for the OS:
     - Which CSRs the kernel must save/restore (0x800, 0x801 as staged or active as needed).
     - When to write 0x802 (e.g. on return to user/task) or rely on mret to apply staged.
   - Optionally add a small **bare-metal multi-task test** that switches windows (e.g. two tasks, each with a dedicated window) and verifies correct register view.

3. **FreeRTOS path (later in Phase 3 or Phase 4)**
   - Port or configure a minimal FreeRTOS (or similar) for CVA6.
   - Integrate window save/restore into the context-switch path (e.g. in the trap handler or scheduler).
   - Run on FPGA with the windowed RF; measure or demonstrate reduced context-switch cost.

## Tangible outcomes

- [ ] Full Phase 2 CSR test passing (or clearly documented pass criteria via RVFI trace).
- [ ] Written context-switch / window ABI for the kernel.
- [ ] (Optional) Bare-metal multi-window task test passing in sim.
- [ ] (Later) FreeRTOS (or minimal RTOS) running on CVA6 with windowed RF on FPGA.

## Notes

- Keep Phase 3 changes in this branch until all bugs are resolved, then merge or open a follow-on branch for FPGA/FreeRTOS.
- Custom CSRs: 0x800 (staged/active base), 0x801 (staged/active size), 0x802 (apply staged → active). mret also applies staged → active.
