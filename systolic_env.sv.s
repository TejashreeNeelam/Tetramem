`include "uvm_macros.svh"
import uvm_pkg::*;
`include "common_types.sv"
`include "mat_tr.sv"

class systolic_env extends uvm_env;
    `uvm_component_utils(systolic_env)

    systolic_agent      sa;
    sub_sys_agent       ssa;
    systolic_scoreboard scb;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      sa  = systolic_agent     ::type_id::create("sa",  this);
      ssa = sub_sys_agent      ::type_id::create("ssa", this);
      scb = systolic_scoreboard::type_id::create("scb", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      sa.ap.connect(scb.exp_systolic);
      ssa.ap.connect(scb.exp_subsys);
    endfunction
  endclass