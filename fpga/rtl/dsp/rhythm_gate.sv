`default_nettype none
// All four rhythms span exactly 96000 accepted frames (one bar at 120 BPM).
// Subdivisions 16:12:10:7 are independent phase accumulators, not serial FX.
module rhythm_gate(input wire clk,rst,ce,input wire signed [15:0] in_l,in_r,
 input wire [63:0] knobs,input wire turing,
 output reg signed [15:0] out_l,out_r,output wire [63:0] patterns,
 output wire [15:0] steps,output wire [31:0] levels,output reg [3:0] accepted,
 output reg [15:0] ring);
 function [15:0] euclid16(input [4:0] k);
 begin case(k)
  1:euclid16=16'h0001;2:euclid16=16'h0101;3:euclid16=16'h0421;4:euclid16=16'h1111;
  5:euclid16=16'h1249;6:euclid16=16'h2525;7:euclid16=16'h2a55;8:euclid16=16'h5555;
  9:euclid16=16'h55ab;10:euclid16=16'h5b5b;11:euclid16=16'h6db7;12:euclid16=16'h7777;
  13:euclid16=16'h7bdf;14:euclid16=16'h7f7f;15:euclid16=16'h7fff;16:euclid16=16'hffff;
  default:euclid16=16'h1249;endcase end endfunction
 wire [15:0] a=euclid16(knobs[4:0]);
 wire [15:0] rotated={a,a}>>(16-knobs[11:8]);
 assign patterns={16'h0009,16'h0049,16'h0295,rotated};
 reg [16:0] phase[0:3];reg [3:0] step[0:3];reg [7:0] env[0:3],target[0:3];
 reg [15:0] random_state[0:3];reg first;
 wire [3:0] enabled=knobs[17:16]==0?4'b0001:knobs[17:16]==1?4'b0011:4'b1111;
 genvar g;generate for(g=0;g<4;g=g+1)begin
  assign steps[g*4+:4]=step[g];assign levels[g*8+:8]=env[g];
 end endgenerate
 integer i,n;reg [17:0] sum_phase;reg boundary;reg [3:0] next_step;
 reg event_on;reg [7:0] next_target,next_env;reg [10:0] total;
 reg signed [27:0] product_l,product_r;reg [7:0] gain,desired_gain,smooth_gain;
 always @(posedge clk)begin
  if(rst)begin
   first<=1;out_l<=0;out_r<=0;ring<=16'hb4d3;accepted<=0;smooth_gain<=0;
   for(i=0;i<4;i=i+1)begin phase[i]<=0;step[i]<=0;env[i]<=0;target[i]<=0;random_state[i]<=16'hace1^(16'h1234*i);end
  end else if(ce)begin
   first<=0;total=0;
   for(i=0;i<4;i=i+1)begin
    case(i)0:n=16;1:n=12;2:n=10;default:n=7;endcase
    sum_phase={1'b0,phase[i]}+n;
    boundary=first||sum_phase>=96000;
    next_step=first?0:sum_phase>=96000?(step[i]==n-1?0:step[i]+1'b1):step[i];
    phase[i]<=first?0:sum_phase>=96000?sum_phase-96000:sum_phase;
    step[i]<=next_step;next_target=target[i];
    if(boundary)begin
     event_on=patterns[i*16+next_step]&&(knobs[39:32]==16||{1'b0,random_state[i][3:0]}<knobs[39:32]);
     next_target=event_on?(turing&&!ring[i*4]?8'd96:8'd128):0;
     target[i]<=next_target;accepted[i]<=event_on&&enabled[i];
     random_state[i]<={random_state[i][14:0],random_state[i][15]^random_state[i][13]^random_state[i][12]^random_state[i][10]};
     if(i==0)ring<={ring[14:0],ring[15]^(turing&&({1'b0,random_state[0][7:4]}<knobs[31:24]))};
    end
    if(!enabled[i])begin next_target=0;accepted[i]<=0;end
    next_env=env[i]<next_target?env[i]+1'b1:env[i]>next_target?env[i]-1'b1:env[i];
    env[i]<=next_env;total=total+next_env;
   end
   // Bound the parallel sum to unity; no clipping, even on coincident events.
   desired_gain=knobs[17:16]==0?(total>128?128:total):knobs[17:16]==1?(total>256?128:total>>1):total>>2;
   gain=smooth_gain<desired_gain?smooth_gain+1'b1:smooth_gain>desired_gain?smooth_gain-1'b1:smooth_gain;
   smooth_gain<=gain;
   product_l=$signed(in_l)*$signed({1'b0,gain});product_r=$signed(in_r)*$signed({1'b0,gain});
   out_l<=product_l>>>7;out_r<=product_r>>>7;
  end
 end
endmodule
`default_nettype wire
