`timescale 1ns/1ps
module tb_dual_delay;
 reg clk=0,rst=1,ce=0;always #5 clk=~clk;
 reg signed [15:0] l=0,r=0;reg [511:0] p=0;reg [5:0] routes=0;
 wire signed [15:0] ol,orr;integer n,k,mode,expect_l,expect_r;
 parallel_fabric dut(clk,rst,ce,l,r,p,routes,ol,orr,);
 task reset;begin rst=1;l=0;r=0;repeat(3)@(negedge clk);rst=0;end endtask
 task frame(input integer a,b);begin
  @(negedge clk);if(dut.phase!=0)$fatal(1,"missed deadline");l=a;r=b;ce=1;
  @(negedge clk);ce=0;repeat(30)@(negedge clk);
  if(dut.phase!=0)$fatal(1,"DSP exceeds 32 clocks");
 end endtask
 initial begin
  // Independent impulses: parallel at 7 and 11, cascade at 18 samples.
  for(mode=0;mode<2;mode=mode+1)begin
   p=0;p[2*16+:16]=6*8;p[24*16+:16]=10*16;p[10*16+:16]=65535;
   p[8*16+:16]=65535;p[26*16+:16]=65535;p[27*16+:16]=mode?3:1;routes=mode?0:4;reset;
   for(n=0;n<40;n=n+1)begin frame(n==0?9000:0,n==0?-6000:0);
    expect_l=mode?(n==18?9000:0):((n==7||n==11)?9000:0);
    expect_r=mode?(n==18?-6000:0):((n==7||n==11)?-6000:0);
    if(ol!==expect_l||orr!==expect_r)$fatal(1,"delay topology %0d frame %0d got %0d/%0d expected %0d/%0d",mode,n,ol,orr,expect_l,expect_r);
   end
  end
  // Second delay reaches its full 4096-frame memory, without shortening D1.
  p=0;p[24*16+:16]=65535;p[26*16+:16]=65535;p[27*16+:16]=1;p[10*16+:16]=65535;routes=0;reset;
  for(n=0;n<4100;n=n+1)begin frame(n==0?12345:0,n==0?-23456:0);if(ol!==(n==4096?12345:0)||orr!==(n==4096?-23456:0))$fatal(1,"delay2 memory depth frame %0d",n);end
  // Bypass each effect preserves signed dry audio at unity, not mute.
  for(k=0;k<6;k=k+1)begin
   p=0;p[10*16+:16]=65535;p[22*16+k]=1;routes=0;
   case(k)
    0:begin routes=2;p[7*16+:16]=65535;end
    1:begin routes=4;p[8*16+:16]=65535;end
    2:begin routes=8;p[9*16+:16]=65535;end
    3:begin routes=16;p[16*16+:16]=65535;p[13*16+:16]=65535;end
    4:begin routes=32;p[17*16+:16]=65535;end
    5:begin p[27*16+:16]=1;p[26*16+:16]=65535;end
   endcase
   reset;for(n=0;n<16;n=n+1)begin frame(-24000+n*3000,21000-n*3000);if(ol!==l||orr!==r)$fatal(1,"bypass %0d is not dry",k);end
  end
  // Serial bypass: bypassing D1 leaves D2's delay; bypassing D2 leaves D1's.
  for(k=0;k<2;k=k+1)begin
   p=0;p[2*16+:16]=6*8;p[24*16+:16]=10*16;p[27*16+:16]=3;p[26*16+:16]=65535;p[10*16+:16]=65535;p[22*16+(k==0?1:5)]=1;routes=0;reset;
   for(n=0;n<30;n=n+1)begin frame(n==0?9000:0,0);if(ol!==(n==(k==0?11:7)?9000:0))$fatal(1,"series bypass stage %0d sample %0d",k,n);end
  end
  // Crossfade to/from bypass cannot jump on a silent VCA at constant input.
  p=0;p[10*16+:16]=65535;p[17*16+:16]=65535;routes=32;reset;expect_l=0;
  for(n=0;n<600;n=n+1)begin p[22*16+4]=(n<300);frame(16000,0);if(ol-expect_l>64||expect_l-ol>64)$fatal(1,"bypass discontinuity");expect_l=ol;end
  // Delay 2 feedback has its own state and its expected halving echoes.
  p=0;p[24*16+:16]=10*16;p[25*16+:16]=65535;p[26*16+:16]=65535;p[27*16+:16]=1;p[10*16+:16]=65535;routes=0;reset;
  for(n=0;n<50;n=n+1)begin frame(n==0?16000:0,0);case(n)11:expect_l=16000;22:expect_l=7999;33:expect_l=3999;44:expect_l=1999;default:expect_l=0;endcase if(ol!==expect_l||orr!==0)$fatal(1,"delay2 feedback/crosstalk %0d: %0d",n,ol);end
  // Both modulation bypasses remove modulation, without muting their target.
  p=0;p[12*16+:16]=65535;p[15*16+:16]=65535;p[18*16+:16]=2;p[19*16+:16]=2;p[14*16+:16]=65535;p[17*16+:16]=65535;p[10*16+:16]=65535;p[22*16+6]=1;p[22*16+7]=1;routes=32;reset;
  for(n=0;n<300;n=n+1)frame(12345,-23456);
  if(ol!==12345||orr!==-23456||dut.p[12]!=0||dut.p[15]!=0)$fatal(1,"modulation bypass must preserve target dry unity");
  $display("PASS dual delay: parallel vs cascade impulses, full 4096-frame memory, six stereo bypasses, serial bypass and smooth transitions within 32 clocks");$finish;
 end
 initial begin #20000000;$fatal(1,"dual delay timeout");end
endmodule
