`include "uvm_macros.svh"
import uvm_pkg::*;
`include "mat_tr.sv"

 class mat_seq extends uvm_sequence #(mat_tr);
    `uvm_object_utils(mat_seq)

    function new(string name="mat_seq");
      super.new(name);
    endfunction

    virtual task body();
      mat_tr tr;
      repeat (10) begin
        tr = mat_tr::type_id::create("tr");
        if (!tr.randomize())
          `uvm_error(get_type_name(), "Randomization failed")
        start_item(tr);
        finish_item(tr);
      end
    endtask
  endclass