interface frame_len_interface(input bit clk_50M);
    logic rst_flv, frame_pass, byte_valid, frame_end;
    logic len_pass, len_fail, frame_long, frame_short;

    clocking drv_cb @(posedge clk_50M);
        default output #1;
        output rst_flv, frame_pass, byte_valid, frame_end;
    endclocking

    clocking mon_cb @(posedge clk_50M);
        input rst_flv, frame_pass, byte_valid, frame_end, len_pass, len_fail, frame_long, frame_short;
    endclocking

endinterface
