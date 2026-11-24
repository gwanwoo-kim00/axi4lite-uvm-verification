// Adapter = translator between the register model and our bus item.
//   ral.led_out.write(st, 'hFF)  -->  reg2bus()  -->  axi_seq_item (is_write=1, addr=0x20, data=FF)
//   driver fills read data/resp  -->  bus2reg()  -->  value returned by ral.xxx.read(st, v)
class axi_reg_adapter extends uvm_reg_adapter;
  `uvm_object_utils(axi_reg_adapter)

  function new(string name = "axi_reg_adapter");
    super.new(name);
    supports_byte_enable = 0;   // register accesses always write the whole 32 bits
    provides_responses   = 0;   // our driver writes the result back into the same item
  endfunction

  virtual function uvm_sequence_item reg2bus(const ref uvm_reg_bus_op rw);
    axi_seq_item t = axi_seq_item::type_id::create("t");
    t.is_write = (rw.kind == UVM_WRITE);
    t.addr     = rw.addr;
    t.data     = rw.data;
    t.strb     = 4'hF;
    return t;
  endfunction

  virtual function void bus2reg(uvm_sequence_item bus_item, ref uvm_reg_bus_op rw);
    axi_seq_item t;
    if (!$cast(t, bus_item)) begin
      `uvm_fatal("ADP", "bus item is not an axi_seq_item")
      return;
    end
    rw.kind   = t.is_write ? UVM_WRITE : UVM_READ;
    rw.addr   = t.addr;
    rw.data   = t.data;
    rw.status = (t.resp == 2'b00) ? UVM_IS_OK : UVM_NOT_OK;
  endfunction
endclass
