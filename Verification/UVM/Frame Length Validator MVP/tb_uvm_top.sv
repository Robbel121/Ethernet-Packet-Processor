`include "uvm_macros.svh"
import uvm_pkg::*;

module tb_uvm_top;
    bit clk_50M;
    always #10 clk_50M = ~clk_50M;    

    frame_len_interface flif(.clk_50M(clk_50M));

    frameLengthVal dut (
        .clk(clk_50M),
        .rst_flv(flif.rst_flv),
        .frame_pass(flif.frame_pass),
        .byte_valid(flif.byte_valid),
        .frame_end(flif.frame_end),
        .len_pass(flif.len_pass),
        .len_fail(flif.len_fail),
        .frame_long(flif.frame_long),
        .frame_short(flif.frame_short)
    );

    initial begin
        // Set frame_len_if to flif, hace this set everywhere since * is used, start at this file(null) 
        uvm_config_db#(virtual frame_len_interface)::set(null, "*", "frame_len_if", flif);
        run_test("frame_len_test");
        $finish;
    end    

endmodule