// axi_periph.v : Vivado / Basys3 version of the verified peripheral (rtl/axi4lite_slave.sv)
// - Plain Verilog-2001 so Vivado "Add Module" (module reference) accepts it
// - Port names start with s_axi_ so Vivado recognizes an AXI4-Lite slave automatically
// - 6-bit address: the interconnect only passes the offset 0x00~0x3C (all 16 registers valid)
// - Same register map and behavior as the UVM-verified RTL (bug ifdefs removed)
`timescale 1ns/1ps
module axi_periph (
  (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF S_AXI, ASSOCIATED_RESET s_axi_aresetn" *)
  input  wire        s_axi_aclk,
  input  wire        s_axi_aresetn,
  input  wire [5:0]  s_axi_awaddr,
  input  wire [2:0]  s_axi_awprot,
  input  wire        s_axi_awvalid,
  output wire        s_axi_awready,
  input  wire [31:0] s_axi_wdata,
  input  wire [3:0]  s_axi_wstrb,
  input  wire        s_axi_wvalid,
  output wire        s_axi_wready,
  output reg  [1:0]  s_axi_bresp,
  output reg         s_axi_bvalid,
  input  wire        s_axi_bready,
  input  wire [5:0]  s_axi_araddr,
  input  wire [2:0]  s_axi_arprot,
  input  wire        s_axi_arvalid,
  output wire        s_axi_arready,
  output reg  [31:0] s_axi_rdata,
  output reg  [1:0]  s_axi_rresp,
  output reg         s_axi_rvalid,
  input  wire        s_axi_rready,
  output wire [15:0] led,
  input  wire [15:0] sw,
  (* X_INTERFACE_INFO = "xilinx.com:signal:interrupt:1.0 irq INTERRUPT" *)
  (* X_INTERFACE_PARAMETER = "SENSITIVITY LEVEL_HIGH" *)
  output wire        irq
);
  localparam IDX_LED = 8, IDX_SW = 9, IDX_CTRL = 10, IDX_LOAD = 11,
             IDX_COUNT = 12, IDX_STAT = 13, IDX_IRQEN = 14, IDX_RSVD = 15;

  reg [31:0] regs [0:15];
  reg [31:0] tmr_count;
  reg        tmr_done, tmr_en_q;
  reg [15:0] sw_meta, sw_sync;

  // ---------------- write path ----------------
  reg        aw_held, w_held;
  reg [5:0]  aw_addr_q;
  reg [31:0] w_data_q;
  reg [3:0]  w_strb_q;

  assign s_axi_awready = !aw_held && !s_axi_bvalid;
  assign s_axi_wready  = !w_held  && !s_axi_bvalid;
  wire aw_hs = s_axi_awvalid && s_axi_awready;
  wire w_hs  = s_axi_wvalid  && s_axi_wready;
  wire        have_aw  = aw_held || aw_hs;
  wire        have_w   = w_held  || w_hs;
  wire [5:0]  wr_addr  = aw_held ? aw_addr_q : s_axi_awaddr;
  wire [31:0] wr_data  = w_held  ? w_data_q  : s_axi_wdata;
  wire [3:0]  wr_strb  = w_held  ? w_strb_q  : s_axi_wstrb;
  wire        do_write = have_aw && have_w && !s_axi_bvalid;
  wire [3:0]  wr_idx   = wr_addr[5:2];
  wire        wr_is_rw = (wr_idx <= IDX_LED) || (wr_idx == IDX_CTRL) ||
                         (wr_idx == IDX_LOAD) || (wr_idx == IDX_IRQEN);

  wire tmr_en    = regs[IDX_CTRL][0];
  wire tmr_auto  = regs[IDX_CTRL][1];
  wire tmr_start = tmr_en && !tmr_en_q;
  wire tmr_hit   = tmr_en && tmr_en_q && (tmr_count == regs[IDX_LOAD]);

  integer i, b;
  always @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
    if (!s_axi_aresetn) begin
      aw_held <= 1'b0;  w_held <= 1'b0;
      aw_addr_q <= 6'd0;  w_data_q <= 32'd0;  w_strb_q <= 4'd0;
      s_axi_bvalid <= 1'b0;  s_axi_bresp <= 2'b00;
      for (i = 0; i < 16; i = i + 1) regs[i] <= 32'd0;
      tmr_count <= 32'd0;  tmr_done <= 1'b0;  tmr_en_q <= 1'b0;
    end else begin
      tmr_en_q <= tmr_en;
      // (1) timer
      if (!tmr_en)            tmr_count <= tmr_count;          // stopped: hold
      else if (tmr_start)     tmr_count <= 32'd0;              // start from 0
      else if (tmr_hit) begin
        if (tmr_auto)         tmr_count <= 32'd0;              // auto-reload
        else                  regs[IDX_CTRL][0] <= 1'b0;       // one-shot: stop
      end else                tmr_count <= tmr_count + 32'd1;

      // (2) bus write
      if (do_write) begin
        aw_held <= 1'b0;  w_held <= 1'b0;
        s_axi_bvalid <= 1'b1;  s_axi_bresp <= 2'b00;
        if (wr_is_rw) begin
          for (b = 0; b < 4; b = b + 1)
            if (wr_strb[b]) regs[wr_idx][b*8 +: 8] <= wr_data[b*8 +: 8];
        end else if (wr_idx == IDX_STAT) begin
          if (wr_strb[0] && wr_data[0]) tmr_done <= 1'b0;    // W1C
        end
      end else begin
        if (aw_hs) begin aw_held <= 1'b1; aw_addr_q <= s_axi_awaddr; end
        if (w_hs)  begin w_held  <= 1'b1; w_data_q <= s_axi_wdata; w_strb_q <= s_axi_wstrb; end
      end

      // (3) DONE set wins over clear
      if (tmr_hit) tmr_done <= 1'b1;

      if (s_axi_bvalid && s_axi_bready) s_axi_bvalid <= 1'b0;
    end
  end

  // ---------------- switch synchronizer ----------------
  always @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
    if (!s_axi_aresetn) begin sw_meta <= 16'd0; sw_sync <= 16'd0; end
    else begin sw_meta <= sw; sw_sync <= sw_meta; end
  end

  assign led = regs[IDX_LED][15:0];
  assign irq = tmr_done && regs[IDX_IRQEN][0];

  // ---------------- read path ----------------
  reg [31:0] rd_val;
  always @(*) begin
    case (s_axi_araddr[5:2])
      IDX_LED:   rd_val = {16'h0, regs[IDX_LED][15:0]};
      IDX_SW:    rd_val = {16'h0, sw_sync};
      IDX_CTRL:  rd_val = {30'h0, regs[IDX_CTRL][1:0]};
      IDX_COUNT: rd_val = tmr_count;
      IDX_STAT:  rd_val = {31'h0, tmr_done};
      IDX_IRQEN: rd_val = {31'h0, regs[IDX_IRQEN][0]};
      IDX_RSVD:  rd_val = 32'h0;
      default:   rd_val = regs[s_axi_araddr[5:2]];
    endcase
  end

  assign s_axi_arready = !s_axi_rvalid;
  always @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
    if (!s_axi_aresetn) begin
      s_axi_rvalid <= 1'b0;  s_axi_rdata <= 32'd0;  s_axi_rresp <= 2'b00;
    end else if (s_axi_arvalid && s_axi_arready) begin
      s_axi_rvalid <= 1'b1;  s_axi_rdata <= rd_val;  s_axi_rresp <= 2'b00;
    end else if (s_axi_rvalid && s_axi_rready) begin
      s_axi_rvalid <= 1'b0;
    end
  end
endmodule
