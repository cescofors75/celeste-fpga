`default_nettype none
module rhythm_controls(input wire clk,rst,encoder_event,input wire [2:0] encoder_index,
 input wire signed [31:0] encoder_delta,input wire encoder_press,touch_pulse,
 output reg [63:0] knobs,output reg dry,turing);
 reg signed [33:0] value;reg [7:0] lo,hi;
 always @*begin
  lo=0;hi=16;
  case(encoder_index)
   0:begin lo=1;hi=16;end
   1:hi=15;
   2:hi=2;
   5:hi=3;
   6:hi=64;
   7:hi=96;
   default:begin end
  endcase
  value=$signed({1'b0,knobs[encoder_index*8+:8]})+$signed(encoder_delta);
 end
 always @(posedge clk)begin
  if(rst)begin knobs<=64'h3020011000000005;dry<=0;turing<=0;end
  else begin
   if(touch_pulse)dry<=!dry;
   if(encoder_press&&encoder_index==3)turing<=!turing;
   if(encoder_event)begin
    if(encoder_index==1)knobs[8+:8]<={4'd0,knobs[11:8]+encoder_delta[3:0]};
    else knobs[encoder_index*8+:8]<=value<$signed({1'b0,lo})?lo:value>$signed({1'b0,hi})?hi:value[7:0];
    if(encoder_index==3)turing<=1;
   end
  end
 end
endmodule
`default_nettype wire
