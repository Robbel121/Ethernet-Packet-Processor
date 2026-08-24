`timescale 1ns / 1ps

module MACAddyFilter(
    input logic clk,
    input logic rst_maf,
    input logic [47:0] dst_mac,// frame parser
    input logic parse_done, // frame parser
    input logic [47:0] allowed_mac,
    input logic all, // Link this to a switch on the FPGA
    
    output logic frame_pass,
    output logic frame_drop
    );
    
    localparam logic [47:0] BROADCAST = 48'hFFFFFFFFFFFF;
    
//    logic dst_lat;
//    logic allowed_lat;
    
    typedef enum logic [1:0]{
        IDLE, PASS, DROP
    } states_s;
    
    states_s state, next_state;
    
//    always@(posedge clk)begin
//        if(rst_maf)begin
//            dst_lat <= '0;
//            allowed_lat <= '0;
//        end else begin
//            dst_lat <= dst_mac;
//            allowed_lat <= allowed_mac;
//        end
//    end
    
    always_comb begin
        next_state = state;
        
        case(state)
            IDLE : begin
                if(parse_done)begin
                    if(dst_mac == allowed_mac || all || dst_mac == BROADCAST)begin
                        next_state = PASS; 
                    end else begin
                        next_state = DROP;
                    end
                end
            end
            
            PASS: begin
                next_state = IDLE;
            end
            
            DROP: begin
                next_state = IDLE;
            end
            default: begin next_state = IDLE; end
        endcase
    end
    
    always_ff@(posedge clk)begin
        if(rst_maf)begin
            state <= IDLE;
            frame_pass <= 1'b0;
            frame_drop <= 1'b0;
        end 
//        else begin
        
//            if (parse_done) begin
//            $display("T=%0t parse_done fired: dst=%h allowed=%h match=%b broadcast=%b all=%b next=%s",
//                $time,
//                dst_mac,
//                allowed_mac,
//                (dst_mac == allowed_mac),
//                (dst_mac == 48'hFFFFFFFFFFFF),
//                all,
//                next_state.name());
            
//            if (parse_done)
//             $display("T=%0t [MAF] parse_done received dst=%h allowed=%h match=%b",
//             $time, dst_mac, allowed_mac, (dst_mac == allowed_mac));
//        end
        
            state <= next_state;
            
            case(state)
                PASS: begin
                    frame_pass = 1'b1;
                    frame_drop = 1'b0;
                end
                
                DROP: begin
                    frame_pass = 1'b0;
                    frame_drop = 1'b1;
                end
                default: begin
                    frame_pass = 1'b0;
                    frame_drop = 1'b0;
                end
            endcase
        end
    
endmodule
