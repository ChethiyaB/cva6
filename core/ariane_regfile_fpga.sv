// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright 2024 - PlanV Technologies for additional contribution.
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
//                 Noam Gallmann - gnoam@live.com
//                 Felipe Lisboa Malaquias
//                 Henry Suzukawa
//                 Angela Gonzalez - PlanV Technologies
//
// Description:    This register file is optimized for implementation on
//                 FPGAs. The register file features one distributed RAM block per implemented
//                 sync-write port, each with a parametrized number of async-read ports.
//                 Read-accesses are multiplexed from the relevant block depending on which block
//                 was last written to. For that purpose an additional array of registers is
//                 maintained keeping track of write accesses.
//

module ariane_regfile_fpga #(
    parameter config_pkg::cva6_cfg_t CVA6Cfg       = config_pkg::cva6_cfg_empty,
    parameter int unsigned           DATA_WIDTH    = 32,
    parameter int unsigned           NR_READ_PORTS = 2,
    parameter bit                    ZERO_REG_ZERO = 0
) (
    input  logic                                     clk_i,
    input  logic                                     rst_ni,
    input  logic                                     test_en_i,
    // [STANDARD] Read port (Logical Address from Decoder is 5 bits)
    input  logic [        NR_READ_PORTS-1:0][    4:0] raddr_i,
    output logic [        NR_READ_PORTS-1:0][DATA_WIDTH-1:0] rdata_o,
    // [STANDARD] Write port (Logical Address from Decoder is 5 bits)
    input  logic [CVA6Cfg.NrCommitPorts-1:0][    4:0] waddr_i,
    input  logic [CVA6Cfg.NrCommitPorts-1:0][DATA_WIDTH-1:0] wdata_i,
    input  logic [CVA6Cfg.NrCommitPorts-1:0]                 we_i,

    // [MODIFIED] Window control (Explicitly 6 bits for Physical Addressing)
    input  logic [5:0] rf_window_base_i,
    input  logic [5:0] rf_window_size_i
);

  // [MODIFIED] Decouple Logical (5-bit) from Physical (6-bit)
  localparam PHYS_ADDR_WIDTH = 6;
  localparam NUM_WORDS = 2 ** PHYS_ADDR_WIDTH;
  localparam LOG_NR_WRITE_PORTS = CVA6Cfg.NrCommitPorts == 1 ? 1 : $clog2(CVA6Cfg.NrCommitPorts);

  // Distributed RAM is now 64 blocks deep
  logic [NUM_WORDS-1:0][DATA_WIDTH-1:0] mem[CVA6Cfg.NrCommitPorts];

  logic [CVA6Cfg.NrCommitPorts-1:0][NUM_WORDS-1:0] we_dec;
  logic [NUM_WORDS-1:0][LOG_NR_WRITE_PORTS-1:0] mem_block_sel;
  logic [NUM_WORDS-1:0][LOG_NR_WRITE_PORTS-1:0] mem_block_sel_q;
  logic [CVA6Cfg.NrCommitPorts-1:0][DATA_WIDTH-1:0] wdata_reg;
  logic [NR_READ_PORTS-1:0] read_after_write;

  // [MODIFIED] Expanded address buses for physical routing (6 bits)
  logic [NR_READ_PORTS-1:0][PHYS_ADDR_WIDTH-1:0] raddr_q;
  logic [NR_READ_PORTS-1:0][PHYS_ADDR_WIDTH-1:0] raddr;

  // [MODIFIED] Added buses to track the logical address for the read boundary check
  logic [NR_READ_PORTS-1:0][4:0] laddr_q;
  logic [NR_READ_PORTS-1:0][4:0] laddr;

  // [MODIFIED] Physical Address and Write Enable Signals
  logic [NR_READ_PORTS-1:0][PHYS_ADDR_WIDTH-1:0] phys_raddr_i;
  logic [CVA6Cfg.NrCommitPorts-1:0][PHYS_ADDR_WIDTH-1:0] phys_waddr_i;
  logic [CVA6Cfg.NrCommitPorts-1:0] we_actual;

  // [MODIFIED] Address Translation and Write Boundary Check
  always_comb begin
    for (int k = 0; k < NR_READ_PORTS; k++) begin
      phys_raddr_i[k] = (raddr_i[k] == 5'b0) ? '0 : ({1'b0, raddr_i[k]} + rf_window_base_i);
    end

    for (int j = 0; j < CVA6Cfg.NrCommitPorts; j++) begin
      phys_waddr_i[j] = (waddr_i[j] == 5'b0) ? '0 : ({1'b0, waddr_i[j]} + rf_window_base_i);
      we_actual[j] = we_i[j] && ({1'b0, waddr_i[j]} < rf_window_size_i) && (waddr_i[j] != 5'b0);
    end
  end

  always_comb begin
    for (int unsigned j = 0; j < CVA6Cfg.NrCommitPorts; j++) begin
      for (int unsigned i = 0; i < NUM_WORDS; i++) begin
        if (phys_waddr_i[j] == i) begin
          we_dec[j][i] = we_actual[j];
        end else begin
          we_dec[j][i] = 1'b0;
        end
      end
    end
  end

  always_comb begin
    mem_block_sel = mem_block_sel_q;
    for (int i = 0; i < NUM_WORDS; i++) begin
      for (int j = 0; j < CVA6Cfg.NrCommitPorts; j++) begin
        if (we_dec[j][i] == 1'b1) begin
          mem_block_sel[i] = LOG_NR_WRITE_PORTS'(j);
        end
      end
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      mem_block_sel_q <= '0;
      raddr_q <= '0;
      laddr_q <= '0;
    end else begin
      mem_block_sel_q <= mem_block_sel;
      if (CVA6Cfg.FpgaAlteraEn) begin
        raddr_q <= phys_raddr_i;
        laddr_q <= raddr_i;
      end else begin
        raddr_q <= '0;
        laddr_q <= '0;
      end
    end
  end

  logic [NR_READ_PORTS-1:0][DATA_WIDTH-1:0] mem_read[CVA6Cfg.NrCommitPorts];
  logic [NR_READ_PORTS-1:0][DATA_WIDTH-1:0] mem_read_sync[CVA6Cfg.NrCommitPorts];
  for (genvar j = 0; j < CVA6Cfg.NrCommitPorts; j++) begin : regfile_ram_block
    always_ff @(posedge clk_i) begin
      if (we_actual[j]) begin
        mem[j][phys_waddr_i[j]] <= wdata_i[j];
        if (CVA6Cfg.FpgaAlteraEn)
          wdata_reg[j] <= wdata_i[j];
        else wdata_reg[j] <= '0;
      end

      if (CVA6Cfg.FpgaAlteraEn) begin
        for (int k = 0; k < NR_READ_PORTS; k++) begin : block_read
          mem_read_sync[j][k] = mem[j][phys_raddr_i[k]];
          read_after_write[k] <= '0;
          if (phys_waddr_i[j] == phys_raddr_i[k])
            read_after_write[k] <= we_actual[j];
        end
      end
    end
    for (genvar k = 0; k < NR_READ_PORTS; k++) begin : block_read
      assign mem_read[j][k] = CVA6Cfg.FpgaAlteraEn ? ( read_after_write[k] ? wdata_reg[j]: mem_read_sync[j][k]) : mem[j][phys_raddr_i[k]];
    end
  end

  assign raddr = CVA6Cfg.FpgaAlteraEn ? raddr_q : phys_raddr_i;
  assign laddr = CVA6Cfg.FpgaAlteraEn ? laddr_q : raddr_i;

  logic [NR_READ_PORTS-1:0][LOG_NR_WRITE_PORTS-1:0] block_addr;
  for (genvar k = 0; k < NR_READ_PORTS; k++) begin : regfile_read_port
    assign block_addr[k] = mem_block_sel_q[raddr[k]];

    assign rdata_o[k] = ((ZERO_REG_ZERO && laddr[k] == '0) || ({1'b0, laddr[k]} >= rf_window_size_i)) ? '0 : mem_read[block_addr[k]][k];
  end

  initial begin
    for (int i = 0; i < CVA6Cfg.NrCommitPorts; i++) begin
      for (int j = 0; j < NUM_WORDS; j++) begin
        if (!CVA6Cfg.FpgaAlteraEn)
          mem[i][j] = $random();
        else mem[i][j] = '0;
      end
    end
  end

endmodule
