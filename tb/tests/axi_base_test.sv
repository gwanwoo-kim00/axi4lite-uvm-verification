// Base test: builds the env and sets common options. It runs no traffic itself.
// Real tests extend this class and only write run_phase.
class axi_base_test extends uvm_test;
  `uvm_component_utils(axi_base_test)

  axi_env env;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = axi_env::type_id::create("env", this);
    // If the DUT hangs (e.g. BUG_B3), stop with UVM_FATAL instead of running forever
    uvm_top.set_timeout(200us, 0);
  endfunction

  function void end_of_elaboration_phase(uvm_phase phase);
    uvm_top.print_topology();
  endfunction
endclass
