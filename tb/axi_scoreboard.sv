// Scoreboard: uses the RAL model (axi_reg_model.sv) as the reference.
// Each field's access rule (RW / RO / W1C) is applied by UVM.
//   write -> predict the model
//   read  -> compare with the model; volatile fields (SW, COUNT, EN, DONE) are skipped
class axi_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(axi_scoreboard)
  uvm_analysis_imp #(axi_seq_item, axi_scoreboard) imp;

  axi_reg_block ral;             // register model (reference)
  int n_wr, n_rd, n_err;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    imp = new("imp", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ral = axi_reg_block::type_id::create("ral");
    ral.build();                 // make all registers + address map
    ral.reset();                 // every field starts at its reset value
  endfunction

  // Called automatically every time the monitor does ap.write(t)
  function void write(axi_seq_item t);
    bit       valid    = (t.addr[31:6] == 0);         // 0x00 ~ 0x3C
    bit [1:0] exp_resp = valid ? 2'b00 : 2'b10;       // OKAY or SLVERR
    uvm_reg   rg;

    if (t.resp != exp_resp) begin
      n_err++;
      `uvm_error("SB", $sformatf("%s addr=0x%02h resp=%0d, expected %0d",
                 t.is_write ? "WR" : "RD", t.addr, t.resp, exp_resp))
    end

    if (t.is_write) n_wr++; else n_rd++;

    if (!valid) begin                                 // outside the map: read data must be 0
      if (!t.is_write && t.data !== 32'h0) begin
        n_err++;
        `uvm_error("SB", $sformatf("RD addr=0x%02h data=%08h, expected 00000000", t.addr, t.data))
      end
      return;
    end

    rg = ral.default_map.get_reg_by_offset(t.addr);   // address -> register in the model
    if (t.is_write) predict_write(rg, t.data, t.strb);
    else            check_read(rg, t.addr, t.data);
  endfunction

  // Write: for every field that has at least one byte enabled by WSTRB,
  // tell the model "this was written". UVM applies the field's rule:
  //   RW -> takes the new value, RO -> ignores it, W1C -> 1 clears the bit
  function void predict_write(uvm_reg rg, bit [31:0] data, bit [3:0] strb);
    uvm_reg_field flds[$];
    bit [31:0]    bmask = {{8{strb[3]}}, {8{strb[2]}}, {8{strb[1]}}, {8{strb[0]}}};
    rg.get_fields(flds);
    foreach (flds[i]) begin
      int unsigned lsb    = flds[i].get_lsb_pos();
      bit [31:0]   fmask  = ((64'h1 << flds[i].get_n_bits()) - 1) << lsb;
      bit [31:0]   cur    = flds[i].get_mirrored_value() << lsb;
      bit [31:0]   merged = (cur & ~bmask) | (data & bmask);   // keep bytes WSTRB did not enable
      if ((fmask & bmask) != 0)
        void'(flds[i].predict((merged & fmask) >> lsb, .kind(UVM_PREDICT_WRITE)));
    end
  endfunction

  // Read: build the expected value from the model, but only for bits we can predict.
  // Volatile fields are left out of the compare and simply updated to what the DUT returned.
  // Bits that belong to no field must read 0.
  function void check_read(uvm_reg rg, bit [31:0] addr, bit [31:0] data);
    uvm_reg_field flds[$];
    bit [31:0]    exp_data = 32'h0;
    bit [31:0]    cmp_mask = 32'hFFFF_FFFF;
    rg.get_fields(flds);
    foreach (flds[i]) begin
      int unsigned lsb   = flds[i].get_lsb_pos();
      bit [31:0]   fmask = ((64'h1 << flds[i].get_n_bits()) - 1) << lsb;
      if (flds[i].is_volatile()) begin
        cmp_mask &= ~fmask;
        void'(flds[i].predict((data & fmask) >> lsb, .kind(UVM_PREDICT_READ)));
      end else begin
        exp_data |= (flds[i].get_mirrored_value() << lsb);
      end
    end
    if ((data & cmp_mask) !== (exp_data & cmp_mask)) begin
      n_err++;
      `uvm_error("SB", $sformatf("RD addr=0x%02h data=%08h, expected %08h (checked bits %08h, %s)",
                 addr, data, exp_data, cmp_mask, rg.get_name()))
    end
  endfunction

  function void report_phase(uvm_phase phase);
    `uvm_info("SB", $sformatf("checked %0d writes, %0d reads, %0d mismatches",
              n_wr, n_rd, n_err), UVM_NONE)
  endfunction
endclass
