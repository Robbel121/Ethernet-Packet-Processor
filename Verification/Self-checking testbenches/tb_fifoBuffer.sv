`timescale 1ns/ 1ps
module tb_fifoBuffer;

    logic        clk, rst_fb;
    logic        byte_valid, frame_pass, frame_drop, frame_end;
    logic [7:0]  payload_byte;
    logic        rd_en;
    logic [7:0]  data_out;
    logic        empty, full;

    packetFifoBuff uut(
        .clk          (clk),
        .rst_fb       (rst_fb),
        .byte_valid   (byte_valid),
        .payload_byte (payload_byte),
        .frame_pass   (frame_pass),
        .frame_drop   (frame_drop),
        .frame_end    (frame_end),
        .rd_en        (rd_en),
        .data_out     (data_out),
        .empty        (empty),
        .full         (full)
    );

    initial clk = 0;
    always #10 clk = ~clk;

    // write one byte into FIFO
    task automatic write_byte(input logic [7:0] data);
        payload_byte = data;
        byte_valid   = 1'b1;
        @(posedge clk); #1;
        byte_valid   = 1'b0;
        @(posedge clk); #1;
    endtask

    // read one byte out of FIFO
    task automatic read_byte(output logic [7:0] data);
        rd_en = 1'b1;
        @(posedge clk); #1;
        rd_en = 1'b0;
        data  = data_out;
        @(posedge clk); #1;
    endtask

    // send a frame of n bytes and pass or drop 
    task automatic send_frame(
        input logic [7:0] data [],
        input logic       pass_or_drop   // 1 = pass, 0 = drop
    );
        int i;
        for(i = 0; i < data.size(); i++)
            write_byte(data[i]);

        frame_end = 1'b1;
        @(posedge clk); #1;
        frame_end = 1'b0;
        @(posedge clk); #1;

        if(pass_or_drop) begin
            frame_pass = 1'b1;
            @(posedge clk); #1;
            frame_pass = 1'b0;
        end else begin
            frame_drop = 1'b1;
            @(posedge clk); #1;
            frame_drop = 1'b0;
        end

        @(posedge clk); #1;
    endtask

    // Payloads
    logic [7:0] frame_a [] = '{8'hAA, 8'hBB, 8'hCC, 8'hDD, 8'hEE, 8'hFF};
    logic [7:0] frame_b [] = '{8'h11, 8'h22, 8'h33, 8'h44, 8'h55, 8'h66};

    logic [7:0] rd_data;

    initial begin
        rst_fb       = 1'b1;
        byte_valid   = 1'b0;
        payload_byte = 8'h00;
        frame_pass   = 1'b0;
        frame_drop   = 1'b0;
        frame_end    = 1'b0;
        rd_en        = 1'b0;

        repeat(3) @(posedge clk);
        rst_fb = 1'b0;
        @(posedge clk); #1;

        // Test 1: FIFO empty on reset
        $display("Test 1: empty on reset");
        assert(empty == 1'b1)
            else $error("FAIL: FIFO should be empty after reset");
        assert(full == 1'b0)
            else $error("FAIL: FIFO should not be full after reset");

        // Test 2: write bytes, assert frame_pass, read back
        $display("Test 2: write and read back a passed frame");
        send_frame(frame_a, 1'b1);

        assert(empty == 1'b0)
            else $error("FAIL: FIFO should not be empty after frame_pass");

        for(int i = 0; i < frame_a.size(); i++) begin
            read_byte(rd_data);
            assert(rd_data == frame_a[i])
                else $error("FAIL: byte %0d read=%h expected=%h", i, rd_data, frame_a[i]);
        end

        assert(empty == 1'b1)
            else $error("FAIL: FIFO should be empty after reading all bytes");

        // Test 3: write bytes, assert frame_drop, confirm FIFO stays empty
        $display("Test 3: dropped frame should not appear in FIFO");
        send_frame(frame_a, 1'b0);

        assert(empty == 1'b1)
            else $error("FAIL: FIFO should be empty after frame_drop rollback");

        // Test 4: drop then pass - confirm pass frame is intact
        $display("Test 4: drop followed by pass");
        send_frame(frame_a, 1'b0);   // drop this one
        send_frame(frame_b, 1'b1);   // pass this one

        for(int i = 0; i < frame_b.size(); i++) begin
            read_byte(rd_data);
            assert(rd_data == frame_b[i])
                else $error("FAIL: byte %0d read=%h expected=%h", i, rd_data, frame_b[i]);
        end

        assert(empty == 1'b1)
            else $error("FAIL: FIFO should be empty after reading frame_b");

        // Test 5: two consecutive passed frames
        $display("Test 5: two consecutive passed frames");
        send_frame(frame_a, 1'b1);
        send_frame(frame_b, 1'b1);

        for(int i = 0; i < frame_a.size(); i++) begin
            read_byte(rd_data);
            assert(rd_data == frame_a[i])
                else $error("FAIL: frame_a byte %0d read=%h expected=%h", i, rd_data, frame_a[i]);
        end
        for(int i = 0; i < frame_b.size(); i++) begin
            read_byte(rd_data);
            assert(rd_data == frame_b[i])
                else $error("FAIL: frame_b byte %0d read=%h expected=%h", i, rd_data, frame_b[i]);
        end

        assert(empty == 1'b1)
            else $error("FAIL: FIFO should be empty after reading both frames");

        $display("Smoke test complete.");
        $finish;
    end

endmodule