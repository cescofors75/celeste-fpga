`timescale 1ns/1ps
module tb_line_in;
 reg clk=0,adc_clk=0,rst=1,adc_rst=1,clocks_on=1,bad_lr=0,start=0,stop=0;
 real half_period=5.001;
 always #5 clk=~clk;
 initial begin #2;forever begin #(half_period) adc_clk=~adc_clk;end end
 wire bck,lrck,dout,ce;
 i2s_tx adc(adc_clk,adc_rst,24'h812345,24'h6abcde,ce,bck,lrck,dout);
 wire adc_bck=clocks_on?bck:1'b0;
 wire pb,pl,pd,running,valid;wire signed [15:0] sl,sr;
 wire [255:0] clock_diagnostics;wire [31:0] samples,faults;wire [239:0] meters;
 reg [511:0] params=0;
 line_in_audio dut(clk,rst,start,stop,adc_bck,bad_lr?1'b0:lrck,dout,params,6'd0,pb,pl,pd,running,valid,sl,sr,samples,faults,meters,clock_diagnostics);
 integer received=0,n,k;reg [23:0] l,r;reg [31:0] before_count;
 always @(posedge clk)if(valid)begin
  if(sl!==16'h8123||sr!==16'h6abc)$fatal(1,"RX channel/sign/alignment mismatch %h %h",sl,sr);
  received=received+1;
 end
 task decode_frame;
 begin
  @(negedge pl);@(posedge pb);l=0;r=0;
  for(k=0;k<24;k=k+1)begin @(posedge pb);#1;l={l[22:0],pd};end
  @(posedge pl);@(posedge pb);
  for(k=0;k<24;k=k+1)begin @(posedge pb);#1;r={r[22:0],pd};end
 end endtask
 initial begin
  params[20*16+:16]=65535; // true DSP bypass, smoothed at startup
  params[10*16+:16]=65535;
  repeat(8)@(negedge clk);rst=0;adc_rst=0;
  repeat(85000)@(negedge clk);
  if(!running||received<300)$fatal(1,"No 48k lock");
  repeat(12)begin decode_frame();if(l!==24'h812300||r!==24'h6abc00)$fatal(1,"DAC bypass mismatch %h %h",l,r);end
  @(negedge clk);stop=1;@(negedge clk);stop=0;
  repeat(800)@(negedge clk);decode_frame();if(l!==0||r!==0||running)$fatal(1,"STOP did not mute");
  @(negedge clk);start=1;@(negedge clk);start=0;
  repeat(85000)@(negedge clk);decode_frame();if(l!==24'h812300||r!==24'h6abc00)$fatal(1,"Restart failed");
  clocks_on=0;repeat(2400)@(negedge clk);if(running||faults==0)$fatal(1,"Clock loss not detected");
  before_count=samples;repeat(2400)@(negedge clk);if(samples!=before_count)$fatal(1,"Invented samples without clock");
  clocks_on=1;repeat(85000)@(negedge clk);if(!running)$fatal(1,"Clock recovery failed");
  half_period=2.5;repeat(6000)@(negedge clk);if(running)$fatal(1,"Accepted 96k input");
  decode_frame();if(l!==0||r!==0)$fatal(1,"Invalid rate not muted");
  half_period=5.001;repeat(85000)@(negedge clk);if(!running)$fatal(1,"48k recovery failed");
  bad_lr=1;repeat(3000)@(negedge clk);if(running)$fatal(1,"Malformed slots accepted");
  bad_lr=0;repeat(10000)@(negedge clk);if(!running)$fatal(1,"Framing recovery failed");
  $display("PASS LINE IN: asynchronous ADC clock, stereo signs, 24->16, DSP bypass, DAC I2S, stop/start, clock loss/recovery, bad rate/slots");$finish;
 end
 initial begin #10000000;$fatal(1,"line in timeout");end
endmodule
