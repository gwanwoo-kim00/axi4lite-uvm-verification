// Pipe test: same traffic as axi_rand_test, driver replaced by axi_pipe_driver (factory override).
// Counts AW/W wait cycles (VALID=1, READY=0), the condition the SVA hold/stable rules check.
class axi_pipe_test extends axi_rand_test;     // inherits the rand test's run_phase (traffic)
  `uvm_component_utils(axi_pipe_test)

  virtual axi_if vif;
  int unsigned aw_waits, w_waits;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    // must come before super.build_phase, where the driver is created
    set_type_override_by_type(axi_driver::get_type(), axi_pipe_driver::get_type());

    super.build_phase(phase);
    if (!uvm_config_db#(virtual axi_if)::get(this, "", "vif", vif))
      `uvm_fatal("PIPE", "no vif")
  endfunction

  task run_phase(uvm_phase phase);
    uvm_objection obj = phase.get_objection();
    obj.set_drain_time(this, 1us);       // writes still in flight when the sequence ends: give them time
    fork count_waits(); join_none
    super.run_phase(phase);              // same sequences as axi_rand_test
  endtask

  task count_waits();
    forever begin
      @(posedge vif.aclk);
      if (vif.awvalid === 1'b1 && vif.awready === 1'b0) aw_waits++;
      if (vif.wvalid  === 1'b1 && vif.wready  === 1'b0) w_waits++;
    end
  endtask

  function void report_phase(uvm_phase phase);
    axi_pipe_driver d;
    super.report_phase(phase);
    if (!$cast(d, env.agt.drv)) begin
      `uvm_error("PIPE", "driver is still axi_driver: factory override did not happen")
      return;
    end
    `uvm_info("PIPE", $sformatf("pipe test: max outstanding=%0d, AW waits=%0d, W waits=%0d",
              d.max_seen, aw_waits, w_waits), UVM_NONE)
    if (d.max_seen < 2 || aw_waits == 0 || w_waits == 0)
      `uvm_error("PIPE", "pipelining/back-pressure was not exercised")
  endfunction
endclass
