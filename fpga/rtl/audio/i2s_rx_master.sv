`default_nettype none
// BCK/LRCK are generated from clk by i2s_tx. Capture DOUT one clk after
// the rising BCK edge, with 3 clk periods since the ADC's falling-edge update.
// This is a source-synchronous input, constrained relative to outgoing BCK.
module i2s_rx_master(input wire clk,rst,bck,lrck,din,
 output reg valid,output reg [47:0] received);
 reg previous_bck,channel,seen,left_ok;
 reg [5:0] bits;reg [23:0] shift,left_word;
 always @(posedge clk)begin
  if(rst)begin previous_bck<=0;channel<=1;seen<=0;left_ok<=0;bits<=0;shift<=0;left_word<=0;received<=0;valid<=0;end
  else begin
   previous_bck<=bck;valid<=0;
   if(bck&&!previous_bck)begin
    if(lrck!=channel)begin channel<=lrck;bits<=0;shift<=0;seen<=1;if(!lrck)left_ok<=0;end
    else if(seen)begin
     if(bits!=63)bits<=bits+1'b1;
     if(bits<24)begin
      shift<={shift[22:0],din};
      if(bits==23)begin
       if(!channel)begin left_word<={shift[22:0],din};left_ok<=1;end
       else if(left_ok)begin received<={shift[22:0],din,left_word};valid<=1;left_ok<=0;end
      end
     end
    end
   end
  end
 end
endmodule
`default_nettype wire
