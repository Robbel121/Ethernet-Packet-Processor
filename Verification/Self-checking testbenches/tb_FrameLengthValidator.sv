`timescale 1ns / 1ps
module tb_frameLengthVal;

    logic clk, rst_flv;
    logic frame_pass, byte_valid, frame_end;
    logic len_pass, len_fail, frame_long, frame_short;

    frameLengthVal uut (
        .clk        (clk),
        .rst_flv    (rst_flv),
        .frame_pass (frame_pass),
        .byte_valid (byte_valid),
        .frame_end  (frame_end),
        .len_pass   (len_pass),
        .len_fail   (len_fail),
        .frame_long (frame_long),
        .frame_short(frame_short)
    );

    initial clk = 0;
    always #10 clk = ~clk;

    // Task: simulate a frame of n payload bytes
    // byte_count in DUT initializes to 14 (header bytes already consumed)
    // so passing n bytes here gives total count of 14+n
    task automatic send_frame(
        input int      num_bytes,
        input logic    expect_pass
    );
        int i;

        // Pulse frame_pass to start counting
        frame_pass = 1'b1;
        @(posedge clk); #1;
        frame_pass = 1'b0;

        // Stream num_bytes of payload
        byte_valid = 1'b1;
        for (i = 0; i < num_bytes; i++) begin
            @(posedge clk); #1;
        end
        byte_valid = 1'b0;

        // End the frame
        frame_end = 1'b1;
        @(posedge clk); #1;
        frame_end = 1'b0;

        // Wait for DECISION state to resolve
        @(posedge clk); #1;
        @(posedge clk); #1;

        // Check
        if (expect_pass) begin
            assert (len_pass == 1'b1 && len_fail == 1'b0)
                else $error("FAIL: expected len_pass for %0d bytes, got pass=%b fail=%b",
                            num_bytes + 14, len_pass, len_fail);
        end else begin
            assert (len_fail == 1'b1 && len_pass == 1'b0)
                else $error("FAIL: expected len_fail for %0d bytes, got pass=%b fail=%b",
                            num_bytes + 14, len_pass, len_fail);
        end

        // Gap between frames
        repeat(2) @(posedge clk);
    endtask

    initial begin
        rst_flv    = 1'b1;
        frame_pass = 1'b0;
        byte_valid = 1'b0;
        frame_end  = 1'b0;

        repeat(3) @(posedge clk);
        rst_flv = 1'b0;
        @(posedge clk); #1;

        // Test 1: minimum legal frame
        // 14 (header) + 46 (payload) = 60 bytes total - exact minimum
        $display("Test 1: minimum legal frame (60 bytes total)");
        send_frame(46, 1'b1);

        // Test 2: normal valid frame
        // 14 + 100 = 114 bytes
        $display("Test 2: normal valid frame (114 bytes total)");
        send_frame(100, 1'b1);

        // Test 3: maximum legal frame
        // 14 + 1500 = 1514 bytes - exact maximum
        $display("Test 3: maximum legal frame (1514 bytes total)");
        send_frame(1500, 1'b1);

        // Test 4: undersized frame - should fail
        // 14 + 20 = 34 bytes, below 60 minimum
        $display("Test 4: undersized frame (34 bytes total)");
        send_frame(20, 1'b0);

        // Test 5: oversized frame - should fail
        // 14 + 1510 = 1524 bytes, above 1514 maximum
        $display("Test 5: oversized frame (1524 bytes total)");
        send_frame(1510, 1'b0);

        // Test 6: one byte below minimum - boundary check
        // 14 + 45 = 59 bytes
        $display("Test 6: one byte below minimum (59 bytes total)");
        send_frame(45, 1'b0);

        // Test 7: one byte above maximum - boundary check
        // 14 + 1501 = 1515 bytes
        $display("Test 7: one byte above maximum (1515 bytes total)");
        send_frame(1501, 1'b0);

        // Test 8: fail then pass - confirm IDLE recovery
        $display("Test 8: undersized then valid (IDLE recovery)");
        send_frame(10, 1'b0);
        send_frame(100, 1'b1);

        $display("Smoke test complete.");
        $finish;
    end

endmodule