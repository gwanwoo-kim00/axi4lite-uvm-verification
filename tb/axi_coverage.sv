// Functional coverage: samples every transaction published by the monitor
class axi_coverage extends uvm_subscriber #(axi_seq_item);
  `uvm_component_utils(axi_coverage)

  axi_seq_item t;   // the item being sampled right now

  covergroup cg;
    cp_rw: coverpoint t.is_write {
      bins rd = {0};
      bins wr = {1};
    }

    cp_resp: coverpoint t.resp {
      bins okay   = {2'b00};
      bins slverr = {2'b10};
    }

    // access outside the register map (>= 0x40)
    cp_bad_addr: coverpoint (t.addr[31:6] != 0) {
      bins bad = {1};
    }

    // every register index 0..15, valid addresses only
    cp_reg: coverpoint t.addr[5:2] iff (t.addr[31:6] == 0) {
      bins regs[] = {[0:15]};
    }

    // WSTRB patterns, writes only
    cp_strb: coverpoint t.strb iff (t.is_write) {
      bins full    = {4'b1111};
      bins single  = {4'b0001, 4'b0010, 4'b0100, 4'b1000};
      bins partial = {4'b0011, 4'b0101, 4'b0110, 4'b1001, 4'b1010, 4'b1100,
                      4'b0111, 4'b1011, 4'b1101, 4'b1110};
      bins none    = {4'b0000};
    }

    cx_rw_resp: cross cp_rw, cp_resp;
    cx_rw_reg:  cross cp_rw, cp_reg;
  endgroup

  function new(string name, uvm_component parent);
    super.new(name, parent);
    cg = new();
  endfunction

  function void write(axi_seq_item t);
    this.t = t;
    cg.sample();
  endfunction

  function void report_phase(uvm_phase phase);
    `uvm_info("COV", $sformatf("functional coverage = %0.1f%%  (rw %0.0f, resp %0.0f, reg %0.0f, strb %0.0f)",
              cg.get_coverage(), cg.cp_rw.get_coverage(), cg.cp_resp.get_coverage(),
              cg.cp_reg.get_coverage(), cg.cp_strb.get_coverage()), UVM_NONE)
  endfunction
endclass
