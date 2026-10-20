`include "uvm_macros.svh"
import uvm_pkg::*;

class frame_len_monitor extends uvm_monitor;

    `uvm_component_utils(frame_len_monitor)
    
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
    
    virtual frame_len_interface frame_len_if;
    
    uvm_analysis_port #(frame_len_seq_item) analysis_port;
    
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        analysis_port = new("analysis_port", this);
        
        // Fatal because I will be using a scoreboard in the non-MVP implementation
        if(!uvm_config_db#(virtual frame_len_interface)::get(this, "", "frame_len_if", frame_len_if))begin
            `uvm_fatal(get_type_name(), "No virtual interface detected")
        end
    endfunction
    

    function void check_result(frame_len_seq_item flsi, int unsigned actual_len);
        bit exp_len_pass, exp_len_fail, exp_frame_long, exp_frame_short;
    
        exp_frame_short = (actual_len < 60);
        exp_frame_long  = (actual_len > 1514);
        exp_len_fail    = exp_frame_short || exp_frame_long;
        exp_len_pass    = !exp_len_fail;
    
        if (flsi.len_pass !== exp_len_pass || flsi.len_fail !== exp_len_fail ||
            flsi.frame_long !== exp_frame_long || flsi.frame_short !== exp_frame_short)
            `uvm_error("CHECK", $sformatf("No match | len=%0d exp(pass=%0b fail=%0b) act(pass=%0b fail=%0b)",
                        actual_len, exp_len_pass, exp_len_fail, flsi.len_pass, flsi.len_fail))
        else
            `uvm_info("CHECK", $sformatf("Pas | len=%0d", actual_len), UVM_LOW)
    endfunction
    
    virtual task run_phase(uvm_phase phase);
        frame_len_seq_item flsi;
        int unsigned byte_count = 0;

        forever begin
            @(frame_len_if.mon_cb);
            
            if (frame_len_if.mon_cb.rst_flv) begin
                byte_count = 0;
            end
            else if (frame_len_if.mon_cb.byte_valid) begin
                byte_count++;
            end
    
            if (frame_len_if.mon_cb.frame_end) begin
                int unsigned captured_len = byte_count +14;
                @(frame_len_if.mon_cb);
                flsi = frame_len_seq_item::type_id::create("flsi", this);
                flsi.len_pass    = frame_len_if.mon_cb.len_pass;
                flsi.len_fail    = frame_len_if.mon_cb.len_fail;
                flsi.frame_long  = frame_len_if.mon_cb.frame_long;
                flsi.frame_short = frame_len_if.mon_cb.frame_short;
    
                check_result(flsi, captured_len);   // pass the counted length in directly
                analysis_port.write(flsi);
    
                byte_count = 0;   // reset for next frame
            end
        end
    endtask
endclass