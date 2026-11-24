// AXI4-Lite peripheral: 8 scratch registers + LED / switch / timer / interrupt (spec: docs/peripheral_spec.md)
// - AW and W channels are accepted independently (any order)
// - Write response is issued only after both AW and W handshakes complete
// - Address outside 0x00~0x3C returns SLVERR (write is ignored, read returns 0)
// - Register kinds: RW (bus writes), RO (hardware writes, bus write ignored), W1C (hardware sets, bus writes 1 to clear)
// - Bug injection: compile with +define+BUG_B1 ... BUG_B5
module axi4lite_slave #(
  parameter int ADDR_W = 32,
  parameter int DATA_W = 32,
  parameter int NUM_REG = 16
)(
  input  logic                 aclk,
  input  logic                 aresetn,
  // AW
  input  logic [ADDR_W-1:0]    awaddr,
  input  logic [2:0]           awprot,
  input  logic                 awvalid,
  output logic                 awready,
  // W
  input  logic [DATA_W-1:0]    wdata,
  input  logic [DATA_W/8-1:0]  wstrb,
  input  logic                 wvalid,
  output logic                 wready,
  // B
  output logic [1:0]           bresp,
  output logic                 bvalid,
  input  logic                 bready,
  // AR
  input  logic [ADDR_W-1:0]    araddr,
  input  logic [2:0]           arprot,
  input  logic                 arvalid,
  output logic                 arready,
  // R
  output logic [DATA_W-1:0]    rdata,
  output logic [1:0]           rresp,
  output logic                 rvalid,
  input  logic                 rready,
  // Peripheral pins (Basys3: 16 LEDs, 16 slide switches)
  output logic [15:0]          led,
  input  logic [15:0]          sw,
  output logic                 irq
);

  localparam logic [1:0] RESP_OKAY   = 2'b00;
  localparam logic [1:0] RESP_SLVERR = 2'b10;
  localparam int IDX_W = $clog2(NUM_REG);

  // Register index map (address = index * 4)
  localparam int IDX_LED   = 8;   // 0x20 RW
  localparam int IDX_SW    = 9;   // 0x24 RO
  localparam int IDX_CTRL  = 10;  // 0x28 RW  [0] EN, [1] AUTO_RELOAD
  localparam int IDX_LOAD  = 11;  // 0x2C RW
  localparam int IDX_COUNT = 12;  // 0x30 RO
  localparam int IDX_STAT  = 13;  // 0x34 W1C [0] DONE
  localparam int IDX_IRQEN = 14;  // 0x38 RW  [0] enable
  localparam int IDX_RSVD  = 15;  // 0x3C read 0, write ignored

  logic [DATA_W-1:0] regs [NUM_REG];   // storage for the RW registers only
  logic [31:0]       tmr_count;        // TMR_COUNT (RO)
  logic              tmr_done;         // TMR_STATUS[0] (W1C)
  logic              tmr_en_q;         // EN delayed 1 cycle (to detect the start edge)
  logic [15:0]       sw_meta, sw_sync; // 2-FF synchronizer: switches are asynchronous to aclk

  // ---------------- Write path ----------------
  logic              aw_held, w_held;
  logic [ADDR_W-1:0] aw_addr_q;
  logic [DATA_W-1:0] w_data_q;
  logic [DATA_W/8-1:0] w_strb_q;

  assign awready = !aw_held && !bvalid;
  assign wready  = !w_held  && !bvalid;

  wire aw_hs = awvalid && awready;
  wire w_hs  = wvalid  && wready;

  wire              have_aw  = aw_held || aw_hs;
  wire              have_w   = w_held  || w_hs;
  wire [ADDR_W-1:0] wr_addr  = aw_held ? aw_addr_q : awaddr;
  wire [DATA_W-1:0] wr_data  = w_held  ? w_data_q  : wdata;
  wire [DATA_W/8-1:0] wr_strb = w_held ? w_strb_q  : wstrb;
  wire              do_write = have_aw && have_w && !bvalid;
  wire [IDX_W-1:0]  wr_idx   = wr_addr[IDX_W+1:2];

  function automatic logic addr_valid(input logic [ADDR_W-1:0] a);
    return (a[ADDR_W-1:IDX_W+2] == '0);
  endfunction

  // Which indexes are plain RW storage
  function automatic logic is_rw(input logic [IDX_W-1:0] i);
    return (i <= IDX_LED) || (i == IDX_CTRL) || (i == IDX_LOAD) || (i == IDX_IRQEN);
  endfunction

  wire tmr_en   = regs[IDX_CTRL][0];
  wire tmr_auto = regs[IDX_CTRL][1];
  wire tmr_start = tmr_en && !tmr_en_q;            // EN just went 0 -> 1
  wire tmr_hit  = tmr_en && tmr_en_q && (tmr_count == regs[IDX_LOAD]);

  always_ff @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
      aw_held   <= 1'b0;
      w_held    <= 1'b0;
      aw_addr_q <= '0;
      w_data_q  <= '0;
      w_strb_q  <= '0;
      bvalid    <= 1'b0;
      bresp     <= RESP_OKAY;
      for (int i = 0; i < NUM_REG; i++) regs[i] <= '0;
      tmr_count <= '0;
      tmr_done  <= 1'b0;
      tmr_en_q  <= 1'b0;
    end else begin
      tmr_en_q <= tmr_en;
      // ---- (1) Timer: hardware updates first, so a bus write in the same cycle wins ----
      if (!tmr_en)            ;                              // stopped: COUNT holds its value
      else if (tmr_start)     tmr_count <= '0;               // start: count from 0
      else if (tmr_hit) begin
        if (tmr_auto)         tmr_count <= '0;
        else                  regs[IDX_CTRL][0] <= 1'b0;   // one-shot: stop (count stays at LOAD)
      end else                tmr_count <= tmr_count + 1;

      // ---- (2) Bus write ----
      if (do_write) begin
        aw_held <= 1'b0;
        w_held  <= 1'b0;
        bvalid  <= 1'b1;
`ifdef BUG_B4
        bresp   <= RESP_OKAY;                         // B4: invalid address answered with OKAY
`else
        bresp   <= addr_valid(wr_addr) ? RESP_OKAY : RESP_SLVERR;
`endif
        if (addr_valid(wr_addr)) begin
          if (is_rw(wr_idx)) begin
            for (int b = 0; b < DATA_W/8; b++) begin
`ifdef BUG_B1
              regs[wr_idx][b*8 +: 8] <= wr_data[b*8 +: 8];   // B1: WSTRB ignored
`else
              if (wr_strb[b]) regs[wr_idx][b*8 +: 8] <= wr_data[b*8 +: 8];
`endif
            end
          end else if (wr_idx == IDX_STAT) begin
`ifdef BUG_B5
            if (wr_strb[0]) tmr_done <= 1'b0;                   // B5: any write clears DONE (W1C data bit ignored)
`else
            if (wr_strb[0] && wr_data[0]) tmr_done <= 1'b0;   // W1C: writing 1 clears
`endif
          end
          // SW_IN, TMR_COUNT, RESERVED: write ignored (still OKAY)
        end
      end else begin
        if (aw_hs) begin
          aw_held   <= 1'b1;
          aw_addr_q <= awaddr;
        end
        if (w_hs) begin
          w_held    <= 1'b1;
`ifdef BUG_B2
          if (aw_held) w_data_q <= wdata;             // B2: data of a W that arrives before AW is lost
`else
          w_data_q  <= wdata;
`endif
          w_strb_q  <= wstrb;
        end
      end

      // ---- (3) Timer DONE set: after the W1C clear, so "set" wins if both happen together ----
      if (tmr_hit) tmr_done <= 1'b1;

`ifdef BUG_B3
      if (bvalid && !do_write) bvalid <= 1'b0;        // B3: BVALID dropped without BREADY
`else
      if (bvalid && bready) bvalid <= 1'b0;
`endif
    end
  end

  // ---------------- Switch synchronizer ----------------
  always_ff @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
      sw_meta <= '0;
      sw_sync <= '0;
    end else begin
      sw_meta <= sw;
      sw_sync <= sw_meta;
    end
  end

  // ---------------- Outputs ----------------
  assign led = regs[IDX_LED][15:0];
  assign irq = tmr_done && regs[IDX_IRQEN][0];

  // ---------------- Read path ----------------
  function automatic logic [DATA_W-1:0] read_reg(input logic [IDX_W-1:0] i);
    case (i)
      IDX_LED:   return {16'h0, regs[IDX_LED][15:0]};     // unused bits read 0
      IDX_CTRL:  return {30'h0, regs[IDX_CTRL][1:0]};
      IDX_IRQEN: return {31'h0, regs[IDX_IRQEN][0]};
      IDX_SW:    return {16'h0, sw_sync};
      IDX_COUNT: return tmr_count;
      IDX_STAT:  return {31'h0, tmr_done};
      IDX_RSVD:  return '0;
      default:   return regs[i];
    endcase
  endfunction

  assign arready = !rvalid;
  wire ar_hs = arvalid && arready;

  always_ff @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
      rvalid <= 1'b0;
      rdata  <= '0;
      rresp  <= RESP_OKAY;
    end else begin
      if (ar_hs) begin
        rvalid <= 1'b1;
        if (addr_valid(araddr)) begin
          rdata <= read_reg(araddr[IDX_W+1:2]);
          rresp <= RESP_OKAY;
        end else begin
          rdata <= '0;
          rresp <= RESP_SLVERR;
        end
      end else if (rvalid && rready) begin
        rvalid <= 1'b0;
      end
    end
  end

endmodule
