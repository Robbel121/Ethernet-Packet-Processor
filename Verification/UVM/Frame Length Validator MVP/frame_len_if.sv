interface frame_ln_if(input bit clk);
    // Inputs(randomize)
    logic rst_flv;
    logic frame_pass;
    logic byte_valid; 
    logic frame_end; 
   
    // Outputs
    logic len_pass; 
    logic len_fail;  
    logic frame_long;
    logic frame_short;
endinterface