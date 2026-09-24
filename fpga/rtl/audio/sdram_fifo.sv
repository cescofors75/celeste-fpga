`default_nettype none
// PCM queue in the GW2AR package SDR SDRAM, bank 0, BL=1, CAS=2.
// Conservative timings at 12.288 MHz; SDRAM samples half a cycle after outputs.
// STOP reinitializes the controller and discards queued PCM, never its counters.
module sdram_fifo #(parameter DEPTH=32768, AW=$clog2(DEPTH), INIT_CYCLES=4096)(
 input wire clk,rst,clear,input wire wr_valid,input wire [31:0] wr_data,
 output wire wr_ready,input wire rd_en,output reg [31:0] rd_data,
 output reg rd_valid,output reg [AW:0] fill,output reg [31:0] overruns,underruns,
 output wire ram_clk,ram_cke,output wire ram_cs_n,ram_ras_n,ram_cas_n,ram_we_n,
 output reg [10:0] ram_addr,output wire [1:0] ram_ba,output wire [3:0] ram_dqm,
 inout wire [31:0] ram_dq
);
 localparam NOP=4'b0111,PRE=4'b0010,REF=4'b0001,MODE=4'b0000,ACT=4'b0011,RD=4'b0101,WR=4'b0100;
 reg [3:0] command;reg [3:0] state;reg [12:0] timer;reg [7:0] refresh_age;
 reg [AW-1:0] wp,rp,address;reg read_pending,reading,drive;
 reg [31:0] write_data;
 assign ram_clk=~clk;assign ram_cke=1'b1;
 assign {ram_cs_n,ram_ras_n,ram_cas_n,ram_we_n}=command;
 assign ram_ba=0;assign ram_dqm=0;assign ram_dq=drive?write_data:32'bz;
 assign wr_ready=state==7&&refresh_age<80&&!read_pending&&!rd_en&&fill<DEPTH;
 always @(posedge clk)begin
  if(rst||clear)begin
   command<=NOP;state<=0;timer<=0;refresh_age<=0;wp<=0;rp<=0;fill<=0;
   rd_valid<=0;rd_data<=0;read_pending<=0;reading<=0;drive<=0;ram_addr<=0;address<=0;write_data<=0;
   if(rst)begin overruns<=0;underruns<=0;end
  end else begin
   command<=NOP;drive<=0;rd_valid<=0;
   if(refresh_age!=255)refresh_age<=refresh_age+1'b1;
   if(rd_en)begin if(fill!=0)begin read_pending<=1;fill<=fill-1'b1;end else underruns<=underruns+1'b1;end
   case(state)
    0:if(timer==INIT_CYCLES-1)begin command<=PRE;ram_addr<=11'h400;timer<=0;state<=1;end else timer<=timer+1'b1;
    1:begin command<=REF;state<=2;end
    2:state<=3;
    3:begin command<=REF;state<=4;end
    4:state<=5;
    5:begin command<=MODE;ram_addr<=11'h220;state<=6;end
    6:begin state<=7;refresh_age<=0;end
    7:begin
     if(refresh_age>=80)begin command<=REF;refresh_age<=0;state<=14;end
     else if(read_pending)begin
      command<=ACT;ram_addr<=rp>>8;address<=rp;rp<=rp+1'b1;read_pending<=0;reading<=1;state<=8;
     end else if(wr_valid&&wr_ready)begin
      command<=ACT;ram_addr<=wp>>8;address<=wp;wp<=wp+1'b1;fill<=fill+1'b1;write_data<=wr_data;reading<=0;state<=8;
     end
    end
    8:state<=9;
    9:begin command<=reading?RD:WR;ram_addr<={1'b1,2'b0,address[7:0]};drive<=!reading;state<=10;end
    10:state<=11;
    11:state<=12;
    12:begin if(reading)begin rd_data<=ram_dq;rd_valid<=1;end state<=13;end
    13:state<=7;
    14:state<=15;
    15:state<=7;
    default:state<=0;
   endcase
  end
 end
endmodule
`default_nettype wire
