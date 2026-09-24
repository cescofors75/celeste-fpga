`default_nettype none
// Temporary SRAM-only echo diagnostic. Fixed onboard 27 MHz / 9 = 3 Mbaud.
module uart_probe(input wire clk27,reset_button,uart_rx,output wire uart_tx,output wire led);
 reg [4:0] boot=0;
 always @(posedge clk27)if(!(&boot))boot<=boot+1'b1;
 wire rst=reset_button||!(&boot);
 wire valid,tx_ready,framing,ready,read_valid;wire [7:0] data,read_data;
 wire [8:0] fill;wire [31:0] over,under;
 reg holding,pending,fault;reg [7:0] held;
 wire pop=!holding&&!pending&&fill!=0;
 uart_8n1 serial(clk27,rst,uart_rx,uart_tx,valid,data,framing,holding,held,tx_ready);
 sample_fifo #(.WIDTH(8),.DEPTH(256)) fifo(clk27,rst,1'b0,valid,data,ready,pop,read_data,read_valid,fill,over,under);
 assign led=!fault;
 always @(posedge clk27)begin
  if(rst)begin holding<=0;pending<=0;fault<=0;held<=0;end
  else begin
   if(framing||(valid&&!ready))fault<=1;
   if(pop)pending<=1;
   if(read_valid)begin pending<=0;holding<=1;held<=read_data;end
   if(holding&&tx_ready)holding<=0;
  end
 end
endmodule
`default_nettype wire
