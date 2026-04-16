# CVA6 Partitioned Register File Implementation

## Overview
This implementation adds hardware support for partitioned register files in the CVA6 core, enabling lightweight task switching without heavy context save/restore overhead. The design is based on modifications made to the Spike RISC-V ISA simulator.

## Key Features
1. **Hardware Window Management**: Register file accessed through configurable windows (base offset + size)
2. **Automatic Context Switching**: On trap entry, current window is saved and kernel window is activated
3. **Automatic Context Restore**: On mret, saved window configuration is restored
4. **Security Boundaries**: Out-of-bounds accesses return 0 or are dropped

## Modified Files

### 1. `/workspace/core/csr_regfile.sv`
Added two new CSRs and automatic window management logic:

#### New Registers (lines 272-273):
- `window_config_q/d` (CSR 0x800): Active window configuration [31:16=size, 15:0=base]
- `prev_window_config_q/d` (CSR 0x801): Saved window for context switch

#### CSR Read Logic (lines 634-636):
```systemverilog
12'h800: csr_rdata = window_config_q;  // Active window configuration
12'h801: csr_rdata = prev_window_config_q;  // Saved window configuration
```

#### CSR Write Logic (lines 1702-1708):
```systemverilog
12'h800: begin  // Active window configuration - sets base and size
  window_config_d = csr_wdata;
end
12'h801: begin  // Previous window configuration - saved context for task switch
  prev_window_config_d = csr_wdata;
end
```

#### Trap Entry - Auto Save Window (lines 2023-2032):
```systemverilog
if (ex_i.valid && !debug_mode_q) begin
  // Save current window configuration to prev_window_config (CSR 0x801)
  prev_window_config_d = window_config_q;
  // Force kernel mode window (base=0, size=32) for trap handler
  window_config_d = {32'h0020_0000};  // size=32, base=0
end
```

#### mret - Auto Restore Window (lines 2333-2337):
```systemverilog
// PARTITIONED REGISTER FILE: Auto-restore window on mret
window_config_d = prev_window_config_q;  // Restore saved window
```

#### Reset Values (lines 2813-2815):
```systemverilog
window_config_q      <= {32'h0020_0000};  // size=32, base=0 (full register file)
prev_window_config_q <= '0;
```

#### Sequential Update (lines 2914-2916):
```systemverilog
window_config_q      <= window_config_d;
prev_window_config_q <= prev_window_config_d;
```

### 2. `/workspace/core/ariane_regfile_ff.sv`
Modified to support partitioned access with window-based address translation:

#### New Parameter:
```systemverilog
parameter int unsigned PHYSICAL_REGS = 64  // Total physical registers
```

#### New Input:
```systemverilog
input  logic [CVA6Cfg.XLEN-1:0]  window_config_i,  // [31:16]=size, [15:0]=base_offset
```

#### Address Translation Logic:
```systemverilog
assign window_base = window_config_i[15:0];
assign window_size = window_config_i[31:16];

// Translate logical to physical with bounds checking
if (raddr_i[i] < window_size) begin
  phys_raddr[i] = window_base + raddr_i[i];
end else begin
  phys_raddr[i] = '0;  // Out of bounds
end
```

#### Security Features:
- Writes outside window boundaries are dropped
- Reads outside window boundaries return 0
- x0 (register 0) always returns 0

## Usage

### Software Interface
```c
// Read current window configuration
uint32_t win_config = csr_read(0x800);

// Set window: base=32, size=32 (second partition)
csr_write(0x800, (32 << 16) | 32);

// Save current window for later restore
uint32_t saved_win = csr_read(0x801);
csr_write(0x801, saved_win);
```

### Hardware Behavior
1. **Normal Execution**: Tasks operate within their assigned window
2. **Trap/Exception**: 
   - Current window auto-saved to CSR 0x801
   - Window forced to kernel mode (base=0, size=32)
   - Handler executes with kernel registers
3. **mret**:
   - Saved window auto-restored from CSR 0x801
   - Task resumes with its original register view

## Benefits
- **Zero-overhead context switches** for trap entry/exit
- **Hardware isolation** between tasks
- **No software save/restore** of general-purpose registers
- **Backward compatible** - defaults to full register file access

## Configuration
Default configuration provides 64 physical registers partitionable into:
- 2 windows of 32 registers each, or
- Variable sizes as needed (e.g., 16+48, 24+40, etc.)

The window size can be adjusted via CSR 0x800 to match application requirements.
