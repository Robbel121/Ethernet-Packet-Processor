# Ethernet-Packet-Processor

A pipelined Ethernet packet processor implemented in Systemverilog and using a Nexys A7 100T FPGA. It interfaces with the LAN8720 PHY over RMII and processes recieved frames through a multi-stage filter and validation pipeline.

## Features
RMII Deserializer: recieves 2 bits at 50 MHz and assembles bytes.
Frame Parser: takes said bytes and  detects preamble/SFD, extracts the destination and source MAC address, determines the Ethertype from a 14-byte header.  
MAC Address Filter: passes frames matching an allowed mac address or broadcast address; promiscuous mode tied to an onboard switch.
Frame Length Validator: enforces a minimum(60 bytes from IEE 802.3) and maximum(1514 bytes/MTU) amount of bytes for data frame size.
Packet FIFO: buffers paylaod bytes from frames that pass all tests. 
Status LED's: indicates real-time pass/drops/errors on onbaord LED's.
-- More to come with physical impelemtation

## Architecture



## Planned features
UART readback-stream buffered payload bytes to PC over USB-UART at 115200 baud. Will utilize my UART project but in SystemVerilog.
UVM testbench rebuild - Fall 2026
Payload Inspection - Winter 2026
