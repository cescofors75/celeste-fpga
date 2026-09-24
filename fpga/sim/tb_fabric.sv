`timescale 1ns/1ps
module tb_fabric;
 reg clk=0,rst=1,ce=0;always #5 clk=~clk;
 reg signed [15:0] l=0,r=0;reg [511:0] p=0;reg [5:0] routes=1;wire signed [15:0] ol,orr;
 wire [127:0] meters;
 parallel_fabric dut(clk,rst,ce,l,r,p,routes,ol,orr,meters);
 integer i;integer energy;
 task tick(input signed [15:0] a,b);begin
  @(negedge clk);l=a;r=b;ce=1;@(negedge clk);ce=0;repeat(255)@(negedge clk);
 end endtask
 task reset;begin rst=1;repeat(3)@(negedge clk);rst=0;end endtask
 initial begin
  p[6*16+:16]=65535;p[10*16+:16]=65535;reset();tick(12000,-12000);
  if(ol<11996||orr> -11996)$fatal(1,"Dry gain/sign %d %d",ol,orr);
  p[6*16+:16]=0;p[8*16+:16]=65535;p[2*16+:16]=80;routes=4;reset();
  tick(20000,-16000);if(ol!=0||orr!=0)$fatal(1,"Delay read uninitialized memory");
  for(i=1;i<=10;i=i+1)begin tick(0,0);if(i<10&&(ol!=0||orr!=0))$fatal(1,"Early delayed sample");end
  tick(0,0);if(ol<19995||orr> -15995)$fatal(1,"Delay impulse stereo %d %d",ol,orr);
  p[8*16+:16]=0;p[9*16+:16]=65535;p[4*16+:16]=20000;p[5*16+:16]=20000;routes=8;reset();
  energy=0;tick(12000,-12000);for(i=0;i<100;i=i+1)begin tick(0,0);energy=energy+(ol<0?-ol:ol);end
  if(energy<1000)$fatal(1,"Filter has no impulse response");
  p[9*16+:16]=0;p[7*16+:16]=65535;p[0+:16]=65535;p[16+:16]=65535;routes=2;reset();
  tick(1000,-1000);tick(2000,-2000);tick(3000,-3000);
  if(ol>1500||orr< -1500)$fatal(1,"Glitch hold not active");
  routes=0;for(i=0;i<300;i=i+1)tick(10000,-10000);if(ol!=0||orr!=0)$fatal(1,"Route mute did not settle");
  p=0;p[10*16+:16]=65535;p[14*16+:16]=32768;p[17*16+:16]=65535;routes=32;reset();tick(20000,-20000);
  if(ol<9995||ol>10001||orr> -9995)$fatal(1,"VCA half gain/sign %d %d",ol,orr);
  p[12*16+:16]=65535;p[18*16+:16]=2;reset();dut.lfo_phase=32'h40000000;tick(20000,-20000);
  if(ol<4990||ol>5010)$fatal(1,"LFO to VCA target %d",ol);
  p[18*16+:16]=1;reset();dut.lfo_phase=32'h40000000;tick(20000,-20000);
  if(ol<9995)$fatal(1,"Filter modulation leaked into VCA");
  p[14*16+:16]=0;for(i=0;i<300;i=i+1)tick(20000,-20000);if(ol!=0||orr!=0)$fatal(1,"VCA zero must mute");
  p=0;p[10*16+:16]=65535;p[16*16+:16]=65535;routes=16;reset();tick(20000,-20000);
  if(ol<19995||orr> -19995)$fatal(1,"Wavefold zero drive identity");
  p[13*16+:16]=65535;for(i=0;i<300;i=i+1)tick(20000,-20000);
  if(ol>=0||orr<=0)$fatal(1,"Wavefold did not fold polarity %d %d",ol,orr);
  p[31*16+:16]=65535;p[15*16+:16]=65535;for(i=0;i<5000;i=i+1)tick(0,0);
  if(dut.chaos_value==32768||dut.chaos_mod==0)$fatal(1,"Chaos did not modulate");
  p=0;p[10*16+:16]=32768;routes=0;reset();tick(16000,-16000);if(ol!=0||orr!=0)$fatal(1,"No routes must mute FX");
  p[20*16+:16]=65535;for(i=0;i<260;i=i+1)tick(16000,-16000);
  if(ol<7995||ol>8000||orr> -7995)$fatal(1,"Bypass dry stereo preserves master %d %d",ol,orr);
  p[20*16+:16]=0;for(i=0;i<260;i=i+1)tick(16000,-16000);if(ol!=0||orr!=0)$fatal(1,"Bypass OFF restores muted route patch");
  p=0;p[10*16+:16]=65535;p[7*16+:16]=16384;p[16*16+:16]=16384;routes=18;reset();tick(12000,-12000);tick(12000,-12000);
  if(ol<5993||ol>6000)$fatal(1,"Parallel branches must sum, not cascade %d",ol);
  if(meters[2*16+:16]<2990||meters[5*16+:16]<2990||meters[7*16+:16]<5990)$fatal(1,"Measured branch/output peaks");
  routes=2;for(i=0;i<300;i=i+1)tick(12000,-12000);if(ol<2993||ol>3000)$fatal(1,"Removing wave route must halve sum %d",ol);
  $display("PASS fabric: dry, delay, filter, glitch, route mute, VCA gain, modulation targets, wavefold, Chaos");$finish;
 end
 initial begin #30000000;$fatal(1,"Fabric timeout");end
endmodule
