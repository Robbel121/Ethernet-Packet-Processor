`timescale 1ns/ 1ps

module tb_MACAddressFilter;
    
    logic clk, rst_maf;
    logic [47:0] dst_mac, allowed_mac;
    logic all, parse_done;
    logic frame_pass, frame_drop;
    
    MACAddyFilter uut(.clk(clk), .rst_maf(rst_maf),
     .dst_mac(dst_mac), .allowed_mac(allowed_mac), .all(all),
      .parse_done(parse_done), .frame_pass(frame_pass),
       .frame_drop(frame_drop));
    
    initial clk = 0;
    always #10 clk = ~clk;
    
    task automatic send(
        input logic [47:0] dst,
        input logic expect_pass
    );
    
        dst_mac = dst;
        parse_done = 1'b1;
        @(posedge clk); #1;
        
        parse_done = 1'b0;
        @(posedge clk); #1;

        
        if(expect_pass)begin
            assert (frame_pass == 1'b1 && frame_drop == 1'b0)
                else $error("FAIL: expected PASS for dst=%h, got pass=%b drop=%b",
                            dst, frame_pass, frame_drop);
        end else begin
            assert (frame_drop == 1'b1 && frame_pass == 1'b0)
                else $error("FAIL: expected DROP for dst=%h, got pass=%b drop=%b",
                            dst, frame_pass, frame_drop);
        end
        
        @(posedge clk)#1;
    endtask
    
    initial begin
        rst_maf     = 1'b1;
        parse_done  = 1'b0;
        all         = 1'b0;
        dst_mac     = '0;
        allowed_mac = 48'hAABBCCDDEEFF;

        repeat(3) @(posedge clk);
        rst_maf = 1'b0;
        @(posedge clk); #1;

        // Expect Pass
        $display("Test 1: exact match");
        send(48'hAABBCCDDEEFF, 1'b1);

        // Expect pass
        $display("Test 2: broadcast");
        send(48'hFFFFFFFFFFFF, 1'b1);

        // Expect Drop
        $display("Test 3: wrong MAC");
        send(48'hDEADBEEF0001, 1'b0);

        // Expect a frame pass
        $display("Test 4: all mode");
        all = 1'b1;
        send(48'hDEADBEEF0001, 1'b1);
        all = 1'b0;

        //Expect Drop and Pass
        $display("Test 5: DROP then PASS");
        send(48'hCAFEBABE0000, 1'b0);
        send(48'hAABBCCDDEEFF, 1'b1);

        $display("Simple test complete.");
        $finish;
    end
    
endmodule