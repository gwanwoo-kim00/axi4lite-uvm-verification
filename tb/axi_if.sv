// AXI4-Lite interface: bundles all channel signals for DUT and testbench
interface axi_if #(parameter int ADDR_W = 32, parameter int DATA_W = 32) (input logic aclk, input logic aresetn);
  logic [ADDR_W-1:0]   awaddr;  logic [2:0] awprot;  logic awvalid; logic awready;
  logic [DATA_W-1:0]   wdata;   logic [DATA_W/8-1:0] wstrb; logic wvalid; logic wready;
  logic [1:0]          bresp;   logic bvalid;  logic bready;
  logic [ADDR_W-1:0]   araddr;  logic [2:0] arprot;  logic arvalid; logic arready;
  logic [DATA_W-1:0]   rdata;   logic [1:0] rresp;   logic rvalid;  logic rready;
  logic [15:0]         led;     logic irq;   // peripheral pins (watched by tests)
endinterface
