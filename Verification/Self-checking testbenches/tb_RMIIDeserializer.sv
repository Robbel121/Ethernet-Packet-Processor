`timescale 1ns / 1ps
module tb_RMIIDeserializer;
    logic phy_clk, rst_ds;
    logic rmii_dv;
    logic [1:0] rmii_rxd;
    
    logic [7:0] byte_out;
    logic byte_valid, frame_end;
    
    logic [7:0] test_frames [] = '{
        8'hAA, 8'hAA, 8'hAA, 8'hAA,   
        8'hAA, 8'hAA, 8'hAA,           // preamble
        8'hD5,                         // For SFD detection
        8'hDE                          // First data
     };
    
    RMIIDeserializer uut(.phy_clk(phy_clk), 
    .rst_ds(rst_ds), .rmii_dv(rmii_dv), .rmii_rxd(rmii_rxd),
    .byte_out(byte_out), .byte_valid(byte_valid), 
    .frame_end(frame_end));
    
    initial phy_clk = 1'b0;
    always #10 phy_clk = ~phy_clk;
    
    task automatic send_byte_rmii(input logic [7:0] byte_in);
        rmii_rxd = byte_in[1:0]; // RMII is LSB first
        @(posedge phy_clk); #1;
        
        rmii_rxd = byte_in[3:2];
        @(posedge phy_clk); #1;
        
        rmii_rxd = byte_in[5:4];
        @(posedge phy_clk); #1;
        
        rmii_rxd = byte_in[7:6];
        @(posedge phy_clk); #1;
    endtask

    task automatic send_frame_rmii(input logic [7:0] data [], input int num_bytes);
        int i;
        
        rmii_dv = 1'b1;
        
        for(i = 0; i < num_bytes ; i++)begin
            send_byte_rmii(data[i]);
        end
        
        rmii_dv = 1'b0;
        rmii_rxd = 2'b00;
        @(posedge phy_clk); #1;
        
     endtask 
        
     initial begin
     
     rst_ds = 1'b1;
     rmii_dv = 1'b0;
     rmii_rxd = 2'b00;
     @(posedge phy_clk);#1;
     @(posedge phy_clk);#1;
     
     rst_ds = 1'b0;
     @(posedge phy_clk);#1;
     @(posedge phy_clk);#1;
     
     send_frame_rmii(test_frames, test_frames.size());
     
     repeat(3)@(posedge phy_clk); #1;
     assert(byte_out == 8'hDE)
        else $error("FAIL : byte out = %h, expected DE",byte_out);
     assert(byte_valid == 1'b0)
        else $error("FAIL: byte is valid/1");
        
   // Test 2: frame_end pulses after CRS_DV drops
     $display("Test 2: frame_end pulse check");
     send_frame_rmii(test_frames, test_frames.size());
        // frame_end should pulse the cycle after rmii_dv drops
     @(posedge phy_clk); #1;
     assert (frame_end == 1'b1)
         else $error("FAIL: frame_end did not pulse after CRS_DV drop");
     @(posedge phy_clk); #1;
     assert (frame_end == 1'b0)
         else $error("FAIL: frame_end stayed high, expected one-cycle pulse");

        // Test 3: back to back frames - confirm dibit_cnt resets
     $display("Test 3: back to back frames");
     send_frame_rmii(test_frames, test_frames.size());
     @(posedge phy_clk); #1;
     send_frame_rmii(test_frames, test_frames.size());
     repeat(3) @(posedge phy_clk); #1;
     assert (byte_out == 8'hDE)
         else $error("FAIL: byte_out=%h on second frame, expected DE", byte_out);

     $display("Smoke test complete.");
     $finish;     
        
     end
       
       
endmodule