`timescale 1ns/1ps
module tb_signal_meters;
 reg clk=0,rst=1,ce=0;always #5 clk=~clk;
 reg [511:0] p=0;wire [239:0] meters;wire signed [15:0] ol,orr;
 reg signed [15:0] source_l=10000,source_r=-8000;
 parallel_fabric dut(clk,rst,ce,source_l,source_r,p,6'd63,ol,orr,meters);
 integer n,k;
 task frame;begin @(negedge clk);ce=1;@(negedge clk);ce=0;repeat(32)@(negedge clk);end endtask
 initial begin
  p[10*16+:16]=65535;p[14*16+:16]=65535;p[4*16+:16]=30000;
  p[2*16+:16]=32;p[24*16+:16]=96;p[26*16+:16]=32768;p[27*16+:16]=3;
  repeat(4)@(negedge clk);rst=0;
  for(n=0;n<350;n=n+1)frame;
  // Muted direct branches must still report their actual processor outputs.
  for(k=2;k<=6;k=k+1)if(meters[k*16+:16]!=0)$fatal(1,"muted mix meter %0d",k);
  for(k=8;k<=14;k=k+1)if(meters[k*16+:16]<4)$fatal(1,"missing raw/D2 meter %0d",k);
  if(meters[9*16+:16]!=10000||meters[13*16+:16]!=10000||meters[14*16+:16]!=5000)$fatal(1,"cascade meter values must follow raw vs gain");
  p[22*16+:16]=63;for(n=0;n<350;n=n+1)frame;
  for(k=8;k<=13;k=k+1)if(meters[k*16+:16]<10000)$fatal(1,"bypass processing visibility");
  source_l=0;source_r=0;for(n=0;n<9600;n=n+1)frame;
  if(meters[15:0]!=10000)$fatal(1,"200 ms peak hold lost a transient between host polls");
  for(n=0;n<100;n=n+1)frame;
  if(meters[15:0]>=10000)$fatal(1,"peak must decay after hold");
  $display("PASS signal telemetry: six independent raw effect outputs, zero-gain branches, serial Delay 1, Delay 2 pre/post mix, component bypass");$finish;
 end
 initial begin #10000000;$fatal(1,"timeout");end
endmodule
