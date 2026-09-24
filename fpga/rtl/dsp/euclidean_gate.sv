`default_nettype none
// Fixed N=16, 120 BPM, one sixteenth-note step per 6000 accepted 48 kHz frames.
// No generated clock, delay memory, pitch operation, filter or distortion.
module euclidean_gate(input wire clk,rst,ce,input wire signed [15:0] in_l,in_r,
 input wire [4:0] pulses,input wire [3:0] rotation,input wire dry,
 output reg signed [15:0] out_l,out_r,output wire [15:0] pattern,
 output reg [3:0] step,output reg [7:0] envelope);
 reg [15:0] base_pattern;
 always @*begin
  case(pulses)
   5'd1:base_pattern=16'h0001;
   5'd2:base_pattern=16'h0101;
   5'd3:base_pattern=16'h0421;
   5'd4:base_pattern=16'h1111;
   5'd5:base_pattern=16'h1249;
   5'd6:base_pattern=16'h2525;
   5'd7:base_pattern=16'h2a55;
   5'd8:base_pattern=16'h5555;
   5'd9:base_pattern=16'h55ab;
   5'd10:base_pattern=16'h5b5b;
   5'd11:base_pattern=16'h6db7;
   5'd12:base_pattern=16'h7777;
   5'd13:base_pattern=16'h7bdf;
   5'd14:base_pattern=16'h7f7f;
   5'd15:base_pattern=16'h7fff;
   5'd16:base_pattern=16'hffff;
   default:base_pattern=16'h1249; // K=5, bit zero is the first displayed step.
  endcase
 end
 // Positive rotation moves events to later steps, cyclically.
 assign pattern={base_pattern,base_pattern}>>(5'd16-{1'b0,rotation});
 reg [12:0] sample_count;
 wire [3:0] playing_step=sample_count==13'd5999 ?step+4'd1:step;
 wire target=dry||pattern[playing_step];
 wire [7:0] next_envelope=target?(envelope<128?envelope+8'd1:8'd128):(envelope!=0?envelope-8'd1:8'd0);
 // Q7 amplitude: 128 is exactly unity, not 127/128. Signed arithmetic preserves
 // -32768 as well as +32767. At zero/unity the output is exact silence/input.
 wire signed [24:0] scaled_l=$signed(in_l)*$signed({1'b0,next_envelope});
 wire signed [24:0] scaled_r=$signed(in_r)*$signed({1'b0,next_envelope});
 always @(posedge clk)begin
  if(rst)begin sample_count<=5999;step<=15;envelope<=0;out_l<=0;out_r<=0;end
  else if(ce)begin
   sample_count<=sample_count==5999?13'd0:sample_count+13'd1;
   step<=playing_step;envelope<=next_envelope;
   out_l<=scaled_l>>>7;out_r<=scaled_r>>>7;
  end
 end
endmodule
`default_nettype wire
