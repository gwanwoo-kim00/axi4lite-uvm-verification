// Timer / W1C / IRQ directed test: checks the volatile fields the scoreboard skips
// (SW, COUNT, EN, DONE) and the led/irq pins. Accesses use RAL frontdoor (real AXI transfers).
class axi_timer_test extends axi_base_test;
  `uvm_component_utils(axi_timer_test)

  axi_reg_adapter adapter;
  virtual axi_if  vif;
  int n_chk, n_fail;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    adapter = axi_reg_adapter::type_id::create("adapter");
    if (!uvm_config_db#(virtual axi_if)::get(this, "", "vif", vif))
      `uvm_fatal("TMR", "no vif")
  endfunction

  // Tell the register model which sequencer + translator to use for frontdoor access
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    env.sb.ral.default_map.set_sequencer(env.agt.sqr, adapter);
  endfunction

  function void chk(string what, uvm_reg_data_t got, uvm_reg_data_t exp);
    n_chk++;
    if (got !== exp) begin
      n_fail++;
      `uvm_error("TMR", $sformatf("FAIL %s: got %0h, expected %0h", what, got, exp))
    end else
      `uvm_info("TMR", $sformatf("ok   %s = %0h", what, got), UVM_NONE)
  endfunction

  task run_phase(uvm_phase phase);
    axi_reg_block  ral;
    uvm_status_e   st;
    uvm_reg_data_t v;
    phase.raise_objection(this);
    ral = env.sb.ral;
    wait (vif.aresetn === 1'b1);
    repeat (3) @(posedge vif.aclk);     // 2-FF switch synchronizer needs 2 clocks

    // ---- Case 0: switch input and LED output pins ----
    ral.sw_in.read(st, v);          chk("SW_IN = switch pins",   v, 16'hBEEF);
    ral.led_out.write(st, 'hA5A5);  chk("led pins follow LED_OUT", vif.led, 16'hA5A5);

    // ---- Case 1: one-shot timer ----
    ral.tmr_load.write(st, 20);     // count to 20
    ral.irq_en.write(st, 1);        // allow the interrupt
    ral.tmr_ctrl.write(st, 'b01);   // EN=1, AUTO=0
    repeat (40) @(posedge vif.aclk);
    ral.tmr_status.read(st, v);     chk("one-shot: DONE set",       v, 1);
    chk("one-shot: irq pin high", vif.irq, 1);
    ral.tmr_ctrl.read(st, v);       chk("one-shot: EN cleared",     v, 0);
    ral.tmr_count.read(st, v);      chk("one-shot: COUNT stays at LOAD", v, 20);

    // ---- Case 2: W1C (DONE=1 here): 0 keeps it, 1 clears it, irq follows ----
    ral.tmr_status.write(st, 0);   ral.tmr_status.read(st, v);   chk("W1C: write 0 keeps DONE", v, 1);
    ral.tmr_status.write(st, 1);   ral.tmr_status.read(st, v);   chk("W1C: write 1 clears DONE", v, 0);
    chk("W1C: irq pin low", vif.irq, 0);

    // ---- Case 3: auto-reload: DONE sets again and EN stays on ----
    ral.tmr_load.write(st, 10);
    ral.tmr_ctrl.write(st, 'b11);          // EN=1, AUTO=1
    repeat (30) @(posedge vif.aclk);
    ral.tmr_status.read(st, v);   chk("auto: DONE set", v, 1);
    ral.tmr_ctrl.read(st, v);     chk("auto: EN stays on", v, 'b11);

    // ---- Case 4: interrupt mask (DONE=1): irq = DONE & IRQ_EN ----
    ral.irq_en.write(st, 0);   chk("mask: irq pin low when irq_en=0",  vif.irq, 0);
    ral.irq_en.write(st, 1);   chk("mask: irq pin high when irq_en=1", vif.irq, 1);

    // ---- clean up: stop the timer, clear DONE ----
    ral.tmr_ctrl.write(st, 0);
    ral.tmr_status.write(st, 1);
    #100;
    phase.drop_objection(this);
  endtask

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("TMR", $sformatf("timer test: %0d checks, %0d failed", n_chk, n_fail), UVM_NONE)
  endfunction
endclass
