`default_nettype none
// Single-master register transfers. STOP between pointer write and read matches
// the official M5Stack library. Data byte zero occupies bits 7:0.
module i2c_register_master #(
    parameter integer HALF_PERIOD=126,
    parameter integer TIMEOUT_CYCLES=504000,
    parameter [6:0] DEVICE_ADDRESS=7'h41
)(input wire clk,rst,start,read_request,
  input wire [7:0] register_address,
  input wire [2:0] length,
  input wire [31:0] write_data,
  output reg busy,done,error,
  output reg [31:0] read_data,
  inout wire scl,sda);
    reg scl_low,sda_low;
    assign scl=scl_low ? 1'b0:1'bz;
    assign sda=sda_low ? 1'b0:1'bz;
    (* ASYNC_REG="TRUE" *) reg [1:0] scl_sync,sda_sync;
    always @(posedge clk) begin
        if(rst) begin scl_sync<=3; sda_sync<=3; end
        else begin scl_sync<={scl_sync[0],scl}; sda_sync<={sda_sync[0],sda}; end
    end
    reg [7:0] state,tx,rx,regaddr;
    reg rd,reading,again;
    reg [2:0] count,nbytes,bitno;
    reg [1:0] stage;
    reg [31:0] payload;
    reg [3:0] recovery;
    integer divider,watchdog;
    localparam IDLE=0,FREE=1,START=2,SEND=3,TXHIGH=4,TXLOW=5,
      ACKSET=6,ACKHIGH=7,ACKREAD=8,ACKEND=9,
      RXSET=10,RXHIGH=11,RXREAD=12,RXLOW=13,
      MACKSET=14,MACKHIGH=15,MACKLOW=16,
      STOPSET=17,STOPHIGH=18,STOPRELEASE=19,STOPEND=20,
      RECLOW=21,RECHIGH=22,RECEND=23;
    always @(posedge clk) begin
        done<=0;
        if(rst) begin
            busy<=0;done<=0;error<=0;read_data<=0;state<=IDLE;
            scl_low<=0;sda_low<=0;divider<=0;watchdog<=0;
            tx<=0;rx<=0;regaddr<=0;rd<=0;reading<=0;again<=0;
            count<=0;nbytes<=0;bitno<=7;stage<=0;payload<=0;recovery<=0;
        end else if(!busy) begin
            divider<=0;watchdog<=0;
            if(start) begin
                busy<=1;error<=0;read_data<=0;regaddr<=register_address;
                rd<=read_request;nbytes<=length;payload<=write_data;
                reading<=0;again<=0;stage<=0;count<=0;recovery<=0;
                scl_low<=0;sda_low<=0;state<=FREE;
            end
        end else if(watchdog>=TIMEOUT_CYCLES) begin
            busy<=0;done<=1;error<=1;state<=IDLE;scl_low<=0;sda_low<=0;
        end else begin
            watchdog<=watchdog+1;
            if(divider<HALF_PERIOD-1) divider<=divider+1;
            else begin
                divider<=0;
                case(state)
                FREE: if(scl_sync[1]) begin
                    if(!sda_sync[1]) begin error<=1;state<=RECLOW; end
                    else begin sda_low<=1;state<=START; end
                end
                START: begin
                    scl_low<=1;tx<={DEVICE_ADDRESS,reading};
                    bitno<=7;stage<=0;state<=SEND;
                end
                SEND: begin sda_low<=!tx[bitno];state<=TXHIGH;end
                TXHIGH: begin scl_low<=0; if(scl_sync[1]) state<=TXLOW;end
                TXLOW: begin
                    scl_low<=1;
                    if(bitno==0) state<=ACKSET;
                    else begin bitno<=bitno-1'b1;state<=SEND;end
                end
                ACKSET: begin sda_low<=0;state<=ACKHIGH;end
                ACKHIGH: begin scl_low<=0;if(scl_sync[1]) state<=ACKREAD;end
                ACKREAD: begin error<=error || sda_sync[1];scl_low<=1;state<=ACKEND;end
                ACKEND: begin
                    if(error) begin again<=0;state<=STOPSET;end
                    else if(stage==0) begin
                        if(reading) begin count<=0;bitno<=7;rx<=0;state<=RXSET;end
                        else begin tx<=regaddr;bitno<=7;stage<=1;state<=SEND;end
                    end else if(stage==1 && rd) begin again<=1;state<=STOPSET;end
                    else if(stage==1 || count+1<nbytes) begin
                        if(stage==1) begin tx<=payload[7:0];count<=0;end
                        else begin tx<=payload[15:8];payload<=payload>>8;count<=count+1'b1;end
                        stage<=2;bitno<=7;state<=SEND;
                    end else begin again<=0;state<=STOPSET;end
                end
                RXSET: begin sda_low<=0;state<=RXHIGH;end
                RXHIGH: begin scl_low<=0;if(scl_sync[1]) state<=RXREAD;end
                RXREAD: begin rx<={rx[6:0],sda_sync[1]};scl_low<=1;state<=RXLOW;end
                RXLOW: begin
                    if(bitno==0) begin read_data[count*8 +: 8]<=rx;state<=MACKSET;end
                    else begin bitno<=bitno-1'b1;state<=RXSET;end
                end
                MACKSET: begin sda_low<=(count+1<nbytes);state<=MACKHIGH;end
                MACKHIGH: begin scl_low<=0;if(scl_sync[1]) state<=MACKLOW;end
                MACKLOW: begin
                    scl_low<=1;
                    if(count+1<nbytes) begin count<=count+1'b1;bitno<=7;state<=RXSET;end
                    else begin again<=0;state<=STOPSET;end
                end
                STOPSET: begin scl_low<=1;sda_low<=1;state<=STOPHIGH;end
                STOPHIGH: begin scl_low<=0;if(scl_sync[1]) state<=STOPRELEASE;end
                STOPRELEASE: begin sda_low<=0;state<=STOPEND;end
                STOPEND: begin
                    if(again && !error) begin reading<=1;again<=0;state<=FREE;end
                    else begin busy<=0;done<=1;state<=IDLE;end
                end
                RECLOW: begin scl_low<=1;sda_low<=0;state<=RECHIGH;end
                RECHIGH: begin scl_low<=0;if(scl_sync[1]) state<=RECEND;end
                RECEND: begin
                    if(recovery==8) begin again<=0;state<=STOPSET;end
                    else begin recovery<=recovery+1'b1;state<=RECLOW;end
                end
                default: begin busy<=0;done<=1;error<=1;scl_low<=0;sda_low<=0;end
                endcase
            end
        end
    end
endmodule
`default_nettype wire
