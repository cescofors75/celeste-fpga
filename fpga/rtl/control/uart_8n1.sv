`default_nettype none
module uart_8n1 #(parameter integer DIV=9)(
 input wire clk,rst,rx,output wire tx,
 output reg rx_valid,output reg [7:0] rx_data,output reg framing_error,
 input wire tx_valid,input wire [7:0] tx_data,output wire tx_ready
);
 (* ASYNC_REG="TRUE" *) reg [1:0] rx_sync;
 reg [1:0] state;reg [15:0] rx_count,tx_count;
 reg [2:0] rx_bit;reg [7:0] rx_shift;
 reg [9:0] tx_shift;reg [3:0] tx_remaining;
 assign tx_ready=tx_remaining==0;
 assign tx=tx_ready?1'b1:tx_shift[0];
 always @(posedge clk)begin
  if(rst)begin rx_sync<=3;state<=0;rx_count<=0;tx_count<=0;rx_bit<=0;rx_shift<=0;rx_data<=0;rx_valid<=0;framing_error<=0;tx_shift<=10'h3ff;tx_remaining<=0;end
  else begin
   rx_sync<={rx_sync[0],rx};rx_valid<=0;framing_error<=0;
   case(state)
    0:if(!rx_sync[1])begin rx_count<=DIV/2-1;state<=1;end
    1:if(rx_count!=0)rx_count<=rx_count-1;else if(!rx_sync[1])begin state<=2;rx_count<=DIV-1;rx_bit<=0;end else state<=0;
    2:if(rx_count!=0)rx_count<=rx_count-1;else begin rx_shift[rx_bit]<=rx_sync[1];rx_count<=DIV-1;if(rx_bit==7)state<=3;else rx_bit<=rx_bit+1;end
    3:if(rx_count!=0)rx_count<=rx_count-1;else begin state<=0;if(rx_sync[1])begin rx_data<=rx_shift;rx_valid<=1;end else framing_error<=1;end
   endcase
   if(tx_ready)begin if(tx_valid)begin tx_shift<={1'b1,tx_data,1'b0};tx_remaining<=10;tx_count<=DIV-1;end end
   else if(tx_count!=0)tx_count<=tx_count-1;
   else begin tx_shift<={1'b1,tx_shift[9:1]};tx_remaining<=tx_remaining-1;tx_count<=DIV-1;end
  end
 end
endmodule
`default_nettype wire
