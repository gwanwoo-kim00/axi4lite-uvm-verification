// Pipelined driver: up to max_outstanding writes in flight at the same time.
// axi_driver completes AW/W/B before taking the next item, so VALID=1 && READY=0 never
// happens and the SVA hold/stable checks pass vacuously. Here AW, W and B each run in
// their own thread fed by a mailbox; the main loop dispatches and takes the next item.
// Reads are not pipelined: wait until all writes have their B response, then drive_read().
class axi_pipe_driver extends axi_driver;     // inherits vif, reset_signals(), drive_read()
  `uvm_component_utils(axi_pipe_driver)

  int unsigned max_outstanding = 4;
  int unsigned outstanding;        // writes handed out whose B response has not come back yet
  int unsigned max_seen;           // largest "outstanding" ever seen (printed by the test)

  // One mailbox per write channel
  mailbox #(axi_seq_item) aw_mb = new();
  mailbox #(axi_seq_item) w_mb  = new();
  mailbox #(axi_seq_item) b_mb  = new();

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    reset_signals();
    wait (vif.aresetn === 1'b1);
    @(posedge vif.aclk);
    fork                                  // start the three workers, they run forever
      aw_thread();
      w_thread();
      b_thread();
    join_none

    forever begin
      seq_item_port.get_next_item(req);
      if (req.is_write) begin
        wait (outstanding < max_outstanding);   // too many in flight -> wait for a B
        outstanding++;
        if (outstanding > max_seen) max_seen = outstanding;
        aw_mb.put(req);                         // same item goes to all three workers
        w_mb.put(req);
        b_mb.put(req);
      end else begin
        wait (outstanding == 0);                // drain all writes before a read
        drive_read(req);
      end
      seq_item_port.item_done();          // write: returns at once, without waiting for B
    end
  endtask

  // AW worker: send addresses one after another
  task aw_thread();
    axi_seq_item t;
    forever begin
      aw_mb.get(t);
      repeat (t.aw_dly) @(posedge vif.aclk);
      vif.awaddr  <= t.addr;
      vif.awvalid <= 1;
      do @(posedge vif.aclk); while (vif.awready !== 1'b1);
      vif.awvalid <= 0;
    end
  endtask

  // W worker: send data/strobe one after another
  task w_thread();
    axi_seq_item t;
    forever begin
      w_mb.get(t);
      repeat (t.w_dly) @(posedge vif.aclk);
      vif.wdata  <= t.data;
      vif.wstrb  <= t.strb;
      vif.wvalid <= 1;
      do @(posedge vif.aclk); while (vif.wready !== 1'b1);
      vif.wvalid <= 0;
    end
  endtask

  // B worker: accept responses in order; each B finishes one write
  task b_thread();
    axi_seq_item t;
    forever begin
      b_mb.get(t);
      repeat (t.b_dly) @(posedge vif.aclk);
      vif.bready <= 1;
      do @(posedge vif.aclk); while (vif.bvalid !== 1'b1);
      t.resp = vif.bresp;
      vif.bready <= 0;
      outstanding--;
    end
  endtask
endclass
