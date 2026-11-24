// SVA checker: AXI4-Lite handshake rules. Bound to the DUT (bottom of file), DUT code untouched.
module axi_sva (
  input logic        aclk,
  input logic        aresetn,
  input logic [31:0] awaddr,  input logic awvalid, input logic awready,
  input logic [31:0] wdata,   input logic [3:0] wstrb, input logic wvalid, input logic wready,
  input logic [1:0]  bresp,   input logic bvalid,  input logic bready,
  input logic [31:0] araddr,  input logic arvalid, input logic arready,
  input logic [31:0] rdata,   input logic [1:0] rresp, input logic rvalid, input logic rready
);
  default clocking cb @(posedge aclk); endclocking
  default disable iff (!aresetn);

  // AW: master holds VALID and address until READY (checked by axi_pipe_test)
  a_aw_hold: assert property (awvalid && !awready |=> awvalid)
    else $error("[SVA] AWVALID dropped before AWREADY");
  a_aw_stable: assert property (awvalid && !awready |=> $stable(awaddr))
    else $error("[SVA] AWADDR changed while waiting for AWREADY");

  // W: master holds VALID, data and strobe until READY
  a_w_hold: assert property (wvalid && !wready |=> wvalid)
    else $error("[SVA] WVALID dropped before WREADY");
  a_w_stable: assert property (wvalid && !wready |=> $stable(wdata) && $stable(wstrb))
    else $error("[SVA] WDATA/WSTRB changed while waiting for WREADY");

  // B / R: DUT holds VALID (and read data) until READY. a_b_hold catches BUG_B3
  a_b_hold: assert property (bvalid && !bready |=> bvalid)
    else $error("[SVA] BVALID dropped before BREADY");
  a_r_hold: assert property (rvalid && !rready |=> rvalid)
    else $error("[SVA] RVALID dropped before RREADY");
  a_r_stable: assert property (rvalid && !rready |=> $stable(rdata))
    else $error("[SVA] RDATA changed while waiting for RREADY");

  // BRESP is OKAY or SLVERR only
  a_bresp_legal: assert property (bvalid |-> (bresp == 2'b00 || bresp == 2'b10))
    else $error("[SVA] illegal BRESP %b", bresp);
endmodule

// (.*) connects every port to the DUT signal of the same name
bind axi4lite_slave axi_sva u_sva (.*);
