// UVM top: clock, reset, interface, DUT, and run_test()
`timescale 1ns/1ps
module top;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import axi_pkg::*;

  logic aclk = 0;
  always #5 aclk = ~aclk;

  logic aresetn = 0;
  initial begin
    repeat (5) @(posedge aclk);
    aresetn = 1;
  end

  logic [15:0] led;
  logic        irq;
  logic [15:0] sw = 16'hBEEF;

  axi_if vif (aclk, aresetn);
  assign vif.led = led;
  assign vif.irq = irq;

  axi4lite_slave dut (
    .aclk(aclk), .aresetn(aresetn),
    .awaddr(vif.awaddr), .awprot(vif.awprot), .awvalid(vif.awvalid), .awready(vif.awready),
    .wdata(vif.wdata), .wstrb(vif.wstrb), .wvalid(vif.wvalid), .wready(vif.wready),
    .bresp(vif.bresp), .bvalid(vif.bvalid), .bready(vif.bready),
    .araddr(vif.araddr), .arprot(vif.arprot), .arvalid(vif.arvalid), .arready(vif.arready),
    .rdata(vif.rdata), .rresp(vif.rresp), .rvalid(vif.rvalid), .rready(vif.rready),
    .led(led), .sw(sw), .irq(irq)
  );

  initial begin
    uvm_config_db#(virtual axi_if)::set(null, "*", "vif", vif);
    run_test();
  end

  initial begin
    $fsdbDumpfile("wave.fsdb");
    $fsdbDumpvars(0, top, "+all");
  end
endmodule
