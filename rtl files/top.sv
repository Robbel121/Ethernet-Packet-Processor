`timescale 1ns / 1ps

module top(input logic clk_100M,
    input logic reset, // assign to switch
    
    input logic [1:0] rmii_rxd,
    input logic rmii_dv,
    input logic phy_clk,
    input logic all_mode, // use to allow all frames to pass
    
    output logic led_frame_pass,
    output logic led_frame_drop,
    output logic led_len_pass,
    output logic led_len_fail,
    output logic led_frame_err,
    output logic locked
);
    //From clocking wizard, used for every module
    logic clk_50M;
    
    //For RMII Deserializer
    (* mark_debug = "true" *) logic [7:0] byte_out;
    (* mark_debug = "true" *) logic byte_valid;
    (* mark_debug = "true" *) logic frame_end;
    (* mark_debug = "true", dont_touch = "true" *) logic rmii_rxd_internal;
    (* mark_debug = "true", dont_touch = "true" *) logic rmii_dv_internal;

    assign rmii_dv_internal = rmii_dv;
    assign rmii_rxd_internal = rmii_rxd;

    //For frame parser
    (* mark_debug = "true" *) logic [47:0] dst_mac;
    logic [47:0] src_mac;
    logic [15:0] ether_type;
    logic payload_valid;
    (* mark_debug = "true" *) logic frame_err;
    logic [7:0] payload;
    (* mark_debug = "true" *) logic parse_done;
    
    //For MAC address filter
    localparam logic [47:0] ALLOWED_MAC = 48'hAABBCCDDEEFF;
    (* mark_debug = "true" *) logic frame_pass;
    (* mark_debug = "true" *) logic frame_drop;
    
    
    //For frame length validator
    (* mark_debug = "true" *) logic len_pass, len_fail;
    logic frame_long, frame_short;
    
    //For fifo buffer
    logic rd_en;
    logic [7:0] output_data;
    (* mark_debug = "true" *) logic empty, full;
    
    assign rd_en = 1'b0; //Have low until UART controller added
    
    packpro_wrapper clk_divider(.clk(clk_100M), .clk_out(clk_50M), .rst(reset), .locked_0(locked));
    
    RMIIDeserializer Deserializer(.phy_clk(clk_50M), .rst_ds(reset), 
    .rmii_rxd(rmii_rxd), .rmii_dv(rmii_dv), .byte_out(byte_out), 
    .byte_valid(byte_valid), .frame_end(frame_end));
    
    frameParse parser(.clk(clk_50M), .rst_fp(reset), .byte_v(byte_valid),
     .byte_in(byte_out), .frame_end(frame_end), .dst_mac(dst_mac), 
     .src_mac(src_mac), .ether_type(ether_type), .payload_v(payload_valid),
      .payload_byte(payload), .frame_err(frame_err), .parse_done(parse_done));
     
    MACAddyFilter AddressFilter(.clk(clk_50M), .rst_maf(reset), .dst_mac(dst_mac), 
    .parse_done(parse_done), .allowed_mac(ALLOWED_MAC), .all(all_mode), 
    .frame_pass(frame_pass), .frame_drop(frame_drop));
     
    frameLengthVal frameValidator(.clk(clk_50M), .rst_flv(reset), 
    .frame_pass(frame_pass), .byte_valid(byte_valid), .frame_end(frame_end), 
    .len_pass(len_pass), .len_fail(len_fail), .frame_long(frame_long), 
    .frame_short(frame_short));
     
    packetFifoBuff bufferRegiser(.clk(clk_50M), .rst_fb(reset), .byte_valid(byte_valid), 
    .payload_byte(payload), .frame_pass(frame_pass), 
    .frame_drop(frame_drop), .frame_end(frame_end), 
    .rd_en(rd_en), .data_out(output_data), .empty(empty), .full(full));
    
    always_ff@(posedge clk_50M)begin
        if(reset)begin
            led_frame_err <= 1'b0;
            led_frame_pass <= 1'b0;
            led_frame_drop <= 1'b0;
            led_len_pass <= 1'b0;
            led_len_fail <= 1'b0;
        end else begin
            led_frame_err <= frame_err;
            led_frame_pass <= frame_pass;
            led_frame_drop <= frame_drop;
            led_len_pass <= len_pass;
            led_len_fail <= len_fail;
        end
    end
    
endmodule
