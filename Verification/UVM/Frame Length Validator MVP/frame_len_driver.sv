`include "uvm_macros.svh"
import uvm_pkg::*;

class frame_len_driver extends uvm_driver #(frame_len_seq_item);

    `uvm_component_utils(frame_len_driver)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
    
    virtual frame_len_interface frame_len_if;
    
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(virtual frame_len_interface)::get(this, "", "frame_len_if", frame_len_if))begin
            `uvm_fatal(get_type_name(),"No virtual interface found")
        end
    endfunction
    
    // No connect phase since that will happen in UVM top
    
    virtual task run_phase(uvm_phase phase);
        frame_len_seq_item flsi;
        
        frame_len_if.drv_cb.rst_flv    <= 1'b1;
        frame_len_if.drv_cb.frame_pass <= 1'b0;
        frame_len_if.drv_cb.byte_valid <= 1'b0;
        frame_len_if.drv_cb.frame_end  <= 1'b0;
        repeat (2) @(frame_len_if.drv_cb);
        frame_len_if.drv_cb.rst_flv <= 1'b0;
        @(frame_len_if.drv_cb);
        
        forever begin
            seq_item_port.get_next_item(flsi);
            frame_len_if.drv_cb.rst_flv <= flsi.rst_flv;  
            frame_len_if.drv_cb.frame_pass <= flsi.frame_pass;
            frame_len_if.drv_cb.byte_valid <= flsi.byte_valid;
            frame_len_if.drv_cb.frame_end <= flsi.frame_end;
            @(frame_len_if.drv_cb);
            seq_item_port.item_done();       
        end
    endtask

endclass