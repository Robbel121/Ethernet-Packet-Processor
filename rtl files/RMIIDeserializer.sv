`timescale 1ns / 1ps

module RMIIDeserializer(
    input logic phy_clk,
    input logic rst_ds,
    input logic [1:0] rmii_rxd,
    input logic rmii_dv,
    
    output logic [7:0] byte_out,
    output logic byte_valid,
    output logic frame_end
    );
    
    logic [7:0] shift_reg;
    logic prev_rmii_dv;
    logic [1:0] bit_count;
    
    always_ff@(posedge phy_clk)begin
        if(rst_ds)begin
            byte_out <= '0;
            byte_valid <= '0;
            frame_end <= '0;
            shift_reg <= '0;
            prev_rmii_dv <= '0;
            bit_count <= '0;
        end
        else begin
            byte_valid <= 1'b0;
            frame_end <= 1'b0;
            prev_rmii_dv <= rmii_dv;
            
            if(prev_rmii_dv && !rmii_dv)begin
                frame_end <= 1'b1;
            end
            
            if(rmii_dv)begin
                shift_reg <= {rmii_rxd, shift_reg[7:2]};
                bit_count <= bit_count + 1;
                
//                if (byte_valid)
//                    $display("T=%0t [DESER] byte_out=%h", $time, byte_out);
//                if (frame_end)
//                    $display("T=%0t [DESER] frame_end", $time);
                
                if(bit_count == 2'd3)begin
                    byte_out <= {rmii_rxd, shift_reg[7:2]};
                    byte_valid <= 1'b1;
                end
            end else begin
                bit_count <= '0;
            end
        end
    end
    
endmodule
