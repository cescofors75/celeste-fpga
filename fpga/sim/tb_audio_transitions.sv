`timescale 1ns/1ps
module tb_audio_transitions;
 reg clk=0,rst=1,ce=0;always #5 clk=~clk;
 reg [383:0] p=0;reg [5:0] routes=32;wire signed [15:0] l,r;
 reg signed [15:0] source=16000;
 parallel_fabric dut(clk,rst,ce,source,-source,p,routes,l,r,);
 integer i,previous,delta,largest=0;
 task tick;begin ce=1;@(negedge clk);ce=0;repeat(7)@(negedge clk);end endtask
 task settle;begin for(i=0;i<300;i=i+1)tick();end endtask
 task ramp_check;begin previous=l;for(i=0;i<300;i=i+1)begin tick();delta=l-previous;if(delta<0)delta=-delta;if(delta>largest)largest=delta;if(delta>128)$fatal(1,"Discontinuous control ramp: %0d LSB",delta);previous=l;end end endtask
 initial begin
  p[10*16+:16]=65535;p[14*16+:16]=65535;p[17*16+:16]=65535;
  repeat(3)@(negedge clk);rst=0;settle();if(l!=16000||r!=-16000)$fatal(1,"Initial unity VCA");
  routes=0;ramp_check();if(l!=0||r!=0)$fatal(1,"Route fade must reach silence");
  p[20*16+:16]=65535;ramp_check();if(l!=16000||r!=-16000)$fatal(1,"Bypass unity");
  p[10*16+:16]=0;ramp_check();if(l!=0||r!=0)$fatal(1,"Master mute");
  p[10*16+:16]=65535;ramp_check();
  p[20*16+:16]=0;ramp_check();if(l!=0)$fatal(1,"Bypass restore");
  routes=32;ramp_check();if(l!=16000)$fatal(1,"Route restore");
  p[14*16+:16]=0;ramp_check();if(l!=0)$fatal(1,"VCA mute");
  // Four independent unity paths must saturate at the final output, never wrap.
  p[6*16+:16]=65535;p[7*16+:16]=65535;p[16*16+:16]=65535;p[14*16+:16]=65535;routes=51;source=30000;settle();
  if(l!=32767||r!=-32768)$fatal(1,"Wide sum must saturate both signs");
  p[10*16+:16]=16384;settle();if(l!=30000||r!=-30000)$fatal(1,"Master must recover pre-clip headroom");
  rst=1;repeat(3)@(negedge clk);if(l!=0||r!=0)$fatal(1,"Reset must clear output");
  $display("PASS dynamics: route/bypass/master/VCA fades, max step %0d LSB; positive/negative headroom; saturation; reset",largest);$finish;
 end
 initial begin #1000000;$fatal(1,"Dynamics timeout");end
endmodule
