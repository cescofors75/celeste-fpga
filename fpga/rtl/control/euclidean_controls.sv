`default_nettype none
module euclidean_controls(input wire clk,rst,encoder_event,input wire [2:0] encoder_index,
 input wire signed [31:0] encoder_delta,input wire touch_pulse,
 output reg [4:0] pulses,output reg [3:0] rotation,output reg dry);
 wire signed [33:0] next_pulses=$signed({1'b0,pulses})+$signed(encoder_delta);
 always @(posedge clk)begin
  if(rst)begin pulses<=5;rotation<=0;dry<=0;end
  else begin
   if(touch_pulse)dry<=!dry;
   if(encoder_event)case(encoder_index)
    0:pulses<=next_pulses<1?5'd1:next_pulses>16?5'd16:next_pulses[4:0];
    1:rotation<=rotation+encoder_delta[3:0];
    default:begin end // Encoders 3..8, their buttons and the bank switch do nothing.
   endcase
  end
 end
endmodule
`default_nettype wire
