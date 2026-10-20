`include "uvm_macros.svh"
import uvm_pkg::*;

class frame_len_sequencer extends uvm_sequencer #(frame_len_seq_item);
    
    `uvm_component_utils(frame_len_sequencer)
    
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

endclass   
