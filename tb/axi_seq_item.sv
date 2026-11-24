// One AXI4-Lite transaction (a single write or a single read)
class axi_seq_item extends uvm_sequence_item;

  rand bit          is_write;   // 1 = write, 0 = read
  rand bit [31:0]   addr;
  rand bit [31:0]   data;       // write data (for read: filled with read result)
  rand bit [3:0]    strb;       // write byte strobe
  rand int unsigned aw_dly;     // cycles before AWVALID
  rand int unsigned w_dly;      // cycles before WVALID
  rand int unsigned b_dly;      // cycles before BREADY (back-pressure)
  rand int unsigned r_dly;      // cycles before RREADY (back-pressure)
  bit  [1:0]        resp;       // BRESP or RRESP observed

  // 4-byte aligned; mostly valid addresses, sometimes invalid ones
  constraint c_addr {
    addr[1:0] == 2'b00;
    addr dist { [32'h00:32'h3C] :/ 90, [32'h40:32'h7C] :/ 10 };
  }
  constraint c_dly {
    aw_dly inside {[0:3]};  w_dly inside {[0:3]};
    b_dly  inside {[0:4]};  r_dly inside {[0:4]};
  }

  `uvm_object_utils_begin(axi_seq_item)
    `uvm_field_int(is_write, UVM_ALL_ON)
    `uvm_field_int(addr,     UVM_ALL_ON | UVM_HEX)
    `uvm_field_int(data,     UVM_ALL_ON | UVM_HEX)
    `uvm_field_int(strb,     UVM_ALL_ON | UVM_BIN)
    `uvm_field_int(resp,     UVM_ALL_ON)
  `uvm_object_utils_end

  function new(string name = "axi_seq_item");
    super.new(name);
  endfunction

endclass
