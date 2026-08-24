`timescale 1ns / 1ps
module frameParse(
    input logic clk,
    input logic rst_fp,
    input logic byte_v,
    input logic [7:0] byte_in,
    input logic frame_end,
    
    output logic [47:0] dst_mac,
    output logic [47:0] src_mac,
    output logic [15:0] ether_type,
    output logic payload_v,
    output logic [7:0] payload_byte,
    output logic frame_err,
    output logic parse_done
    );
    
    //Parser FSM
    typedef enum logic [2:0]{
        IDLE, PREAMBLE, SFD, HEAD, PAYLOAD, ERR
    } state_s;
    
    state_s state, next_state; 
    
    //Used to identify states
    logic [3:0] byte_count;
    
    //shift regs for MAC address
    logic [47:0] dst_mac_reg, src_mac_reg;
    logic [15:0] ether_type_reg;
    
    
    //reset
    always_comb begin
       next_state = state;
       
       case(state)
        IDLE: begin
            if(byte_v && byte_in == 8'hAA)
                next_state = PREAMBLE;
            end
            
        PREAMBLE: begin
                if(byte_v)begin
                    if(byte_in == 8'hAA)
                        next_state = PREAMBLE;
                    else if(byte_in == 8'hD5 && byte_count == 4'd7)
                        next_state = SFD;
                    else
                        next_state = ERR;
                end
            end
            
        SFD : begin
            next_state = HEAD;
            end
            
        HEAD : begin
            if(byte_v && byte_count == 4'd13)
                next_state = PAYLOAD;
            end
            
        PAYLOAD : begin
                if(frame_end)
                    next_state = IDLE;
            end
            
        ERR : begin
                next_state = IDLE;
            end
       
        default: next_state = IDLE;
       
       endcase
    end
    
    always_ff@(posedge clk)begin
        
//        if (byte_v)
//            $display("T=%0t [PARSE] state=%s byte_in=%h byte_count=%0d",
//             $time, state.name(), byte_in, byte_count);
//        if (parse_done)
//            $display("T=%0t [PARSE] parse_done! dst=%h src=%h etype=%h",
//             $time, dst_mac, src_mac, ether_type);
//        if (frame_err)
//            $display("T=%0t [PARSE] frame_err state=%s", $time, state.name());
        
        if(rst_fp)begin
            state          <= IDLE;
            byte_count     <= '0;
            dst_mac_reg    <= '0;
            src_mac_reg    <= '0;
            ether_type_reg <= '0;
            dst_mac        <= '0;
            src_mac        <= '0;
            ether_type     <= '0;
            payload_v      <= 1'b0;
            payload_byte   <= '0;
            frame_err      <= 1'b0;
            parse_done     <= 1'b0;
        end else begin
        
        frame_err <= 1'b0;
        parse_done <= 1'b0;
        payload_v <= 1'b0;
       
        state <= next_state;
        
            case(state)
            
                IDLE: begin
                    byte_count <= '0;
                    if(byte_v && byte_in == 8'hAA)
                        byte_count <= 4'd1;
                end
            
                PREAMBLE: begin
                    if(byte_v)begin
                        if(byte_in == 8'hAA)
                            byte_count <= byte_count + 1;
                        else if(byte_in == 8'hD5 && byte_count == 4'd7)
                            byte_count <= '0;
                    end
                end
            
                SFD : begin
                    byte_count <= '0;
                end
            
                HEAD : begin
                    if(byte_v)begin
                        //Destination MAC address
                        if(byte_count <= 4'd5)
                            dst_mac_reg <= {dst_mac_reg[39:0], byte_in};
                        //Source MAC address
                        else if(byte_count <= 4'd11)
                            src_mac_reg <= {src_mac_reg[39:0], byte_in};
                        else if(byte_count <= 4'd13)
                            ether_type_reg <= {ether_type_reg[7:0], byte_in};
                        
                        if(byte_count == 4'd13)begin
                            dst_mac <= dst_mac_reg;
                            src_mac <= src_mac_reg;
                            ether_type <= {ether_type_reg[7:0], byte_in};
                            parse_done <= 1'b1;
                        end
                        
                        byte_count <= byte_count + 1;
                    end
                end
            
                PAYLOAD : begin
                    if(byte_v)begin
                        payload_v <= 1'b1;
                        payload_byte <= byte_in;
                    end
                end
            
                ERR : begin
                    frame_err <= 1'b1;
                    byte_count <= '0;
                end
            endcase
       end
    end
    
endmodule
