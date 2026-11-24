// Package with all UVM classes (include order matters)
package axi_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  `include "axi_seq_item.sv"
  `include "axi_sequence.sv"
  `include "axi_driver.sv"
  `include "axi_pipe_driver.sv"
  `include "axi_monitor.sv"
  `include "axi_reg_model.sv"
  `include "axi_reg_adapter.sv"
  `include "axi_scoreboard.sv"
  `include "axi_agent.sv"
  `include "axi_coverage.sv"
  `include "axi_env.sv"
  `include "axi_base_test.sv"
  `include "axi_rand_test.sv"
  `include "axi_timer_test.sv"
  `include "axi_pipe_test.sv"
endpackage
