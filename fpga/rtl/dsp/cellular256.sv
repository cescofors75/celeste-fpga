`default_nettype none
// 256 binary decisions, NOT 256 audio voices. Circular boundaries.
// Rule bits indexed by {left,center,right}; simultaneous update from old state.
module cellular256(input wire clk,rst,step,input wire [1:0] rule_mode,
 input wire [31:0] seed,output reg [255:0] cells,output reg [31:0] reseeds);
 wire [7:0] rule_bits=rule_mode==0?8'd30:rule_mode==1?8'd90:8'd110;
 wire [255:0] initial_cells=256'hc31e57e1946af02d792bea1085d3c6f029174dba635ef880a73c921d4e6b05af^{224'd0,seed};
 wire [255:0] next_cells;
 genvar n;generate for(n=0;n<256;n=n+1)begin
  assign next_cells[n]=rule_bits[{cells[(n+255)%256],cells[n],cells[(n+1)%256]}];
 end endgenerate
 always @(posedge clk)begin
  if(rst)begin cells<=initial_cells;reseeds<=0;end
  else if(step)begin
   // Rule 90 on a 256-cell ring eventually extinguishes. Explicit deterministic
   // reseeding prevents permanent absorption; this is part of the instrument.
   if(next_cells==0)begin cells<=initial_cells;reseeds<=reseeds+1'b1;end
   else cells<=next_cells;
  end
 end
endmodule
`default_nettype wire
