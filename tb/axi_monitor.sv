// Monitor: passively samples the bus and publishes one seq_item per completed transaction.
class axi_monitor extends uvm_monitor;
  `uvm_component_utils(axi_monitor)
  virtual axi_if vif;
  uvm_analysis_port #(axi_seq_item) ap;

  // AW/W/AR are queued until the matching B/R response completes the transaction
  bit [31:0] aw_addr_q[$];
  bit [31:0] w_data_q[$];
  bit [3:0]  w_strb_q[$];
  bit [31:0] ar_addr_q[$];

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual axi_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "virtual interface 'vif' not found in config_db")
  endfunction

  task run_phase(uvm_phase phase);
    axi_seq_item t;
    wait (vif.aresetn === 1'b1);
    forever begin
      @(posedge vif.aclk);

      if (vif.awvalid && vif.awready) aw_addr_q.push_back(vif.awaddr);

      if (vif.wvalid && vif.wready) begin
        w_data_q.push_back(vif.wdata);
        w_strb_q.push_back(vif.wstrb);
      end

      if (vif.bvalid && vif.bready) begin
        if (aw_addr_q.size() == 0 || w_data_q.size() == 0)
          `uvm_error("MON", "B response without a matching AW/W")
        else begin
          t = axi_seq_item::type_id::create("t");
          t.is_write = 1;
          t.addr = aw_addr_q.pop_front();
          t.data = w_data_q.pop_front();
          t.strb = w_strb_q.pop_front();
          t.resp = vif.bresp;
          ap.write(t);
        end
      end

      if (vif.arvalid && vif.arready) ar_addr_q.push_back(vif.araddr);

      if (vif.rvalid && vif.rready) begin
        if (ar_addr_q.size() == 0)
          `uvm_error("MON", "R response without a matching AR")
        else begin
          t = axi_seq_item::type_id::create("t");
          t.is_write = 0;
          t.addr = ar_addr_q.pop_front();
          t.data = vif.rdata;
          t.resp = vif.rresp;
          ap.write(t);
        end
      end
    end
  endtask
endclass
