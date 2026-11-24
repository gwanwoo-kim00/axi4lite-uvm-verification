// RAL register model, written from docs/peripheral_spec.md
//   field.configure(parent, size, lsb, access, volatile, reset, has_reset, is_rand, indiv_access)
// volatile = 1 : changed by hardware (switch, counter, timer flags); the scoreboard skips it

class scratch_reg extends uvm_reg;            // 0x00 ~ 0x1C : plain storage
  `uvm_object_utils(scratch_reg)
  rand uvm_reg_field data;
  function new(string name = "scratch_reg");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction
  virtual function void build();
    data = uvm_reg_field::type_id::create("data");
    data.configure(this, 32, 0, "RW", 0, 32'h0, 1, 1, 0);
  endfunction
endclass

class led_reg extends uvm_reg;                // 0x20 LED_OUT : [15:0] RW
  `uvm_object_utils(led_reg)
  rand uvm_reg_field led;
  function new(string name = "led_reg");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction
  virtual function void build();
    led = uvm_reg_field::type_id::create("led");
    led.configure(this, 16, 0, "RW", 0, 32'h0, 1, 1, 0);
  endfunction
endclass

class sw_reg extends uvm_reg;                 // 0x24 SW_IN : [15:0] RO, follows the board switches
  `uvm_object_utils(sw_reg)
  uvm_reg_field sw;
  function new(string name = "sw_reg");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction
  virtual function void build();
    sw = uvm_reg_field::type_id::create("sw");
    sw.configure(this, 16, 0, "RO", 1, 32'h0, 1, 0, 0);
  endfunction
endclass

class ctrl_reg extends uvm_reg;               // 0x28 TMR_CTRL : [0] EN, [1] AUTO_RELOAD
  `uvm_object_utils(ctrl_reg)
  rand uvm_reg_field en;
  rand uvm_reg_field auto_reload;
  function new(string name = "ctrl_reg");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction
  virtual function void build();
    en          = uvm_reg_field::type_id::create("en");
    auto_reload = uvm_reg_field::type_id::create("auto_reload");
    // EN is RW, but the timer clears it by itself in one-shot mode -> volatile = 1
    en.configure(this, 1, 0, "RW", 1, 1'b0, 1, 1, 0);
    auto_reload.configure(this, 1, 1, "RW", 0, 32'h0, 1, 1, 0);
  endfunction
endclass

class load_reg extends uvm_reg;               // 0x2C TMR_LOAD : 32-bit RW
  `uvm_object_utils(load_reg)
  rand uvm_reg_field load;
  function new(string name = "load_reg");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction
  virtual function void build();
    load = uvm_reg_field::type_id::create("load");
    load.configure(this, 32, 0, "RW", 0, 32'h0, 1, 1, 0);
  endfunction
endclass

class count_reg extends uvm_reg;              // 0x30 TMR_COUNT : 32-bit RO, counts by itself
  `uvm_object_utils(count_reg)
  uvm_reg_field count;
  function new(string name = "count_reg");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction
  virtual function void build();
    count = uvm_reg_field::type_id::create("count");
    count.configure(this, 32, 0, "RO", 1, 32'h0, 1, 0, 0);
  endfunction
endclass

class status_reg extends uvm_reg;             // 0x34 TMR_STATUS : [0] DONE, write 1 to clear
  `uvm_object_utils(status_reg)
  uvm_reg_field done;
  function new(string name = "status_reg");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction
  virtual function void build();
    done = uvm_reg_field::type_id::create("done");
    done.configure(this, 1, 0, "W1C", 1, 32'h0, 1, 0, 0);
  endfunction
endclass

class irqen_reg extends uvm_reg;              // 0x38 IRQ_EN : [0] RW
  `uvm_object_utils(irqen_reg)
  rand uvm_reg_field en;
  function new(string name = "irqen_reg");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction
  virtual function void build();
    en = uvm_reg_field::type_id::create("en");
    en.configure(this, 1, 0, "RW", 0, 1'b0, 1, 1, 0);
  endfunction
endclass

class rsvd_reg extends uvm_reg;               // 0x3C RESERVED : always reads 0
  `uvm_object_utils(rsvd_reg)
  uvm_reg_field zero;
  function new(string name = "rsvd_reg");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction
  virtual function void build();
    zero = uvm_reg_field::type_id::create("zero");
    zero.configure(this, 32, 0, "RO", 0, 32'h0, 1, 0, 0);     // RO + not volatile = always 0
  endfunction
endclass

// The block = the whole register map (address -> register)
class axi_reg_block extends uvm_reg_block;
  `uvm_object_utils(axi_reg_block)

  rand scratch_reg scratch[8];
  rand led_reg     led_out;
       sw_reg      sw_in;
  rand ctrl_reg    tmr_ctrl;
  rand load_reg    tmr_load;
       count_reg   tmr_count;
       status_reg  tmr_status;
  rand irqen_reg   irq_en;
       rsvd_reg    rsvd;

  function new(string name = "axi_reg_block");
    super.new(name, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    // map: base address 0, 4 bytes per register
    default_map = create_map("map", 0, 4, UVM_LITTLE_ENDIAN);

    foreach (scratch[i]) begin
      scratch[i] = scratch_reg::type_id::create($sformatf("scratch%0d", i));
      scratch[i].configure(this);
      scratch[i].build();
      default_map.add_reg(scratch[i], i*4, "RW");
    end

    led_out = led_reg::type_id::create("led_out");
    led_out.configure(this);  led_out.build();  default_map.add_reg(led_out, 'h20, "RW");

    sw_in = sw_reg::type_id::create("sw_in");
    sw_in.configure(this);  sw_in.build();  default_map.add_reg(sw_in, 'h24, "RO");

    tmr_ctrl = ctrl_reg::type_id::create("tmr_ctrl");
    tmr_ctrl.configure(this);  tmr_ctrl.build();  default_map.add_reg(tmr_ctrl, 'h28, "RW");

    tmr_load = load_reg::type_id::create("tmr_load");
    tmr_load.configure(this);  tmr_load.build();  default_map.add_reg(tmr_load, 'h2C, "RW");

    tmr_count = count_reg::type_id::create("tmr_count");
    tmr_count.configure(this);  tmr_count.build();  default_map.add_reg(tmr_count, 'h30, "RO");

    tmr_status = status_reg::type_id::create("tmr_status");
    tmr_status.configure(this);  tmr_status.build();  default_map.add_reg(tmr_status, 'h34, "RW");

    irq_en = irqen_reg::type_id::create("irq_en");
    irq_en.configure(this);  irq_en.build();  default_map.add_reg(irq_en, 'h38, "RW");

    rsvd = rsvd_reg::type_id::create("rsvd");
    rsvd.configure(this);  rsvd.build();  default_map.add_reg(rsvd, 'h3C, "RO");

    lock_model();   // map is final; no more registers can be added
  endfunction
endclass
