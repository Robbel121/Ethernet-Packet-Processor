`include "uvm_macros.svh"
import uvm_pkg::*;

class frame_len_env extends uvm_env;
    `uvm_component_utils(frame_len_env)
    
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
    
    frame_len_agent fla;
    
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        fla = frame_len_agent::type_id::create("fla", this);
    endfunction
endclass