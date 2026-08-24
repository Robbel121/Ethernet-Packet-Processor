`timescale 1ns / 1ps
// frame_short and frame_long stay triggered once activated
module frameLengthVal(
    input logic clk,
    input logic rst_flv,
    
    input logic frame_pass, // MAC Filter signal
    input logic byte_valid, // rmii deserializer
    input logic frame_end,  // also rmii deserializer
    
    output logic len_pass,
    output logic len_fail,
    output logic frame_long,
    output logic frame_short
    );
    // Use for each verified part of our ethernet frame.
    
    localparam int MIN_BYTES = 60; //FCS not coutned in either
    localparam int MAX_BYTES = 1514;
    
    logic [10:0] byte_count;
    
    logic frame_long_r, frame_short_r;
    
    typedef enum logic [1:0]{
    IDLE, COUNTING, DECISION 
    }state_s;
    
    state_s state, next_state;
    
    always_comb begin
        next_state = state;
        
        case(state)
            IDLE : begin
                if(frame_pass)
                    next_state = COUNTING;
            end
            
            COUNTING: begin
                     
                if(byte_count > MAX_BYTES && !frame_end)begin
                    frame_long = 1'b1;
                    next_state = DECISION;   
                end else if(frame_end)begin
                    if(byte_count < MIN_BYTES)
                        frame_short = 1'b1;
                    next_state = DECISION;
                end
            end
            
            DECISION: begin
    
                if(byte_count >= MIN_BYTES && byte_count <= MAX_BYTES)begin
                    len_pass = 1'b1;
                    len_fail = 1'b0;
                end else begin
                    len_pass = 1'b0;
                    len_fail = 1'b1;
                end
                next_state = IDLE;
            end
            
            default: begin next_state = IDLE; end
            
        endcase
    end
    
    always_ff@(posedge clk)begin
    
//        if (state != next_state)
//            $display("T=%0t [LEN] state %s -> %s", $time, state.name(), next_state.name());
        
//        if (frame_pass)
//            $display("T=%0t [LEN] frame_pass received, starting count from %0d",
//             $time, byte_count);
//        if (len_pass)
//            $display("T=%0t [LEN] len_pass! byte_count=%0d", $time, byte_count);
//        if (len_fail)
//            $display("T=%0t [LEN] len_fail! byte_count=%0d", $time, byte_count);
        
        if(rst_flv)begin
            state <= IDLE;
            len_pass <= 1'b0; 
            len_fail <= 1'b0; 
            frame_long <= 1'b0;
            frame_short <= 1'b0;
            byte_count <= '0;
        end else begin
            state <= next_state;
            
            if(frame_long)  frame_long_r  <= 1'b1;
            if(frame_short) frame_short_r <= 1'b1;

            if(next_state == IDLE) begin
                frame_long_r  <= 1'b0;
                frame_short_r <= 1'b0;
            end
            
            case(state)
                IDLE : begin
                    byte_count <= 11'd14;
                end
                
                COUNTING: begin
                    if(byte_valid && !frame_end && byte_count <= MAX_BYTES)
                        byte_count <= byte_count + 1;
                end
                
                DECISION: begin
//                    $display("T=%0t [LEN] DECISION byte_count=%0d min=%0d max=%0d",
//                    $time, byte_count, MIN_BYTES, MAX_BYTES);
                
                    byte_count <= '0;
                end
            endcase
         end
    end
    
endmodule
