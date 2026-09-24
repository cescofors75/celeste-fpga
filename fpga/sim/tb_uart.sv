`timescale 1ns/1ps
module tb_uart;
 reg clk=0,reset=1,rx=1;always #5 clk=~clk;
 wire tx,led;uart_probe dut(clk,reset,rx,tx,led);
 integer i,j,seen=0;reg [7:0] got;
 always begin
  @(negedge tx);repeat(13)@(posedge clk);
  for(integer bitno=0;bitno<8;bitno=bitno+1)begin got[bitno]=tx;repeat(9)@(posedge clk);end
  if(tx!==1'b1||got!==(seen&255))$fatal(1,"Echo mismatch at %d: %h",seen,got);
  seen=seen+1;
 end
 initial begin
  repeat(40)@(negedge clk);reset=0;
  for(i=0;i<512;i=i+1)begin
   rx=0;repeat(9)@(negedge clk);
   for(j=0;j<8;j=j+1)begin rx=(i>>j)&1;repeat(9)@(negedge clk);end
   rx=1;repeat(9)@(negedge clk);
  end
  wait(seen==512);if(!led)$fatal(1,"Framing/overflow fault");
  $display("PASS UART: 512 back-to-back bytes at 3 Mbaud echo");$finish;
 end
 initial begin #1000000;$fatal(1,"UART timeout");end
endmodule
