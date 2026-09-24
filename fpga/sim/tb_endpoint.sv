`timescale 1ns/1ps
module tb_endpoint;
 reg clk=0,rst=1,rx_valid=0,tx_ready=1;always #5 clk=~clk;
 reg [7:0] rx_data=0;wire ready,tx_valid,bck,lrck,dout;wire [7:0] tx_data;
 stream_endpoint dut(.clk_audio(clk),.rst(rst),.rx_valid(rx_valid),.rx_data(rx_data),.rx_ready(ready),.tx_valid(tx_valid),.tx_data(tx_data),.tx_ready(tx_ready),.pcm_bck(bck),.pcm_lrck(lrck),.pcm_din(dout),.encoder_press(1'b0),.encoder_event(1'b0),.encoder_index(3'd0),.encoder_delta(32'd0),.bank_switch(1'b0),.panel_online(1'b0));
 reg [7:0] ping[0:11],status_packet[0:11],start_packet[0:11],stop_packet[0:11],drain_packet[0:11],param[0:11],audio[0:15];
 reg [7:0] received[0:63];integer received_count=0,expected_count=12,i;
 reg [31:0] left,right;
 reg [15:0] crc;
 function automatic [15:0] crc_byte(input [15:0] c,input [7:0] b);
  reg [15:0] v;integer j;begin v=c^{b,8'b0};for(j=0;j<8;j=j+1)v=v[15]?(v<<1)^16'h1021:v<<1;crc_byte=v;end
 endfunction
 always @(posedge clk)if(tx_valid&&tx_ready)begin received[received_count]=tx_data;received_count=received_count+1;end
 task send(input [7:0] b);begin
  @(negedge clk);while(!ready)@(negedge clk);rx_valid=1;rx_data=b;@(negedge clk);rx_valid=0;
 end endtask
 task check_response(input [7:0] kind,input integer length);integer j;begin
  wait(received_count==length+12);@(negedge clk);
  if(received[0]!=8'h43||received[1]!=8'h45||received[2]!=1||received[3]!=kind||received[8]!=length||received[9]!=0)$fatal(1,"Response header");
  crc=16'hffff;for(j=2;j<length+10;j=j+1)crc=crc_byte(crc,received[j]);
  if({received[length+11],received[length+10]}!=crc)$fatal(1,"Response CRC");
  received_count=0;
 end endtask
 initial begin
  $readmemh("fpga/sim/ping_packet.hex",ping);$readmemh("fpga/sim/status_packet.hex",status_packet);
  $readmemh("fpga/sim/start_packet.hex",start_packet);$readmemh("fpga/sim/stop_packet.hex",stop_packet);
  $readmemh("fpga/sim/drain_packet.hex",drain_packet);$readmemh("fpga/sim/param_packet.hex",param);$readmemh("fpga/sim/audio_packet.hex",audio);
  repeat(5)@(negedge clk);rst=0;
  tx_ready=0;for(i=0;i<12;i=i+1)send(ping[i]);repeat(30)@(negedge clk);
  if(received_count!=0||!tx_valid)$fatal(1,"TX backpressure");tx_ready=1;check_response(8'h81,9);
  if({received[10],received[11],received[12],received[13],received[14],received[15],received[16],received[17],received[18]}!="CELESTE/1")$fatal(1,"Ping payload");
  for(i=0;i<16;i=i+1)send(audio[i]);check_response(8'h84,0);
  if({received[7],received[6],received[5],received[4]}!=32'h12345678)$fatal(1,"Sequence echo");
  for(i=0;i<12;i=i+1)send(status_packet[i]);check_response(8'h82,32);
  if({received[17],received[16]}!=1||{received[13],received[12],received[11],received[10]}!=48000)$fatal(1,"Status fill/rate");
  for(i=0;i<12;i=i+1)send(drain_packet[i]);check_response(8'h87,0);
  for(i=0;i<12;i=i+1)send(start_packet[i]);check_response(8'h85,0);
  wait(dut.source_valid);@(posedge clk);@(posedge bck); // skip I2S delay bit
  left=0;right=0;
  for(i=0;i<32;i=i+1)begin @(posedge bck);left={left[30:0],dout};end
  for(i=0;i<32;i=i+1)begin @(posedge bck);right={right[30:0],dout};end
  if(left!==32'h80000000||right!==32'h7fff0000)$fatal(1,"End-to-end I2S mismatch %h %h",left,right);
  wait(!dut.running);
  if(dut.samples!=1||dut.under!=0)$fatal(1,"Clean finite drain");
  if(dut.nonzero_samples!=1||dut.sum_l!=32768||dut.sum_r!=32767||dut.peak_l!=32768||dut.peak_r!=32767||dut.din_ones!=16)$fatal(1,"I2S diagnostics must measure real signed samples and transmitted bits");
  for(i=0;i<12;i=i+1)send(param[i]);check_response(8'hff,1);if(received[10]!=1)$fatal(1,"Unsupported params must fail");
  for(i=0;i<12;i=i+1)send(stop_packet[i]);check_response(8'h86,0);if(dut.fill!=0)$fatal(1,"Stop");
  $display("PASS endpoint: Rust packets -> staging -> FIFO -> serialized I2S; PING/status/ACK/CRC/drain/backpressure");$finish;
 end
 initial begin #1000000;$fatal(1,"Endpoint timeout");end
endmodule
