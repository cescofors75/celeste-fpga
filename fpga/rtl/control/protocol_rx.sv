`default_nettype none
// CRC-checked packet staging. No payload byte is exposed before the CRC passes.
// Backpressure rx_ready must be honored by the bridge. 1024-byte staging RAM.
module protocol_rx #(parameter IDLE_BITS=25)(
 input wire clk,rst,input wire rx_valid,input wire [7:0] rx_data,output wire rx_ready,
 output reg packet_valid,input wire packet_done,output reg [7:0] kind,
 output reg [31:0] sequence_number,output reg [10:0] length,
 input wire [9:0] payload_address,output reg [7:0] payload_data,
 output reg [31:0] errors
);
 reg [7:0] payload[0:1023];
 reg [3:0] state;reg [10:0] index;reg [15:0] crc;reg [7:0] crc_low;
 // USB bridges may pause inside a UART packet. 20 bits allowed only 85 ms
 // at 12.288 MHz and dropped valid packets during measured 200+ ms stalls.
 // 25 bits provides 2.731 s resynchronization time without weakening CRC.
 reg [IDLE_BITS-1:0] idle_cycles;
 function automatic [15:0] crc_byte(input [15:0] c,input [7:0] b);
  reg [15:0] v;integer j;begin v=c^{b,8'b0};for(j=0;j<8;j=j+1)v=v[15]?(v<<1)^16'h1021:v<<1;crc_byte=v;end
 endfunction
 assign rx_ready=!packet_valid;
 always @(posedge clk)begin
  payload_data<=payload[payload_address];
  if(rst)begin state<=0;index<=0;crc<=16'hffff;packet_valid<=0;errors<=0;kind<=0;sequence_number<=0;length<=0;idle_cycles<=0;crc_low<=0;end
  else if(packet_valid)begin if(packet_done)begin packet_valid<=0;state<=0;end end
  else if(rx_valid)begin
   idle_cycles<=0;
   case(state)
    0:if(rx_data==8'h43)state<=1;
    1:if(rx_data==8'h45)begin state<=2;crc<=16'hffff;end else state<=(rx_data==8'h43)?1:0;
    2:if(rx_data==1)begin crc<=crc_byte(crc,rx_data);state<=3;end else begin state<=0;errors<=errors+1;end
    3:begin kind<=rx_data;crc<=crc_byte(crc,rx_data);state<=4;index<=0;end
    4:begin sequence_number[index*8+:8]<=rx_data;crc<=crc_byte(crc,rx_data);if(index==3)begin state<=5;index<=0;end else index<=index+1;end
    5:begin length[7:0]<=rx_data;crc<=crc_byte(crc,rx_data);state<=6;end
    6:begin
     crc<=crc_byte(crc,rx_data);length[10:8]<=rx_data[2:0];index<=0;
     if(rx_data>4||(rx_data==4&&length[7:0]!=0))begin state<=0;errors<=errors+1;end
     else state<=({rx_data,length[7:0]}==0)?8:7;
    end
    7:begin payload[index[9:0]]<=rx_data;crc<=crc_byte(crc,rx_data);if(index==length-1)state<=8;else index<=index+1;end
    8:begin crc_low<=rx_data;state<=9;end
    9:begin if({rx_data,crc_low}==crc)packet_valid<=1;else errors<=errors+1;state<=0;end
    default:state<=0;
   endcase
  end else if(state!=0)begin
   idle_cycles<=idle_cycles+1;
   if(&idle_cycles)begin state<=0;errors<=errors+1;end
  end
 end
endmodule
`default_nettype wire
