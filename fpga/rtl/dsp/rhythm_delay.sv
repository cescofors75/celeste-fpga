`default_nettype none
// One stereo delay. Convex feedback/mix keep every arithmetic stage in range.
// Synchronous memory, no reset loop. Unwritten history is explicitly silent.
module rhythm_delay(input wire clk,rst,ce,input wire signed [15:0] in_l,in_r,dry_l,dry_r,
 input wire [1:0] division,input wire [7:0] mix,feedback,input wire dry,
 output reg signed [15:0] out_l,out_r);
 reg [31:0] memory[0:16383];reg [31:0] read_data;
 reg [13:0] wr;reg [14:0] filled;reg [1:0] current_division;
 reg [7:0] fade,mix_s,fb_s,bypass_s;reg pending,history_valid;
 reg signed [15:0] held_l,held_r,held_dry_l,held_dry_r;
 wire [13:0] length=current_division==0?14'd3000:current_division==1?14'd6000:current_division==2?14'd9000:14'd12000;
 wire [13:0] rd=wr-length;
 reg [7:0] wet,fb;reg signed [15:0] tap_l,tap_r;
 wire [15:0] wet_product=mix_s*fade,feedback_product=fb_s*fade;
 reg signed [31:0] store_l,store_r,mixed_l,mixed_r,result_l,result_r;
 // Read and write enables are outside reset so Gowin infers block RAM.
 always @(posedge clk)begin
  if(ce&&!rst)read_data<=memory[rd];
  if(pending&&!rst)memory[wr]<={store_r[15:0],store_l[15:0]};
 end
 always @*begin
  wet=wet_product>>7;fb=feedback_product>>7;
  tap_l=history_valid?$signed(read_data[15:0]):16'sd0;
  tap_r=history_valid?$signed(read_data[31:16]):16'sd0;
  store_l=($signed(held_l)*$signed(9'd128-{1'b0,fb})+$signed(tap_l)*$signed({1'b0,fb}))>>>7;
  store_r=($signed(held_r)*$signed(9'd128-{1'b0,fb})+$signed(tap_r)*$signed({1'b0,fb}))>>>7;
  mixed_l=($signed(held_l)*$signed(9'd128-{1'b0,wet})+$signed(tap_l)*$signed({1'b0,wet}))>>>7;
  mixed_r=($signed(held_r)*$signed(9'd128-{1'b0,wet})+$signed(tap_r)*$signed({1'b0,wet}))>>>7;
  result_l=(mixed_l*$signed(9'd128-{1'b0,bypass_s})+$signed(held_dry_l)*$signed({1'b0,bypass_s}))>>>7;
  result_r=(mixed_r*$signed(9'd128-{1'b0,bypass_s})+$signed(held_dry_r)*$signed({1'b0,bypass_s}))>>>7;
 end
 always @(posedge clk)begin
  if(rst)begin
   wr<=0;filled<=0;current_division<=1;fade<=0;mix_s<=0;fb_s<=0;bypass_s<=0;
   pending<=0;history_valid<=0;held_l<=0;held_r<=0;held_dry_l<=0;held_dry_r<=0;out_l<=0;out_r<=0;
  end else begin
   pending<=ce;
   if(ce)begin
    held_l<=in_l;held_r<=in_r;held_dry_l<=dry_l;held_dry_r<=dry_r;
    history_valid<=filled>=length;
    if(division!=current_division)begin if(fade!=0)fade<=fade-1'b1;else current_division<=division;end
    else if(fade<128)fade<=fade+1'b1;
    if(mix_s<mix)mix_s<=mix_s+1'b1;else if(mix_s>mix)mix_s<=mix_s-1'b1;
    if(fb_s<feedback)fb_s<=fb_s+1'b1;else if(fb_s>feedback)fb_s<=fb_s-1'b1;
    if(dry&&bypass_s<128)bypass_s<=bypass_s+1'b1;
    else if(!dry&&bypass_s!=0)bypass_s<=bypass_s-1'b1;
   end
   if(pending)begin
    out_l<=result_l[15:0];out_r<=result_r[15:0];wr<=wr+1'b1;
    if(filled<16384)filled<=filled+1'b1;
   end
  end
 end
endmodule
`default_nettype wire
