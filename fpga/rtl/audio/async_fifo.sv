`default_nettype none
// Dual-clock RAM with Gray-coded pointer synchronizers and registered read output.
// Reset BOTH sides together; release synchronously in their own clock domains.
module async_fifo #(parameter WIDTH=8, AW=10)(
 input wire wr_clk,wr_rst,wr_valid,input wire [WIDTH-1:0] wr_data,output wire wr_ready,
 input wire rd_clk,rd_rst,output reg rd_valid,output reg [WIDTH-1:0] rd_data,input wire rd_ready
);
 reg [WIDTH-1:0] memory[0:(1<<AW)-1];
 reg [AW:0] wp,rp,wg,rg;
 (* ASYNC_REG="TRUE" *) reg [AW:0] rg1,rg2,wg1,wg2;
 wire full=wg=={~rg2[AW:AW-1],rg2[AW-2:0]};
 wire empty=rg==wg2;
 wire [AW:0] wn=wp+1'b1,rn=rp+1'b1;
 assign wr_ready=!full;
 always @(posedge wr_clk)begin
  if(wr_rst)begin wp<=0;wg<=0;rg1<=0;rg2<=0;end
  else begin rg1<=rg;rg2<=rg1;
   if(wr_valid&&wr_ready)begin memory[wp[AW-1:0]]<=wr_data;wp<=wn;wg<=(wn>>1)^wn;end
  end
 end
 always @(posedge rd_clk)begin
  if(rd_rst)begin rp<=0;rg<=0;wg1<=0;wg2<=0;rd_valid<=0;rd_data<=0;end
  else begin wg1<=wg;wg2<=wg1;
   if(!rd_valid||rd_ready)begin
    rd_valid<=!empty;
    if(!empty)begin rd_data<=memory[rp[AW-1:0]];rp<=rn;rg<=(rn>>1)^rn;end
   end
  end
 end
endmodule
`default_nettype wire
