`timescale 1ns/1ps
module tb_protocol_usb_gap;
 reg clk=0,rst=1,rx_valid=0,done=0;always #5 clk=~clk;
 reg [7:0] data;wire ready,valid;wire [7:0] kind,payload;wire [31:0] seq,errors;wire [10:0] length;
 protocol_rx dut(clk,rst,rx_valid,data,ready,valid,done,kind,seq,length,10'd0,payload,errors);
 reg [7:0] vector[0:15];integer i;
 task send(input [7:0] b);begin @(negedge clk);rx_valid=1;data=b;@(negedge clk);rx_valid=0;end endtask
 initial begin
  $readmemh("fpga/sim/audio_packet.hex",vector);repeat(4)@(negedge clk);rst=0;
  for(i=0;i<12;i=i+1)send(vector[i]);
  // 200 ms at the actual audio clock, well beyond the former 85 ms limit.
  repeat(2457600)@(negedge clk);
  for(i=12;i<16;i=i+1)send(vector[i]);
  if(!valid||errors||seq!=32'h12345678||length!=4)$fatal(1,"Valid stalled USB packet was lost");
  $display("PASS protocol USB gap: valid CRC packet survives 2457600 idle cycles");$finish;
 end
 initial begin #30000000;$fatal(1,"Timeout");end
endmodule
