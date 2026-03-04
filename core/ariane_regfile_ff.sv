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
// Design Name:    RISC-V register file
// Project Name:   zero-riscy
// Language:       SystemVerilog
//
// Description:    Register file with 31 or 15x 32 bit wide registers.
//                 Register 0 is fixed to 0. This register file is based on
//                 flip flops.
//
// Windowed register file (Phase 1): Physical RF expanded to 64 entries; logical
// addresses (5-bit) are translated via rf_window_base_i; rf_window_size_i gates
// writes and forces out-of-window reads to zero. x0 always maps to physical 0.
//

module ariane_regfile #(
    parameter config_pkg::cva6_cfg_t CVA6Cfg       = config_pkg::cva6_cfg_empty,
    parameter int unsigned           DATA_WIDTH    = 32,
    parameter int unsigned           NR_READ_PORTS = 2,
    parameter bit                    ZERO_REG_ZERO = 0
) (
    // clock and reset
    input  logic                                             clk_i,
    input  logic                                             rst_ni,
    // disable clock gates for testing
    input  logic                                             test_en_i,
    // read port (logical address, 5-bit)
    input  logic [        NR_READ_PORTS-1:0][           4:0] raddr_i,
    output logic [        NR_READ_PORTS-1:0][DATA_WIDTH-1:0] rdata_o,
    // write port (logical address, 5-bit)
    input  logic [CVA6Cfg.NrCommitPorts-1:0][           4:0] waddr_i,
    input  logic [CVA6Cfg.NrCommitPorts-1:0][DATA_WIDTH-1:0] wdata_i,
    input  logic [CVA6Cfg.NrCommitPorts-1:0]                 we_i,
    // window control: base and size of active register window
    input  logic [5:0]                                       rf_window_base_i,
    input  logic [5:0]                                       rf_window_size_i
);

  localparam int unsigned PHYS_ADDR_WIDTH = 6;
  localparam int unsigned NUM_WORDS = 2 ** PHYS_ADDR_WIDTH;

  logic [NUM_WORDS-1:0][DATA_WIDTH-1:0] mem;
  logic [CVA6Cfg.NrCommitPorts-1:0][PHYS_ADDR_WIDTH-1:0] phys_waddr;
  logic [CVA6Cfg.NrCommitPorts-1:0][NUM_WORDS-1:0] we_dec;
  logic [CVA6Cfg.NrCommitPorts-1:0] we_actual;

  always_comb begin
    for (int j = 0; j < CVA6Cfg.NrCommitPorts; j++) begin
      phys_waddr[j] = (waddr_i[j] == 5'b0) ? 6'b0 : (6'(waddr_i[j]) + rf_window_base_i);
      we_actual[j] = we_i[j] && (6'(waddr_i[j]) < rf_window_size_i) && (waddr_i[j] != 5'b0);
    end
    for (int unsigned j = 0; j < CVA6Cfg.NrCommitPorts; j++) begin
      for (int unsigned i = 0; i < NUM_WORDS; i++) begin
        we_dec[j][i] = (phys_waddr[j] == i) ? we_actual[j] : 1'b0;
      end
    end
  end

  always_ff @(posedge clk_i, negedge rst_ni) begin : register_write_behavioral
    if (~rst_ni) begin
      mem <= '{default: '0};
    end else begin
      for (int unsigned j = 0; j < CVA6Cfg.NrCommitPorts; j++) begin
        for (int unsigned i = 0; i < NUM_WORDS; i++) begin
          if (we_dec[j][i]) begin
            mem[i] <= wdata_i[j];
          end
        end
      end
      if (ZERO_REG_ZERO) begin
        mem[0] <= '0;
      end
    end
  end

  logic [NR_READ_PORTS-1:0][PHYS_ADDR_WIDTH-1:0] phys_raddr;
  always_comb begin
    for (int k = 0; k < NR_READ_PORTS; k++) begin
      phys_raddr[k] = (raddr_i[k] == 5'b0) ? 6'b0 : (6'(raddr_i[k]) + rf_window_base_i);
    end
  end

  for (genvar k = 0; k < NR_READ_PORTS; k++) begin : gen_read_port
    assign rdata_o[k] = ((ZERO_REG_ZERO && raddr_i[k] == 5'b0) || (6'(raddr_i[k]) >= rf_window_size_i))
      ? '0
      : mem[phys_raddr[k]];
  end

endmodule
