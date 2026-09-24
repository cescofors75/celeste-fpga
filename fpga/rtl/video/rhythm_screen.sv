`default_nettype none
module rhythm_screen #(parameter SMALL=0)(input wire clk,input wire [9:0] x,y,
 input wire [255:0] state,output wire [15:0] pixel);
 wire [63:0] knobs=state[63:0],patterns=state[127:64];
 wire [15:0] steps=state[143:128],ring=state[191:176];
 wire [7:0] flags=state[199:192];
 reg [255:0] line;reg [7:0] ch,ch_q;
 reg [2:0] gx,gy,gx_q,gy_q;reg on,on_q;
 reg [15:0] bg,fg,bg_q,fg_q;wire [34:0] glyph;
 integer px,py,row,col,j,num,voice,step_index,count;
 function [23:0] decimal3(input integer v);
 begin decimal3[23:16]=48+v/100;decimal3[15:8]=48+(v/10)%10;decimal3[7:0]=48+v%10;end endfunction
 ui_font font(ch_q,glyph);
 always @(posedge clk)begin ch_q<=ch;gx_q<=gx;gy_q<=gy;on_q<=on;bg_q<=bg;fg_q<=fg;end
 assign pixel=on_q&&glyph[34-gy_q*5-gx_q]?fg_q:bg_q;
 always @*begin
  px=SMALL?x:$signed({1'b0,x})/2-40;py=SMALL?y:y/2;
  row=py/12;col=(px-8)/6;gx=(px-8)%6;gy=py%12;
  ch=32;on=0;bg=16'h0041;fg=16'h07ff;line={32{8'd32}};
  num=0;voice=0;step_index=0;count=0;
  case(row)
   0:line="CELESTE RHYTHM LAB              ";
   1:line="LINE IN / 120 BPM / 48 KHZ      ";
   2:line=flags[1]?"MODE DRY   TOUCH: FX            ":"MODE FX    TOUCH: DRY           ";
   3:begin line="1 PULSES A       000            ";num=knobs[7:0];end
   4:begin line="2 ROTATION A     000            ";num=knobs[15:8];end
   5:begin line="3 PATTERNS       000            ";num=knobs[23:16]==0?1:knobs[23:16]==1?2:4;end
   6:begin line="4 TURING MUTATE  000%           ";num=knobs[31:24]*100/16;fg=16'hf81f;end
   7:begin line="5 PROBABILITY    000%           ";num=knobs[39:32]*100/16;fg=16'h07e0;end
   8:begin
    case(knobs[41:40])
     0:line="6 DELAY 1/32     62.5 MS        ";
     1:line="6 DELAY 1/16     125 MS         ";
     2:line="6 DELAY 3/32     187.5 MS       ";
     3:line="6 DELAY 1/8      250 MS         ";
    endcase
   end
   9:begin line="7 DELAY MIX      000%           ";num=knobs[55:48]*100/128;end
   10:begin line="8 FEEDBACK       000%           ";num=knobs[63:56]*100/128;end
   11:line=!flags[2]?"TURING OFF / PRESS ENCODER 4    ":knobs[31:24]==0?"TURING LOCK / PRESS 4: OFF      ":"TURING EVOLVING / PRESS 4: OFF  ";
   12:line=flags[0]?"AUDIO CLOCK LOCKED              ":"WAITING FOR LINE IN             ";
   13:line="PATTERNS: X EVENT / - REST      ";
   14,15,16,17:begin
    voice=row-14;count=voice==0?16:voice==1?12:voice==2?10:7;
    line[255-:8]=65+voice;
    for(j=0;j<16;j=j+1)if(j<count)line[255-(j+3)*8-:8]=patterns[voice*16+j]?88:45;
    fg=voice==0?16'h07ff:voice==1?16'hffe0:voice==2?16'hf81f:16'h07e0;
    if((knobs[23:16]==0&&voice>0)||(knobs[23:16]==1&&voice>1))fg=16'h4208;
    step_index=steps[voice*4+:4];
    if(flags[0]&&col==step_index+3)bg=flags[voice+4]?16'h0320:16'h6000;
   end
   18:line="TURING REGISTER:                ";
   19:for(j=0;j<16;j=j+1)line[255-j*8-:8]=ring[15-j]?49:48;
   default:begin end
  endcase
  if((row>=3&&row<=7)||row==9||row==10)line[255-17*8-:24]=decimal3(num);
  if(px>=8&&px<200&&py<240&&col>=0&&col<32)begin
   ch=line[255-col*8-:8];on=gx<5&&(py%12)<7;
  end
 end
endmodule
`default_nettype wire
