// Driver: takes one seq_item and wiggles the AXI pins following VALID/READY rules.
// Signals are driven with <= right after a clock edge; READY/VALID are sampled at the edge.
class axi_driver extends uvm_driver #(axi_seq_item);
  `uvm_component_utils(axi_driver)
  virtual axi_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual axi_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "virtual interface 'vif' not found in config_db")
  endfunction

  task run_phase(uvm_phase phase);
    reset_signals();
    wait (vif.aresetn === 1'b1);
    @(posedge vif.aclk);
    forever begin
      seq_item_port.get_next_item(req);
      if (req.is_write) drive_write(req);
      else              drive_read(req);
      seq_item_port.item_done();
    end
  endtask

  task reset_signals();
    vif.awvalid <= 0; vif.awaddr <= 0; vif.awprot <= 0;
    vif.wvalid  <= 0; vif.wdata  <= 0; vif.wstrb  <= 0;
    vif.bready  <= 0;
    vif.arvalid <= 0; vif.araddr <= 0; vif.arprot <= 0;
    vif.rready  <= 0;
  endtask

  // AW and W are independent channels, so drive them in parallel with their own delays.
  task drive_write(axi_seq_item t);
    fork
      begin : aw_ch
        repeat (t.aw_dly) @(posedge vif.aclk);
        vif.awaddr  <= t.addr;
        vif.awvalid <= 1;
        do @(posedge vif.aclk); while (vif.awready !== 1'b1);
        vif.awvalid <= 0;
      end
      begin : w_ch
        repeat (t.w_dly) @(posedge vif.aclk);
        vif.wdata  <= t.data;
        vif.wstrb  <= t.strb;
        vif.wvalid <= 1;
        do @(posedge vif.aclk); while (vif.wready !== 1'b1);
        vif.wvalid <= 0;
      end
    join
    // B channel: wait b_dly cycles before saying "ready" (back-pressure test)
    repeat (t.b_dly) @(posedge vif.aclk);
    vif.bready <= 1;
    do @(posedge vif.aclk); while (vif.bvalid !== 1'b1);
    t.resp = vif.bresp;
    vif.bready <= 0;
    `uvm_info("DRV", $sformatf("WR addr=0x%02h data=%08h strb=%b bresp=%0d",
              t.addr, t.data, t.strb, t.resp), UVM_HIGH)
  endtask

  task drive_read(axi_seq_item t);
    repeat (t.aw_dly) @(posedge vif.aclk);   // reuse aw_dly as the AR delay
    vif.araddr  <= t.addr;
    vif.arvalid <= 1;
    do @(posedge vif.aclk); while (vif.arready !== 1'b1);
    vif.arvalid <= 0;
    repeat (t.r_dly) @(posedge vif.aclk);
    vif.rready <= 1;
    do @(posedge vif.aclk); while (vif.rvalid !== 1'b1);
    t.data = vif.rdata;
    t.resp = vif.rresp;
    vif.rready <= 0;
    `uvm_info("DRV", $sformatf("RD addr=0x%02h data=%08h rresp=%0d",
              t.addr, t.data, t.resp), UVM_HIGH)
  endtask
endclass
