// Random test: write/read of every register, then 200 constrained-random transactions
class axi_rand_test extends axi_base_test;
  `uvm_component_utils(axi_rand_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    axi_wr_rd_seq wr_rd = axi_wr_rd_seq::type_id::create("wr_rd");
    axi_rand_seq  rnd   = axi_rand_seq::type_id::create("rnd");
    phase.raise_objection(this);
    rnd.num_items = 200;
    wr_rd.start(env.agt.sqr);
    rnd.start(env.agt.sqr);
    #100;
    phase.drop_objection(this);
  endtask
endclass
