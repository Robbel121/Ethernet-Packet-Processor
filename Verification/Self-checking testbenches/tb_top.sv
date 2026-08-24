`timescale 1ns / 1ps
module tb_top;
    logic        clk_100M;
    logic        reset;
    logic [1:0]  rmii_rxd;
    logic        rmii_dv;
    logic        phy_clk;
    logic        all_mode;

    logic        led_frame_pass;
    logic        led_frame_drop;
    logic        led_len_pass;
    logic        led_len_fail;
    logic        led_frame_err;

    top dut (
        .clk_100M      (clk_100M),
        .reset         (reset),
        .rmii_rxd      (rmii_rxd),
        .rmii_dv       (rmii_dv),
        .phy_clk       (phy_clk),
        .all_mode      (all_mode),
        .led_frame_pass(led_frame_pass),
        .led_frame_drop(led_frame_drop),
        .led_len_pass  (led_len_pass),
        .led_len_fail  (led_len_fail),
        .led_frame_err (led_frame_err)
    );


    initial clk_100M = 1'b0;
    always  #5  clk_100M = ~clk_100M;  

    initial phy_clk  = 1'b0;
    always  #10 phy_clk  = ~phy_clk;   

    // Sticky capture registers
    logic cap_frame_pass, cap_frame_drop;
    logic cap_len_pass,   cap_len_fail;
    logic cap_frame_err;

    always_ff @(posedge phy_clk) begin
        if (reset) begin
            cap_frame_pass <= 1'b0;
            cap_frame_drop <= 1'b0;
            cap_len_pass   <= 1'b0;
            cap_len_fail   <= 1'b0;
            cap_frame_err  <= 1'b0;
        end else begin
            if (led_frame_pass) cap_frame_pass <= 1'b1;
            if (led_frame_drop) cap_frame_drop <= 1'b1;
            if (led_len_pass)   cap_len_pass   <= 1'b1;
            if (led_len_fail)   cap_len_fail   <= 1'b1;
            if (led_frame_err)  cap_frame_err  <= 1'b1;
        end
    end

    // Scoreboard counters
    int tests_run    = 0;
    int tests_passed = 0;
    int tests_failed = 0;

    localparam logic [47:0] ALLOWED_MAC  = 48'hAABBCCDDEEFF;
    localparam logic [47:0] BROADCAST    = 48'hFFFFFFFFFFFF;
    localparam logic [47:0] SRC_MAC      = 48'h112233445566;
    localparam int          HEADER_BYTES = 14;
    localparam int          MIN_FRAME    = 60;
    localparam int          MAX_FRAME    = 1514;

    typedef struct {
        logic expect_pass;
        logic expect_drop;
        logic expect_len_ok;
        logic expect_len_fail;
        logic expect_err;
    } expected_t;

    // Prediction function
    function automatic expected_t predict(
        input logic [47:0] dst,
        input logic        promisc,
        input int          total_bytes,
        input logic        corrupt_preamble,
        input logic        corrupt_sfd
    );
        expected_t e;
        e.expect_err      = corrupt_preamble | corrupt_sfd;
        e.expect_pass     = !e.expect_err &&
                            (promisc || dst == ALLOWED_MAC || dst == BROADCAST);
        e.expect_drop     = !e.expect_err && !e.expect_pass;
        e.expect_len_ok   = e.expect_pass &&
                            (total_bytes >= MIN_FRAME && total_bytes <= MAX_FRAME);
        e.expect_len_fail = e.expect_pass &&
                            (total_bytes < MIN_FRAME || total_bytes > MAX_FRAME);
        return e;
    endfunction

    // Reset pipeline between tests
    task automatic reset_pipeline();
        rmii_dv  = 1'b0;
        rmii_rxd = 2'b00;
        reset    = 1'b1;
        repeat(20) @(posedge phy_clk);
        reset    = 1'b0;
        repeat(20) @(posedge phy_clk);
    endtask

    // RMII byte sender - LSB-first to match LAN8720A spec
    task automatic send_byte_rmii(input logic [7:0] data);
        rmii_rxd = data[1:0]; @(posedge phy_clk); #1;
        rmii_rxd = data[3:2]; @(posedge phy_clk); #1;
        rmii_rxd = data[5:4]; @(posedge phy_clk); #1;
        rmii_rxd = data[7:6]; @(posedge phy_clk); #1;
    endtask

    // Full Ethernet frame sender
    // Builds: 7x preamble (0xAA) + SFD (0xD5) + dst + src + etype + payload
    task automatic send_eth_frame(
        input logic [47:0] dst,
        input logic [47:0] src,
        input logic [15:0] etype,
        input int          payload_len,
        input logic        corrupt_preamble,
        input logic        corrupt_sfd
    );
        int i;
        rmii_dv = 1'b1;

        // Preamble: 7 bytes of 0xAA
        send_byte_rmii(8'hAA);
        for (i = 1; i < 7; i++) begin
            if (i == 1 && corrupt_preamble)
                send_byte_rmii(8'hBB);
            else
                send_byte_rmii(8'hAA);
        end

        // SFD
        if (corrupt_sfd) send_byte_rmii(8'hCC);
        else             send_byte_rmii(8'hD5);

        if (!corrupt_preamble && !corrupt_sfd) begin
            for (i = 0; i < 6; i++)
                send_byte_rmii(dst[40 -(i*8) +: 8]);

            // Source MAC
            for (i = 0; i < 6; i++)
                send_byte_rmii(src[40 - (i*8) +: 8]);

            send_byte_rmii(etype[15:8]);
            send_byte_rmii(etype[7:0]);

            for (i = 0; i < payload_len; i++)
                send_byte_rmii(i[7:0]);
        end

        // End frame
        rmii_dv  = 1'b0;
        rmii_rxd = 2'b00;
        @(posedge phy_clk); #1;
    endtask

    // Scoreboard
    task automatic check_result(
        input expected_t exp,
        input string     test_name
    );
        tests_run++;

        // Error 
        if (exp.expect_err) begin
            if (cap_frame_err) begin
                $display("[%s] PASS - frame_err asserted correctly", test_name);
                tests_passed++;
            end else begin
                $error("[%s] FAIL - expected frame_err, got pass=%b drop=%b err=%b",
                       test_name, cap_frame_pass, cap_frame_drop, cap_frame_err);
                tests_failed++;
            end
            return;
        end

        // MAC filter
        if (exp.expect_pass && !cap_frame_pass) begin
            $error("[%s] FAIL - expected frame_pass, got pass=%b drop=%b",
                   test_name, cap_frame_pass, cap_frame_drop);
            tests_failed++;
            return;
        end

        if (exp.expect_drop && !cap_frame_drop) begin
            $error("[%s] FAIL - expected frame_drop, got pass=%b drop=%b",
                   test_name, cap_frame_pass, cap_frame_drop);
            tests_failed++;
            return;
        end

        // Length check for frames that pass MAC filter
        if (exp.expect_pass) begin
            if (exp.expect_len_ok && !cap_len_pass) begin
                $error("[%s] FAIL - expected len_pass, got pass=%b fail=%b",
                       test_name, cap_len_pass, cap_len_fail);
                tests_failed++;
                return;
            end
            if (exp.expect_len_fail && !cap_len_fail) begin
                $error("[%s] FAIL - expected len_fail, got pass=%b fail=%b",
                       test_name, cap_len_pass, cap_len_fail);
                tests_failed++;
                return;
            end
        end

        $display("[%s] PASS", test_name);
        tests_passed++;
    endtask

    // Run one test
    // Resets pipeline, sends frame, waits, checks 
    task automatic run_test(
        input string       name,
        input logic [47:0] dst,
        input int          payload_len,
        input logic        promisc,
        input logic        corrupt_preamble,
        input logic        corrupt_sfd
    );
        expected_t exp;
        int        total;

        total    = HEADER_BYTES + payload_len;
        exp      = predict(dst, promisc, total, corrupt_preamble, corrupt_sfd);
        all_mode = promisc;

        // Reset clears FSMs and capture registers
        reset_pipeline();

        send_eth_frame(dst, SRC_MAC, 16'h0800, payload_len,
                       corrupt_preamble, corrupt_sfd);

        // payload * 4 dibit cycles + 200 cycles FSM latency margin
        repeat((payload_len * 4) + 200) @(posedge phy_clk);

        check_result(exp, name);

        all_mode = 1'b0;
    endtask

    initial begin
        reset    = 1'b1;
        rmii_rxd = 2'b00;
        rmii_dv  = 1'b0;
        all_mode = 1'b0;

        repeat(50) @(posedge phy_clk);
        reset = 1'b0;
        repeat(20) @(posedge phy_clk);

        $display("  Ethernet Packet Processor Test top ");

        $display("\n Group 1: MAC filter");
        run_test("T01_exact_match",      ALLOWED_MAC,        46, 0, 0, 0);
//        run_test("T02_broadcast",        BROADCAST,          46, 0, 0, 0);
        run_test("T03_wrong_mac",        48'hDEADBEEF0001,   46, 0, 0, 0);
//        run_test("T04_near_miss_mac",    48'hAABBCCDDEEFE,   46, 0, 0, 0);
//        run_test("T05_zero_mac",         48'h000000000000,   46, 0, 0, 0);
//        run_test("T06_multicast",        48'h01005E000001,   46, 0, 0, 0);

        $display("\n Group 2: Promisc mode ");
//        run_test("T07_promisc_wrong",    48'hDEADBEEF0001,   46, 1, 0, 0);
        run_test("T08_promisc_bcast",    BROADCAST,          46, 1, 0, 0);

        $display("\n Group 3: Length validation ");
        run_test("T09_min_legal",        ALLOWED_MAC,        46, 0, 0, 0);
//        run_test("T10_max_legal",        ALLOWED_MAC,      1500, 0, 0, 0);
//        run_test("T11_one_below_min",    ALLOWED_MAC,        45, 0, 0, 0);
        run_test("T12_one_above_max",    ALLOWED_MAC,      1501, 0, 0, 0);
//        run_test("T13_undersized",       ALLOWED_MAC,        20, 0, 0, 0);
//        run_test("T14_drop_undersized",  48'hDEADBEEF0001,   20, 0, 0, 0);

        $display("\n-- Group 4: Error conditions --");
        run_test("T15_corrupt_preamble", ALLOWED_MAC,        46, 0, 1, 0);
        run_test("T16_corrupt_sfd",      ALLOWED_MAC,        46, 0, 0, 1);

        $display("\n Group 5: Pipeline recovery ");
        run_test("T17_err_frame",        ALLOWED_MAC,        46, 0, 1, 0);
//        run_test("T17b_good_after_err",  ALLOWED_MAC,        46, 0, 0, 0);
//        run_test("T18_drop",             48'hDEADBEEF0001,   46, 0, 0, 0);
//        run_test("T18b_pass_after_drop", ALLOWED_MAC,        46, 0, 0, 0);
//        run_test("T19_back_to_back_1",   ALLOWED_MAC,        46, 0, 0, 0);
//        run_test("T19_back_to_back_2",   ALLOWED_MAC,       100, 0, 0, 0);
        run_test("T20_seq_pass",         ALLOWED_MAC,        46, 0, 0, 0);
//        run_test("T20_seq_drop",         48'hCAFEBABE0000,   46, 0, 0, 0);
//        run_test("T20_seq_pass_again",   ALLOWED_MAC,       200, 0, 0, 0);

        $display("  Results: %0d / %0d passed", tests_passed, tests_run);
        if (tests_failed > 0)
            $display("  FAILED:  %0d tests", tests_failed);
        else
            $display("  All tests passed.");

        $finish;
    end

endmodule