`default_nettype none
// Temporary directional diagnostic: 0 clears, 255 returns count/sum/error
// as three u32 little-endian words. Bytes 1..254 increment count and sum.
module uart_sink_probe(input wire clk27,reset_button,uart_rx,output wire uart_tx,output wire led);
 reg [4:0] boot=0;always @(posedge clk27)if(!(&boot))boot<=boot+1'b1;
 wire rst=reset_button||!(&boot);
 wire valid,tx_ready,framing;wire [7:0] data;
 reg [31:0] count,sum,errors;reg [95:0] reply;reg [3:0] left;
 uart_8n1 serial(clk27,rst,uart_rx,uart_tx,valid,data,framing,left!=0,reply[7:0],tx_ready);
 assign led=errors==0;
 always @(posedge clk27)begin
  if(rst)begin count<=0;sum<=0;errors<=0;reply<=0;left<=0;end
  else begin
   if(framing)errors<=errors+1;
   if(left!=0&&tx_ready)begin reply<={8'b0,reply[95:8]};left<=left-1'b1;end
   if(valid)begin
    if(data==0)begin count<=0;sum<=0;errors<=0;end
    else if(data==255)begin reply<={errors,sum,count};left<=12;end
    else begin count<=count+1;sum<=sum+data;end
   end
  end
 end
endmodule
`default_nettype wire
