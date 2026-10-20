`include "uvm_macros.svh"
import uvm_pkg::*;

class frame_len_test extends uvm_test;
    `uvm_component_utils(frame_len_test)
    
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
    
    frame_len_env flenv;
    frame_len_sequence flseq;
    
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        flenv = frame_len_env::type_id::create("flenv", this);
    endfunction
    
    task run_phase(uvm_phase phase);
        flseq = frame_len_sequence::type_id::create("flseq", this);        
        phase.raise_objection(this);
        `uvm_info("MVP_CHECK", $sformatf("Starting sequence with 16 runs"), UVM_LOW)
        flseq.start(flenv.fla.flsqr);
        phase.drop_objection(this);
    endtask
    
endclass
