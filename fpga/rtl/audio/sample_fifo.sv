`default_nettype none
// Single clock, synchronous BRAM read. rd_valid pulses one clock after acceptance.
module sample_fifo #(parameter integer WIDTH=32, DEPTH=4096, AW=$clog2(DEPTH))(
 input wire clk,rst,clear,input wire wr_valid,input wire [WIDTH-1:0] wr_data,
 output wire wr_ready,input wire rd_en,output reg [WIDTH-1:0] rd_data,
 output reg rd_valid,output reg [AW:0] fill,
 output reg [31:0] overruns,underruns
);
 reg [WIDTH-1:0] memory[0:DEPTH-1];
 reg [AW-1:0] wr_ptr,rd_ptr;
 wire pop=rd_en&&(fill!=0);
 assign wr_ready=(fill<DEPTH)||pop;
 wire push=wr_valid&&wr_ready;
 always @(posedge clk) begin
  if(rst||clear)begin wr_ptr<=0;rd_ptr<=0;fill<=0;rd_valid<=0;rd_data<=0;
   if(rst)begin overruns<=0;underruns<=0;end
  end else begin
   rd_valid<=pop;
   if(push)begin memory[wr_ptr]<=wr_data;wr_ptr<=wr_ptr+1'b1;end
   if(pop)begin rd_data<=memory[rd_ptr];rd_ptr<=rd_ptr+1'b1;end
   case({push,pop})2'b10:fill<=fill+1'b1;2'b01:fill<=fill-1'b1;default:fill<=fill;endcase
   if(wr_valid&&!wr_ready)overruns<=overruns+1;
   if(rd_en&&!pop)underruns<=underruns+1;
  end
 end
endmodule
`default_nettype wire
