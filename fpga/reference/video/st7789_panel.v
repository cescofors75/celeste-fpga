`default_nettype none
// 240x240 ST7789, RGB565, selectable mode 0/3, CS tied active on the seven-pin module.
// Power/gamma settings follow Waveshare Pico-LCD-1.3 reference.
// MADCTL=0: rotation 2, zero row offset on the common 240x240 glass.
module st7789_panel #(
    parameter integer WAIT_CYCLES=3780000, // 150 ms at 25.2 MHz
    parameter integer HALF_PERIOD=12,
    parameter integer FRAME_HEIGHT=240, PIXEL_PIPELINED=0
)(input wire clk,rst, input wire [15:0] pixel,
  output reg [7:0] x,output reg [8:0] y, output reg frame_start,
  output reg scl,sda,dc,res, input wire mode3);
    localparam RESET_LOW=0,RESET_WAIT=1,INIT=2,DELAY=3,WINDOW=4,
               PIX_HI=5,PIX_LO=6,ADVANCE=7,SEND=8,PIX_WAIT=9;
    localparam [15:0] LAST_ROW=FRAME_HEIGHT-1;
    reg [3:0] state,after_send;
    reg [31:0] timer;
    reg [5:0] index;
    reg [7:0] tx;
    reg [15:0] held_pixel;
    reg [4:0] edge_index;
    reg [7:0] divider;
    reg [8:0] token;
    always @* begin
        token=0;
        if(state==INIT) case(index)
            0:token=9'h001;
            1:token=9'h011;
            2:token=9'h03a;
            3:token=9'h155;
            4:token=9'h036;
            5:token=9'h100;
            6:token=9'h0b2;
            7:token=9'h10c;
            8:token=9'h10c;
            9:token=9'h100;
            10:token=9'h133;
            11:token=9'h133;
            12:token=9'h0b7;
            13:token=9'h135;
            14:token=9'h0bb;
            15:token=9'h119;
            16:token=9'h0c0;
            17:token=9'h12c;
            18:token=9'h0c2;
            19:token=9'h101;
            20:token=9'h0c3;
            21:token=9'h112;
            22:token=9'h0c4;
            23:token=9'h120;
            24:token=9'h0c6;
            25:token=9'h10f;
            26:token=9'h0d0;
            27:token=9'h1a4;
            28:token=9'h1a1;
            29:token=9'h0e0;
            30:token=9'h1d0;
            31:token=9'h104;
            32:token=9'h10d;
            33:token=9'h111;
            34:token=9'h113;
            35:token=9'h12b;
            36:token=9'h13f;
            37:token=9'h154;
            38:token=9'h14c;
            39:token=9'h118;
            40:token=9'h10d;
            41:token=9'h10b;
            42:token=9'h11f;
            43:token=9'h123;
            44:token=9'h0e1;
            45:token=9'h1d0;
            46:token=9'h104;
            47:token=9'h10c;
            48:token=9'h111;
            49:token=9'h113;
            50:token=9'h12c;
            51:token=9'h13f;
            52:token=9'h144;
            53:token=9'h151;
            54:token=9'h12f;
            55:token=9'h11f;
            56:token=9'h11f;
            57:token=9'h120;
            58:token=9'h123;
            59:token=9'h021;
            60:token=9'h013;
            61:token=9'h029;
            default:token=0;
        endcase
        else case(index)
            0:token=9'h02a;
            1,2,3:token=9'h100;
            4:token=9'h1ef;
            5:token=9'h02b;
            6,7:token=9'h100;
            8:token={1'b1,LAST_ROW[15:8]};
            9:token={1'b1,LAST_ROW[7:0]};
            10:token=9'h02c;
            default:token=0;
        endcase
    end
    always @(posedge clk) begin
        if(rst) begin
            state<=RESET_LOW;timer<=0;index<=0;x<=0;y<=0;
            scl<=mode3;sda<=0;dc<=0;res<=0;frame_start<=0;
            tx<=0;held_pixel<=0;divider<=0;edge_index<=0;after_send<=INIT;
        end else begin
            frame_start<=0;
            case(state)
            RESET_LOW: if(timer==WAIT_CYCLES-1) begin
                timer<=0;res<=1;state<=RESET_WAIT;
            end else timer<=timer+1'b1;
            RESET_WAIT: if(timer==WAIT_CYCLES-1) begin
                timer<=0;state<=INIT;
            end else timer<=timer+1'b1;
            INIT: begin
                tx<=token[7:0];sda<=token[7];dc<=token[8];divider<=0;edge_index<=0;
                state<=SEND;index<=index+1'b1;
                if(index==0 || index==1 || index==3 || index==61) after_send<=DELAY;
                else after_send<=INIT;
            end
            DELAY: if(timer==WAIT_CYCLES-1) begin
                timer<=0;
                if(index==62) begin index<=0;state<=WINDOW;frame_start<=1;end
                else state<=INIT;
            end else timer<=timer+1'b1;
            WINDOW: begin
                tx<=token[7:0];sda<=token[7];dc<=token[8];divider<=0;edge_index<=0;
                state<=SEND;
                if(index==10) begin index<=0;after_send<=PIX_HI;end
                else begin index<=index+1'b1;after_send<=WINDOW;end
            end
            PIX_HI: begin
                held_pixel<=pixel;tx<=pixel[15:8];sda<=pixel[15];dc<=1;
                divider<=0;edge_index<=0;state<=SEND;after_send<=PIX_LO;
            end
            PIX_LO: begin
                tx<=held_pixel[7:0];sda<=held_pixel[7];dc<=1;
                divider<=0;edge_index<=0;state<=SEND;after_send<=ADVANCE;
            end
            ADVANCE: begin
                if(x==239) begin
                    x<=0;
                    if(y==LAST_ROW) begin y<=0;frame_start<=1;state<=WINDOW;end
                    else begin y<=y+1'b1;state<=PIXEL_PIPELINED?PIX_WAIT:PIX_HI;end
                end else begin x<=x+1'b1;state<=PIXEL_PIPELINED?PIX_WAIT:PIX_HI;end
            end
            PIX_WAIT:state<=PIX_HI;
            SEND: if(divider==HALF_PERIOD-1) begin
                divider<=0;
                if(mode3) begin
                    if(!edge_index[0]) begin scl<=0;sda<=tx[7];end
                    else begin scl<=1;tx<={tx[6:0],1'b0};end
                end else begin
                    if(!edge_index[0]) scl<=1;
                    else begin scl<=0;tx<={tx[6:0],1'b0};sda<=tx[6];end
                end
                if(edge_index==15) state<=after_send;
                else edge_index<=edge_index+1'b1;
            end else divider<=divider+1'b1;
            default:state<=RESET_LOW;
            endcase
        end
    end
endmodule
`default_nettype wire
