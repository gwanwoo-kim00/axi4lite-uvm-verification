// Sequences: they decide WHAT transactions to send (driver decides HOW).

// 1) Write every register (0x00~0x3C) with random data, then read it back.
//    The scoreboard checks the results.
class axi_wr_rd_seq extends uvm_sequence #(axi_seq_item);
  `uvm_object_utils(axi_wr_rd_seq)

  function new(string name = "axi_wr_rd_seq");
    super.new(name);
  endfunction

  task body();
    axi_seq_item wr, rd;
    for (int i = 0; i < 16; i++) begin
      wr = axi_seq_item::type_id::create("wr");
      start_item(wr);
      if (!wr.randomize() with { is_write == 1; addr == i*4; strb == 4'hF; })
        `uvm_fatal("SEQ", "randomize failed")
      finish_item(wr);

      rd = axi_seq_item::type_id::create("rd");
      start_item(rd);
      if (!rd.randomize() with { is_write == 0; addr == i*4; })
        `uvm_fatal("SEQ", "randomize failed")
      finish_item(rd);
    end
  endtask
endclass

// 2) Fully random reads/writes (addresses, strobes, delays all random).
//    The scoreboard checks the results.
class axi_rand_seq extends uvm_sequence #(axi_seq_item);
  `uvm_object_utils(axi_rand_seq)
  int unsigned num_items = 20;

  function new(string name = "axi_rand_seq");
    super.new(name);
  endfunction

  task body();
    axi_seq_item t;
    repeat (num_items) begin
      t = axi_seq_item::type_id::create("t");
      start_item(t);
      if (!t.randomize()) `uvm_fatal("SEQ", "randomize failed")
      finish_item(t);
      `uvm_info("RAND", $sformatf("%s addr=0x%02h data=%08h strb=%b resp=%0d",
                t.is_write ? "WR" : "RD", t.addr, t.data, t.strb, t.resp), UVM_LOW)
    end
  endtask
endclass
