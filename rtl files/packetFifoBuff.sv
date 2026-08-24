`timescale 1ns / 1ps

module packetFifoBuff(
    input logic clk,
    input logic rst_fb,
    
    input logic byte_valid,
    input logic [7:0] payload_byte,    
    
    input logic frame_pass,
    input logic frame_drop,
    input logic frame_end,
    input logic rd_en,
    
    output logic [7:0] data_out,
    output logic empty,
    output logic full
    );
    
    localparam int DEPTH = 4096; // For 12 bit pointers
    
    logic [7:0] mem [0:DEPTH -1];
    logic [11:0] wr_ptr, rd_ptr, frame_start_ptr;
    logic frame_active;
    logic [7:0] data_out_reg;
    
    always_ff@(posedge clk) begin
        if(rst_fb)begin
            wr_ptr <= '0;
            rd_ptr <= '0;
            frame_start_ptr <= '0;
            frame_active <= 1'b0;
            data_out_reg <= '0;
        end else begin
            
            if(byte_valid && !frame_active)begin
                frame_start_ptr <= wr_ptr;
                frame_active <= 1'b1;
            end
            
            if(byte_valid && !full)begin
                mem[wr_ptr] <= payload_byte;
                wr_ptr <= wr_ptr + 1;
            end
                        
            if(frame_pass || frame_end)
                frame_active <= 1'b0;
                
            if(frame_drop)begin
                wr_ptr <= frame_start_ptr;
                frame_active <= 1'b0;
            end
                
            if(rd_en && !empty) begin
                data_out_reg <= mem[rd_ptr];
                rd_ptr <= rd_ptr + 1;
            end
        end
    end
        
    assign full = ((wr_ptr + 1) == rd_ptr);
    assign empty = (wr_ptr == rd_ptr);
    assign data_out = data_out_reg;
endmodule
