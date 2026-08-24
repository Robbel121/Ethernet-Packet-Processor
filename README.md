# Ethernet-Packet-Processor

A pipelined Ethernet packet processor implemented in Systemverilog and using a Nexys A7 100T FPGA. It interfaces with the LAN8720 PHY over RMII and processes recieved frames through a multi-stage filter and validation pipeline.

## Features
-RMII Deserializer: recieves 2 bits at 50 MHz and assembles bytes.


-Frame Parser: takes said bytes and  detects preamble/SFD, extracts the destination and source MAC address, determines the Ethertype from a 14-byte header.  


-MAC Address Filter: passes frames matching an allowed mac address or broadcast address; promiscuous mode tied to an onboard switch.


-Frame Length Validator: enforces a minimum(60 bytes from IEE 802.3) and maximum(1514 bytes/MTU) amount of bytes for data frame size.


-Packet FIFO: buffers payload bytes from frames that pass all tests. 


-Status LED's: indicates real-time pass/drops/errors on onbaord LED's.


-- More to come with physical impelemtation

## Architecture

LAN 8720A PHY(RMII 2-bit rxd @ 50 MHz) -> RMII Deserializer(byte stream @ 50 Mhz) -> Frame Parser(dst mac, src mac, ethertype, payload bytes, then send parse done) -> MAC Address Filter(frame_pass or frame_drop) -> Frame length Validator(len_fail or len_pass) -> FIFO buffer(store for UART readback)

## Simulation

All modules include SystemVerilog smoke tests written without UVM. Tests use a self-checking scoreboard with $error reports. Be sure to remove the (*mark debug*) commands in top.sv since those are meant for the ILA.

To run a simulation in Vivado:
1. Add the module source and its corresponding tb_ file to your project
2. Set the testbench as the top module under Simulation Sources
3. Run Simulation -> Run All
4. Check the Tcl console for PASS/FAIL output

## Planned features

Fall 2026 - UVM testbench rebuild

