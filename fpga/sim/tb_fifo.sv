`timescale 1ns/1ps
module tb_fifo;
 reg clk=0,rst=1,clear=0,write=0,read=0;always #5 clk=~clk;
 reg [31:0] din=0;wire ready,valid;wire [31:0] dout,over,under;wire [3:0] fill;
 sample_fifo #(.DEPTH(8)) dut(clk,rst,clear,write,din,ready,read,dout,valid,fill,over,under);
 integer i;
 initial begin
  repeat(3)@(negedge clk);rst=0;
  for(i=0;i<8;i=i+1)begin write=1;din=i;@(negedge clk);end
  if(fill!=8||ready)$fatal(1,"Full handling");
  @(negedge clk);write=0;if(over!=1)$fatal(1,"Overrun counter");
  for(i=0;i<8;i=i+1)begin read=1;@(negedge clk);if(!valid||dout!=i)$fatal(1,"Order at %d",i);end
  @(negedge clk);read=0;if(fill!=0||under!=1)$fatal(1,"Underflow counter");
  // Exercise wrap and simultaneous push/pop without changing occupancy.
  write=1;din=100;@(negedge clk);
  for(i=0;i<20;i=i+1)begin read=1;din=101+i;@(negedge clk);if(fill!=1||dout!=100+i)$fatal(1,"Simultaneous read/write");end
  write=0;read=0;clear=1;@(negedge clk);clear=0;
  if(fill!=0||valid)$fatal(1,"Clear");
  $display("PASS FIFO: full, empty, wrap, simultaneous, counters, clear");$finish;
 end
 initial begin #100000;$fatal(1,"Timeout");end
endmodule
