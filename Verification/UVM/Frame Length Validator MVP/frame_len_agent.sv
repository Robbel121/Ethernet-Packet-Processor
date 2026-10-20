`include "uvm_macros.svh"
import uvm_pkg::*;

class frame_len_agent extends uvm_agent;
    
    `uvm_component_utils(frame_len_agent)
    
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
    
    frame_len_driver fldrv;
    frame_len_sequencer flsqr;
    frame_len_monitor flmon;
    
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(get_is_active() == UVM_ACTIVE)begin
            flsqr = frame_len_sequencer::type_id::create("flsqr",this);
            fldrv = frame_len_driver::type_id::create("fldrv",this);        
        end
        flmon = frame_len_monitor::type_id::create("flmon",this);        
    endfunction
    
    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        
        if(get_is_active() == UVM_ACTIVE)begin
            fldrv.seq_item_port.connect(flsqr.seq_item_export);   
        end
    endfunction
endclass