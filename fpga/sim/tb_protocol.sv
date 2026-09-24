`timescale 1ns/1ps
module tb_protocol;
 reg clk=0,rst=1,rx_valid=0,done=0;always #5 clk=~clk;
 reg [7:0] data;wire ready,valid;wire [7:0] kind,payload;wire [31:0] seq,errors;wire [10:0] length;reg [9:0] address=0;
 protocol_rx #(.IDLE_BITS(12)) dut(clk,rst,rx_valid,data,ready,valid,done,kind,seq,length,address,payload,errors);
 reg [7:0] vector[0:15];integer i;
 task send(input [7:0] b);begin @(negedge clk);rx_valid=1;data=b;@(negedge clk);rx_valid=0;end endtask
 initial begin
  $readmemh("fpga/sim/audio_packet.hex",vector);
  repeat(4)@(negedge clk);rst=0;
  send(8'hfe);send(8'h43);send(8'h43);
  for(i=1;i<16;i=i+1)send(vector[i]);
  if(!valid||kind!=4||seq!=32'h12345678||length!=4||ready)$fatal(1,"Header decode");
  for(i=0;i<4;i=i+1)begin address=i;repeat(2)@(negedge clk);if(payload!=vector[10+i])$fatal(1,"Payload");end
  done=1;@(negedge clk);done=0;
  for(i=0;i<16;i=i+1)send(i==12?vector[i]^8'h01:vector[i]);
  if(valid||errors!=1)$fatal(1,"Corrupt frame accepted");
  for(i=0;i<16;i=i+1)send(vector[i]);
  if(!valid)$fatal(1,"Recovery");done=1;@(negedge clk);done=0;
  send(8'h43);send(8'h45);send(1);send(4);repeat(4100)@(negedge clk);
  if(errors!=2)$fatal(1,"Truncated frame timeout");
  $display("PASS protocol: Rust vector, CRC rejection, resync, backpressure, timeout");$finish;
 end
 initial begin #12000000;$fatal(1,"Timeout");end
endmodule
