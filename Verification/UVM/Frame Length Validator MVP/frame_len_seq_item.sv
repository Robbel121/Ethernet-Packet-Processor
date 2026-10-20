`include "uvm_macros.svh"
import uvm_pkg::*;

class frame_len_seq_item extends uvm_sequence_item;
    //Input
    bit rst_flv;
    bit frame_pass;
    rand bit byte_valid; 
    bit frame_end; 
     //Output
    bit len_pass;
    bit len_fail;
    bit frame_long;
    bit frame_short;

    // Constraint needed(I was wrong :()
    constraint no_random_reset { rst_flv == 0; }

    `uvm_object_utils_begin(frame_len_seq_item)
        `uvm_field_int(rst_flv,  UVM_ALL_ON)
        `uvm_field_int(frame_pass,  UVM_ALL_ON)
        `uvm_field_int(byte_valid,   UVM_ALL_ON)
        `uvm_field_int(frame_end,  UVM_ALL_ON)
        `uvm_field_int(len_pass,  UVM_ALL_ON)
        `uvm_field_int(len_fail,  UVM_ALL_ON)
        `uvm_field_int(frame_long,  UVM_ALL_ON)
        `uvm_field_int(frame_short,  UVM_ALL_ON)
    `uvm_object_utils_end
  
  
    function new(string name = "frame_len_seq_item");
        super.new(name);
        rst_flv =0;  
        frame_pass=0;
        frame_end=0;
    endfunction

endclass