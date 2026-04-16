// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// Engineer:       Francesco Conti - f.conti@unibo.it
//
// Additional contributions by:
//                 Markus Wegmann - markus.wegmann@technokrat.ch
//
// Design Name:    RISC-V register file with partitioned windows
// Project Name:   CVA6 - Partitioned Register File for lightweight task switching
// Language:       SystemVerilog
//
// Description:    Register file with partitioned windows for task switching.
//                 Supports configurable base offset and window size.
//                 Register 0 is fixed to 0. Based on flip flops.

module ariane_regfile #(
    parameter config_pkg::cva6_cfg_t CVA6Cfg       = config_pkg::cva6_cfg_empty,
    parameter int unsigned           DATA_WIDTH    = 32,
    parameter int unsigned           NR_READ_PORTS = 2,
    parameter bit                    ZERO_REG_ZERO = 0,
    // Partitioned Register File Parameters
    parameter int unsigned           PHYSICAL_REGS = 64  // Total physical registers (e.g., 64 for 2 windows of 32)
) (
    // clock and reset
    input  logic                                             clk_i,
    input  logic                                             rst_ni,
    // disable clock gates for testing
    input  logic                                             test_en_i,
    // Partitioned Register File Control
    input  logic [CVA6Cfg.XLEN-1:0]                          window_config_i,  // [31:16]=size, [15:0]=base_offset
    // read port
    input  logic [        NR_READ_PORTS-1:0][           4:0] raddr_i,
    output logic [        NR_READ_PORTS-1:0][DATA_WIDTH-1:0] rdata_o,
    // write port
    input  logic [CVA6Cfg.NrCommitPorts-1:0][           4:0] waddr_i,
    input  logic [CVA6Cfg.NrCommitPorts-1:0][DATA_WIDTH-1:0] wdata_i,
    input  logic [CVA6Cfg.NrCommitPorts-1:0]                 we_i
);

  localparam ADDR_WIDTH = 5;
  localparam NUM_WORDS = 2 ** ADDR_WIDTH;
  localparam PHYS_ADDR_WIDTH = $clog2(PHYSICAL_REGS);

  logic [            PHYSICAL_REGS-1:0][DATA_WIDTH-1:0] mem;
  logic [CVA6Cfg.NrCommitPorts-1:0][ PHYSICAL_REGS-1:0] we_dec;
  logic [NR_READ_PORTS-1:0][PHYS_ADDR_WIDTH-1:0] phys_raddr;
  logic [CVA6Cfg.NrCommitPorts-1:0][PHYS_ADDR_WIDTH-1:0] phys_waddr;
  
  // Window configuration registers
  logic [15:0] window_base;
  logic [15:0] window_size;
  
  // Extract base and size from window_config_i
  assign window_base = window_config_i[15:0];
  assign window_size = window_config_i[31:16];
  
  // Translate logical addresses to physical addresses with bounds checking
  always_comb begin : address_translation
    for (int i = 0; i < NR_READ_PORTS; i++) begin
      // Check if logical address is within current window
      if (raddr_i[i] < window_size) begin
        phys_raddr[i] = window_base + raddr_i[i];
      end else begin
        // Out of bounds - return x0 value (0)
        phys_raddr[i] = '0;
      end
    end
    
    for (int j = 0; j < CVA6Cfg.NrCommitPorts; j++) begin
      // Check if logical address is within current window before writing
      if (waddr_i[j] < window_size) begin
        phys_waddr[j] = window_base + waddr_i[j];
      end else begin
        // Out of bounds - redirect to x0 (will be dropped by ZERO_REG_ZERO check)
        phys_waddr[j] = '0;
      end
    end
  end

  always_comb begin : we_decoder
    for (int unsigned j = 0; j < CVA6Cfg.NrCommitPorts; j++) begin
      for (int unsigned i = 0; i < PHYSICAL_REGS; i++) begin
        if (phys_waddr[j] == i) we_dec[j][i] = we_i[j];
        else we_dec[j][i] = 1'b0;
      end
    end
  end

  // loop from 1 to PHYSICAL_REGS-1 as R0 is nil
  always_ff @(posedge clk_i, negedge rst_ni) begin : register_write_behavioral
    if (~rst_ni) begin
      mem <= '{default: '0};
    end else begin
      for (int unsigned j = 0; j < CVA6Cfg.NrCommitPorts; j++) begin
        for (int unsigned i = 0; i < PHYSICAL_REGS; i++) begin
          if (we_dec[j][i]) begin
            // Prevent writes to x0 (physical address 0 when ZERO_REG_ZERO)
            if (!(ZERO_REG_ZERO && i == 0)) begin
              mem[i] <= wdata_i[j];
            end
          end
        end
      end
    end
  end

  for (genvar i = 0; i < NR_READ_PORTS; i++) begin
    // Return 0 for out-of-bounds reads or x0
    if (ZERO_REG_ZERO && raddr_i[i] == 0) begin
      assign rdata_o[i] = '0;
    end else if (raddr_i[i] >= window_size) begin
      assign rdata_o[i] = '0;  // Out of bounds returns 0
    end else begin
      assign rdata_o[i] = mem[phys_raddr[i]];
    end
  end

endmodule
