`include "uvm_macros.svh"
import uvm_pkg::*;

class frame_len_sequence extends uvm_sequence #(frame_len_seq_item);
    
    `uvm_object_utils(frame_len_sequence)
        
    function new(string name = "frame_len_sequence");
        super.new(name);
    endfunction
    
    task body();
        frame_len_seq_item item;
        int target_len;
        int bytes_sent;
       
        repeat (16) begin
            target_len = $urandom_range(0, 1500);
            bytes_sent = 0;
            item = frame_len_seq_item::type_id::create("item");
            start_item(item);
            item.frame_pass = 1;
            item.byte_valid = 0;
            item.frame_end  = 0;
            finish_item(item);
            
            while (bytes_sent < target_len) begin
                item = frame_len_seq_item::type_id::create("item");
                start_item(item);
                item.frame_pass = 0;
                item.frame_end  = 0;
                assert(item.randomize()); 
                finish_item(item);
                if (item.byte_valid) bytes_sent++;
            end

            item = frame_len_seq_item::type_id::create("item");
            start_item(item);
            item.frame_pass = 0;
            item.byte_valid = 0;
            item.frame_end  = 1;
            finish_item(item);
            // Bubble cycle
            item = frame_len_seq_item::type_id::create("item");
            start_item(item);
            item.frame_pass = 0;
            item.byte_valid = 0;
            item.frame_end  = 0;
            finish_item(item);
        end
    endtask
endclass