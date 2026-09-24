`timescale 1ns/1ps
module tb_wide_status;
 reg clk=0,rst=1,rv=0;always #5 clk=~clk;
 reg [7:0] data=0;wire ready,tv;wire [7:0] td;
 stream_endpoint #(.DEPTH(131072)) dut(.clk_audio(clk),.rst(rst),.rx_valid(rv),.rx_data(data),.rx_ready(ready),.tx_valid(tv),.tx_data(td),.tx_ready(1'b1),.encoder_press(1'b0),.encoder_event(1'b0),.encoder_index(3'd0),.encoder_delta(32'd0),.panel_online(1'b0),.bypass_toggle(1'b0),.bank_switch(1'b0));
 reg [7:0] packet[0:11],reply[0:51];integer count=0,i,j;reg [15:0] crc;
 function automatic [15:0] step(input [15:0] c,input [7:0] b);
  reg [15:0] v;integer n;begin v=c^{b,8'b0};for(n=0;n<8;n=n+1)v=v[15]?(v<<1)^16'h1021:v<<1;step=v;end
 endfunction
 always @(posedge clk)if(tv)begin reply[count]=td;count=count+1;end
 task query;begin
  count=0;for(i=0;i<12;i=i+1)begin @(negedge clk);while(!ready)@(negedge clk);rv=1;data=packet[i];@(negedge clk);rv=0;end
  wait(count==52);@(negedge clk);
  if(reply[3]!=8'h82||reply[8]!=40||reply[9]!=0)$fatal(1,"Wide status framing");
  crc=16'hffff;for(j=2;j<50;j=j+1)crc=step(crc,reply[j]);if({reply[51],reply[50]}!=crc)$fatal(1,"Wide status CRC");
  if({reply[45],reply[44],reply[43],reply[42]}!=131072||{reply[15],reply[14]}!=65535||!reply[39][4])$fatal(1,"Wide capacity/capability");
 end endtask
 initial begin
  $readmemh("fpga/sim/status_packet.hex",packet);repeat(5)@(negedge clk);rst=0;
  force dut.fill=18'd100000;query();
  if({reply[49],reply[48],reply[47],reply[46]}!=100000||{reply[17],reply[16]}!=65535)$fatal(1,"Full width fill truncated");
  force dut.fill=18'd42;query();
  if({reply[49],reply[48],reply[47],reply[46]}!=42||{reply[17],reply[16]}!=42)$fatal(1,"Small fill mismatch");
  release dut.fill;$display("PASS wide FIFO status: 131072 capacity, 100000/42 fill, saturated prefix, capability, CRC");$finish;
 end
 initial begin #1000000;$fatal(1,"Timeout");end
endmodule
