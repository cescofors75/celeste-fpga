`timescale 1ns/1ps
module tb_controls;
 reg bypass_toggle=0,bank=0;
 reg clk=0,rst=1,valid=0,encoder=0;always #5 clk=~clk;
 reg [7:0] data;wire ready,tv;wire [7:0] td;reg [2:0] index=0;reg signed [31:0] delta=0;
 wire [511:0] values;wire [39:0] mapping;wire [31:0] revision;wire [5:0] routes;
 stream_endpoint #(.DSP(1)) dut(.clk_audio(clk),.rst(rst),.rx_valid(valid),.rx_data(data),.rx_ready(ready),.tx_valid(tv),.tx_data(td),.tx_ready(1'b1),.encoder_press(1'b0),.encoder_event(encoder),.encoder_index(index),.encoder_delta(delta),.bank_switch(bank),.panel_online(1'b1),.control_values(values),.control_mappings(mapping),.control_routes(routes),.bypass_toggle(bypass_toggle),.control_revision(revision));
 reg [7:0] packet[0:15],response[0:127];integer count=0,i;reg [15:0] crc;
 function automatic [15:0] crc_byte(input [15:0] c,input [7:0] b);reg [15:0] v;integer j;begin v=c^{b,8'b0};for(j=0;j<8;j=j+1)v=v[15]?(v<<1)^16'h1021:v<<1;crc_byte=v;end endfunction
 always @(posedge clk)if(tv)begin response[count]=td;count=count+1;end
 task command(input [7:0] kind,input [15:0] id,value,input integer length,expected);begin
  count=0;packet[0]=8'h43;packet[1]=8'h45;packet[2]=1;packet[3]=kind;packet[4]=19;packet[5]=0;packet[6]=0;packet[7]=0;packet[8]=length;packet[9]=0;
  packet[10]=id[7:0];packet[11]=id[15:8];packet[12]=value[7:0];packet[13]=value[15:8];
  crc=16'hffff;for(i=2;i<10+length;i=i+1)crc=crc_byte(crc,packet[i]);packet[10+length]=crc[7:0];packet[11+length]=crc[15:8];
  for(i=0;i<12+length;i=i+1)begin @(negedge clk);while(!ready)@(negedge clk);valid=1;data=packet[i];@(negedge clk);valid=0;end
  wait(count==expected+12);repeat(6)@(negedge clk);
  crc=16'hffff;for(i=2;i<10+expected;i=i+1)crc=crc_byte(crc,response[i]);if({response[11+expected],response[10+expected]}!=crc)$fatal(1,"Response CRC");
 end endtask
 initial begin
  repeat(5)@(negedge clk);rst=0;
  command(3,4,16'd54321,4,0);if(values[4*16+:16]!=54321||revision!=1)$fatal(1,"SET_PARAM staging/commit");
  command(3,40,4,4,0);if(mapping[3:0]!=4)$fatal(1,"Encoder mapping");
  delta=2;encoder=1;@(negedge clk);encoder=0;repeat(3)@(negedge clk);
  if(values[4*16+:16]!=55345)$fatal(1,"Physical encoder update");
  command(3,32,15,4,0);if(routes!=15)$fatal(1,"Route register");
  command(9,0,0,0,110);if({response[19],response[18]}!=55345||response[74]!=4||response[82]!=15||!response[83][0])$fatal(1,"Readback snapshot");
  command(3,40,99,4,1);if(response[3]!=255||mapping[3:0]!=4)$fatal(1,"Invalid mapping accepted");
  delta=-32;encoder=1;@(negedge clk);encoder=0;
  command(3,20,65535,4,0);if(values[20*16+:16]!=65535)$fatal(1,"Host bypass ON");
  @(negedge clk);bypass_toggle=1;@(negedge clk);bypass_toggle=0;repeat(2)@(negedge clk);
  if(values[20*16+:16]!=0)$fatal(1,"Touch must toggle same bypass register OFF");
  @(negedge clk);bypass_toggle=1;@(negedge clk);bypass_toggle=0;repeat(2)@(negedge clk);
  command(9,0,0,0,110);if({response[51],response[50]}!=65535)$fatal(1,"Touch bypass must appear in readback");
  @(negedge clk);bank=1;repeat(3)@(negedge clk);
  if(mapping[4:0]!=13||values[21*16+:16]!=65535)$fatal(1,"Bank 1 default mapping");
  delta=2;encoder=1;@(negedge clk);encoder=0;repeat(3)@(negedge clk);
  if(values[13*16+:16]!=1024)$fatal(1,"Bank 1 must control wavefolder");
  command(3,48,14,4,0);if(mapping[4:0]!=14)$fatal(1,"Bank 1 remapping");
  command(9,0,0,0,110);if(!response[83][4]||response[74]!=14)$fatal(1,"Bank 1 snapshot");
  command(3,21,0,4,1);if(response[3]!=255)$fatal(1,"Bank register must be read-only");
  command(3,22,165,4,0);command(3,24,43210,4,0);command(3,25,12345,4,0);command(3,26,50000,4,0);command(3,27,3,4,0);
  command(9,0,0,0,110);if({response[55],response[54]}!=165||{response[59],response[58]}!=43210||{response[65],response[64]}!=3||response[88]!=6)$fatal(1,"Dual delay controls/snapshot version");
  @(negedge clk);bank=0;repeat(3)@(negedge clk);
  if(mapping[4:0]!=4)$fatal(1,"Bank 0 mapping must survive switching");
  command(3,40,24,4,0);if(mapping[4:0]!=24)$fatal(1,"Delay 2 mapping rejected");
  command(3,40,31,4,0);if(mapping[4:0]!=31)$fatal(1,"Chaos speed mapping rejected");
  command(3,40,27,4,1);if(response[3]!=255||mapping[4:0]!=31)$fatal(1,"Reserved mapping accepted");
  command(3,40,21,4,1);if(response[3]!=255||mapping[4:0]!=31)$fatal(1,"Read-only bank mapping accepted");
  $display("PASS controls: framed writes/readback/CRC, routing, mapped encoder updates, invalid command rejection");$finish;
 end
 initial begin #1000000;$fatal(1,"Control timeout");end
endmodule
