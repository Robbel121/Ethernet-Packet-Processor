`timescale 1ns / 1ps
module tb_frameParse;

    logic        clk, rst_fp;
    logic        byte_v, frame_end;
    logic [7:0]  byte_in;
    logic [47:0] dst_mac, src_mac;
    logic [15:0] ether_type;
    logic        payload_v, frame_err, parse_done;
    logic [7:0]  payload_byte;

    frameParse uut (
        .clk         (clk),
        .rst_fp      (rst_fp),
        .byte_v      (byte_v),
        .byte_in     (byte_in),
        .frame_end   (frame_end),
        .dst_mac     (dst_mac),
        .src_mac     (src_mac),
        .ether_type  (ether_type),
        .payload_v   (payload_v),
        .payload_byte(payload_byte),
        .frame_err   (frame_err),
        .parse_done  (parse_done)
    );

    initial clk = 0;
    always #10 clk = ~clk;

    // Task: send one byte into the parser
    task automatic send_byte(input logic [7:0] data);
        byte_in = data;
        byte_v  = 1'b1;
        @(posedge clk); #1;
        byte_v  = 1'b0;
        @(posedge clk); #1;
    endtask

    // Task: send a complete valid Ethernet frame header + n payload bytes
    // Builds: 7x preamble, SFD, dst MAC, src MAC, EtherType, payload
    task automatic send_frame(
        input logic [47:0] dst,
        input logic [47:0] src,
        input logic [15:0] etype,
        input int          payload_len,
        input logic        expect_err
    );
        int i;

        // Preamble: 7 bytes of 0xAA
        for (i = 0; i < 7; i++)
            send_byte(8'hAA);

        // SFD
        send_byte(8'hD5);

        // Destination MAC (MSB first)
        for (i = 5; i >= 0; i--)
            send_byte(dst[i*8 +: 8]);

        // Source MAC (MSB first)
        for (i = 5; i >= 0; i--)
            send_byte(src[i*8 +: 8]);

        // EtherType (2 bytes, MSB first)
        send_byte(etype[15:8]);
        send_byte(etype[7:0]);

        // Payload bytes (fill with 0xAB pattern)
        for (i = 0; i < payload_len; i++)
            send_byte(8'hD5);

        // End of frame
        frame_end = 1'b1;
        @(posedge clk); #1;
        frame_end = 1'b0;

        // Wait for outputs to settle
        repeat(3) @(posedge clk);

        // Check error flag
        if (expect_err) begin
            assert (frame_err == 1'b1)
                else $error("FAIL: expected frame_err, got err=%b", frame_err);
        end else begin
            assert (frame_err == 1'b0)
                else $error("FAIL: unexpected frame_err asserted");
        end
    endtask

    initial begin
        rst_fp     = 1'b1;
        byte_v     = 1'b0;
        byte_in    = 8'h00;
        frame_end  = 1'b0;

        repeat(3) @(posedge clk);
        rst_fp = 1'b0;
        @(posedge clk); #1;

        // Test 1: valid frame, check dst_mac parsed correctly
        $display("Test 1: valid frame - dst MAC extraction");
        send_frame(
            48'hAABBCCDDEEFF,  // dst
            48'h112233445566,  // src
            16'h0800,          // EtherType: IPv4
            46,                // payload bytes
            1'b0               // expect no error
        );
        assert (dst_mac == 48'hAABBCCDDEEFF)
            else $error("FAIL: dst_mac=%h, expected aabbccddeeff", dst_mac);
        assert (src_mac == 48'h112233445566)
            else $error("FAIL: src_mac=%h, expected 112233445566", src_mac);
        assert (ether_type == 16'h0800)
            else $error("FAIL: ether_type=%h, expected 0800", ether_type);

        // Test 2: broadcast dst MAC
        $display("Test 2: broadcast dst MAC");
        send_frame(
            48'hFFFFFFFFFFFF,
            48'h112233445566,
            16'h0806,          // EtherType: ARP
            46,
            1'b0
        );
        assert (dst_mac == 48'hFFFFFFFFFFFF)
            else $error("FAIL: dst_mac=%h, expected ffffffffffff", dst_mac);

        // Test 3: bad preamble byte - expect frame_err
        $display("Test 3: corrupted preamble");
        send_byte(8'hAA);  // valid first preamble byte
        send_byte(8'hBB);  // corrupted - should trigger ERR state
        repeat(5) @(posedge clk);
        assert (frame_err == 1'b1)
            else $error("FAIL: expected frame_err on bad preamble");
        frame_end = 1'b1;
        @(posedge clk); #1;
        frame_end = 1'b0;
        repeat(2) @(posedge clk);

        // Test 4: bad SFD byte - expect frame_err
        $display("Test 4: corrupted SFD");
        for (int i = 0; i < 7; i++)
            send_byte(8'hAA);
        send_byte(8'hCC);  // wrong SFD
        repeat(3) @(posedge clk);
        assert (frame_err == 1'b1)
            else $error("FAIL: expected frame_err on bad SFD");
        frame_end = 1'b1;
        @(posedge clk); #1;
        frame_end = 1'b0;
        repeat(2) @(posedge clk);

        // Test 5: valid frame after error - confirm recovery to IDLE
        $display("Test 5: valid frame after error (IDLE recovery)");
        send_frame(
            48'hAABBCCDDEEFF,
            48'h112233445566,
            16'h0800,
            46,
            1'b0
        );
        assert (dst_mac == 48'hAABBCCDDEEFF)
            else $error("FAIL: dst_mac=%h after recovery, expected aabbccddeeff", dst_mac);

        // Test 6: parse_done pulses exactly once per valid frame
        $display("Test 6: parse_done pulse check");
        send_frame(
            48'hAABBCCDDEEFF,
            48'h112233445566,
            16'h0800,
            46,
            1'b0
        );
        // parse_done should already be 0 by now (one-cycle pulse)
        assert (parse_done == 1'b0)
            else $error("FAIL: parse_done still high after frame, should be one-cycle pulse");

        $display("Smoke test complete.");
        $finish;
    end

endmodule
