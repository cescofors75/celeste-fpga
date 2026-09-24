`default_nettype none
// ADC is master: 24-bit I2S, 32 BCK/channel, LRCK low=left.
// RX captures on rising edges. TX uses falling edges and delays LRCK by one
// BCK so it never races the ADC's LRCK output changing on that same edge.
module i2s_slave(input wire bck,rst,lrck,din,
 output reg valid,output reg [47:0] received,
 input wire [47:0] transmit,input wire enabled,
 output reg tx_lrck,tx_dout);
 reg channel,left_ok,right_ok,seen;
 reg [5:0] bits;
 reg [23:0] shift,left_word,right_word;
 reg [47:0] tx_held;
 reg tx_channel;reg [5:0] tx_bits;
 always @(posedge bck or posedge rst)begin
  if(rst)begin channel<=1;bits<=0;shift<=0;left_word<=0;right_word<=0;left_ok<=0;right_ok<=0;valid<=0;received<=0;seen<=0;end
  else begin
   valid<=0;
   if(lrck!=channel)begin
    channel<=lrck;bits<=0;shift<=0;seen<=1;
    if(!lrck)begin
     if(seen&&bits==31&&left_ok&&right_ok)begin received<={right_word,left_word};valid<=1;end
     left_ok<=0;right_ok<=0;
    end else if(bits!=31)left_ok<=0;
   end else if(seen)begin
    if(bits!=63)bits<=bits+1'b1;
    if(bits<24)begin
     shift<={shift[22:0],din};
     if(bits==23)begin
      if(!channel)begin left_word<={shift[22:0],din};left_ok<=1;end
      else begin right_word<={shift[22:0],din};right_ok<=1;end
     end
    end
   end
  end
 end
 always @(negedge bck or posedge rst)begin
  if(rst)begin tx_channel<=1;tx_bits<=0;tx_lrck<=1;tx_dout<=0;tx_held<=0;end
  else if(channel!=tx_channel)begin
   tx_channel<=channel;tx_lrck<=channel;tx_bits<=0;tx_dout<=0;
   if(!channel)tx_held<=enabled?transmit:48'd0;
  end else begin
   if(tx_bits!=63)tx_bits<=tx_bits+1'b1;
   if(!enabled)tx_dout<=0;
   else if(tx_bits<24)tx_dout<=channel?tx_held[47-tx_bits]:tx_held[23-tx_bits];
   else tx_dout<=0;
  end
 end
endmodule
`default_nettype wire
