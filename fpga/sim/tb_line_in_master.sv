`timescale 1ns/1ps
module tb_line_in_master;
 reg clk=0,rst=1,start=0,stop=0,din=0,connected=1;
 always #5 clk=~clk;
 wire bck,lrck,dout,running,valid;wire signed [15:0] l,r;
 wire [31:0] samples,faults;wire [239:0] meters;
 reg [511:0] params=0;
 line_in_master_audio dut(clk,rst,start,stop,din,params,6'd0,bck,lrck,dout,running,valid,l,r,samples,faults,meters);
 // Independent PCM1808 slave model: samples update AFTER the falling BCK edge.
 reg prev_lr=1;integer bitno=0,received=0,k;reg [23:0] decoded_l,decoded_r;
 reg [23:0] input_l=24'h812345,input_r=24'h6abcde;
 time previous_edge=0;integer frame_cycles=0;
 always @(negedge bck)begin
  #1;
  if(rst)begin prev_lr=1;bitno=0;din=0;end
  else if(lrck!=prev_lr)begin prev_lr=lrck;bitno=0;din=0;end
  else begin
   if(bitno<24&&connected)din=lrck?input_r[23-bitno]:input_l[23-bitno];else din=0;
   bitno=bitno+1;
  end
 end
 always @(posedge clk)if(valid)begin
  if(connected&&(l!==input_l[23:8]||r!==input_r[23:8]))$fatal(1,"ADC alignment/sign mismatch %h %h",l,r);
  received=received+1;
 end
 always @(posedge bck)begin
  if(!rst&&previous_edge!=0&&$time-previous_edge!=40)$fatal(1,"BCK ratio is not MCLK/4");
  previous_edge=$time;
 end
 task decode;
 begin
  @(negedge lrck);@(posedge bck);decoded_l=0;decoded_r=0;
  for(k=0;k<24;k=k+1)begin @(posedge bck);#1;decoded_l={decoded_l[22:0],dout};end
  @(posedge lrck);@(posedge bck);
  for(k=0;k<24;k=k+1)begin @(posedge bck);#1;decoded_r={decoded_r[22:0],dout};end
 end endtask
 initial begin
  params[20*16+:16]=65535;params[10*16+:16]=65535;
  repeat(8)@(negedge clk);rst=0;
  repeat(90000)@(negedge clk);
  if(!running||received<300)$fatal(1,"No master frames");
  repeat(12)begin decode();if(decoded_l!==24'h812300||decoded_r!==24'h6abc00)$fatal(1,"DAC mismatch %h %h",decoded_l,decoded_r);end
  @(negedge clk);stop=1;@(negedge clk);stop=0;
  repeat(800)@(negedge clk);decode();if(running||decoded_l!==0||decoded_r!==0)$fatal(1,"STOP not silent");
  @(negedge clk);start=1;@(negedge clk);start=0;
  repeat(90000)@(negedge clk);decode();if(decoded_l!==24'h812300||decoded_r!==24'h6abc00)$fatal(1,"Restart failed");
  connected=0;repeat(1200)@(negedge clk);decode();if(decoded_l!==0||decoded_r!==0)$fatal(1,"Disconnected input not silent in bypass");
  $display("PASS Tang master: MCLK/4 BCK, ADC slave model, signed stereo, DSP bypass, DAC output, stop/start and disconnected silence");$finish;
 end
 initial begin #5000000;$fatal(1,"Master test timeout");end
endmodule
