`timescale 1ns/1ps
module tb_sonic_controls;
 reg clk=0,rst=1,ce=0;always #5 clk=~clk;
 reg [511:0] p=0;reg signed [15:0] l=0,r=0;
 wire signed [15:0] ol,orr;wire [239:0] meters;
 parallel_fabric dut(clk,rst,ce,l,r,p,6'd63,ol,orr,meters);
 integer i,j,last,step,maxstep;
 task tick;begin ce=1;@(negedge clk);ce=0;repeat(31)@(negedge clk);
 if((^ol)===1'bx||(^orr)===1'bx)$fatal(1,"Unknown output");
 if(dut.phase!=0)$fatal(1,"DSP must finish within 32 clocks");end endtask
 task reset;begin rst=1;repeat(3)@(negedge clk);rst=0;end endtask
 initial begin
 p[10*16+:16]=65535;p[14*16+:16]=65535;p[17*16+:16]=65535;
 p[12*16+:16]=65535;p[18*16+:16]=2;reset();l=12000;r=-7000;
 dut.lfo_phase=32'h7fffffff;tick();if(ol!=0||orr!=0)$fatal(1,"Full depth must close VCA");
 dut.lfo_phase=0;tick();if(ol!=12000||orr!= -7000)$fatal(1,"Full depth must also reach unity");
 p[15*16+:16]=65535;p[19*16+:16]=2;reset();dut.lfo_phase=32'h7fffffff;dut.chaos_value=65535;tick();
 if(ol!=0||orr!=0)$fatal(1,"Combined modulation must clamp at silence, never wrap");
 // Grain length changes are deferred to a new capture, never read unfilled RAM.
 p=0;p[10*16+:16]=65535;p[7*16+:16]=65535;p[0+:16]=65535;p[16+:16]=65535;
 p[23*16+:16]=65535;p[29*16+:16]=65535;p[30*16+:16]=65535;reset();
 for(i=0;i<2100;i=i+1)begin l=i;r=-i;tick();end
 p[29*16+:16]=0;
 for(i=0;i<34000;i=i+1)begin l=i%4000;r=0;tick();end
 if(dut.grain_length!=256)$fatal(1,"New grain size not applied after repeat cycle");
 // Safe filter mode transitions: a bounded fade, with no register slew through other modes.
 p=0;p[10*16+:16]=65535;p[9*16+:16]=65535;p[4*16+:16]=18000;reset();l=6000;r=0;
 for(i=0;i<512;i=i+1)tick();last=ol;maxstep=0;
 for(j=1;j<4;j=j+1)begin p[28*16+:16]=j*16384;
 for(i=0;i<100;i=i+1)begin tick();step=ol-last;if(step<0)step=-step;if(step>maxstep)maxstep=step;last=ol;end
 if(dut.filter_mode!=j||dut.filter_fade!=65535)$fatal(1,"Mode transition did not settle");end
 if(maxstep>500)$fatal(1,"Mode change click: %0d",maxstep);
 // Chaos rate is an actual target-update rate, not an inert UI field.
 p=0;p[31*16+:16]=0;reset();for(i=0;i<5000;i=i+1)tick();
 if(dut.chaos_target!=32768)$fatal(1,"Slow Chaos updated prematurely");
 p[31*16+:16]=65535;reset();for(i=0;i<5000;i=i+1)tick();
 if(dut.chaos_target==32768)$fatal(1,"Fast Chaos never updated");
 $display("PASS sonic controls: VCA extrema, combined clamp, grain resize, smooth filter modes, Chaos rate, 32-clock deadline");$finish;
 end
 initial begin #100000000;$fatal(1,"Sonic test timeout");end
endmodule
