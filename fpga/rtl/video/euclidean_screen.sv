`default_nettype none
module euclidean_screen #(parameter SMALL=0)(input wire clk,input wire [9:0] x,y,
 input wire [39:0] state,output wire [15:0] pixel);
 wire running=state[39],dry=state[37];wire [4:0] pulses=state[36:32];
 wire [3:0] rotation=state[31:28],step=state[27:24];wire [15:0] pattern=state[23:8];
 wire [7:0] envelope=state[7:0];
 reg [15:0] bg,color,bg_q,color_q;reg on,on_q;reg [7:0] ch,ch_q;
 reg [2:0] gx,gy,gx_q,gy_q;wire [34:0] glyph;reg [255:0] line;
 integer lx,ly,col,cell_index,cell_x,origin,pattern_y,cell_width;
 ui_font font(ch_q,glyph);
 always @(posedge clk)begin bg_q<=bg;color_q<=color;on_q<=on;ch_q<=ch;gx_q<=gx;gy_q<=gy;end
 assign pixel=on_q&&glyph[34-gy_q*5-gx_q]?color_q:bg_q;
 always @*begin
  bg=16'h0041;color=16'h07ff;on=0;ch=32;gx=0;gy=0;line=0;lx=-1;ly=-1;col=0;cell_index=0;cell_x=0;
  origin=SMALL?16:32;pattern_y=SMALL?160:272;cell_width=SMALL?12:28;
  if(y>=16&&y<(SMALL?24:32))begin lx=SMALL?x-origin:(x-origin)>>1;ly=SMALL?y-16:(y-16)>>1;line="EUCLIDEAN TEST                  ";end
  if(y>=(SMALL?40:72)&&y<(SMALL?48:80))begin lx=x-origin;ly=y-(SMALL?40:72);line=dry?"MODE: DRY                       ":"MODE: EUCLID                    ";end
  if(y>=(SMALL?56:96)&&y<(SMALL?64:104))begin lx=x-origin;ly=y-(SMALL?56:96);line="BPM: 120 / SIXTEENTHS           ";end
  if(y>=(SMALL?80:144)&&y<(SMALL?88:152))begin lx=x-origin;ly=y-(SMALL?80:144);line="STEPS: 16                       ";end
  if(y>=(SMALL?104:176)&&y<(SMALL?112:184))begin lx=x-origin;ly=y-(SMALL?104:176);line="PULSES: 00                      ";line[255-8*8-:8]=pulses>=10?49:48;line[255-9*8-:8]=48+(pulses>=10?pulses-10:pulses);end
  if(y>=(SMALL?128:208)&&y<(SMALL?136:216))begin lx=x-origin;ly=y-(SMALL?128:208);line="ROTATE: 00                      ";line[255-8*8-:8]=rotation>=10?49:48;line[255-9*8-:8]=48+(rotation>=10?rotation-10:rotation);end
  if(y>=(SMALL?196:344)&&y<(SMALL?204:352))begin lx=x-origin;ly=y-(SMALL?196:344);line="RAMP: 2.67 MS                   ";end
  if(y>=(SMALL?212:376)&&y<(SMALL?220:384))begin lx=x-origin;ly=y-(SMALL?212:376);line="TOUCH: DRY / EUCLID             ";end
  if(y>=(SMALL?228:408)&&y<(SMALL?236:416))begin lx=x-origin;ly=y-(SMALL?228:408);line=running?"LINE IN / 48 KHZ                ":"WAITING FOR LINE IN             ";end
  if(lx>=0&&lx<(SMALL?216:256)&&ly>=0&&ly<8)begin col=lx>>3;gx=lx&7;gy=ly&7;ch=line[255-col*8-:8];on=gx<5&&gy<7;end
  // Each cell reads the same pattern bit used by the audio multiplier.
  for(integer n=0;n<16;n=n+1)begin
   cell_x=origin+n*cell_width;
   if(x>=cell_x&&x<cell_x+cell_width&&y>=pattern_y&&y<pattern_y+(SMALL?16:24))begin
    if(running&&step==n)bg=16'h1268;
    color=pattern[n]?16'h07f0:16'h7bef;
    lx=SMALL?x-cell_x-2:(x-cell_x-6)>>1;ly=SMALL?y-pattern_y-3:(y-pattern_y-4)>>1;
    ch=pattern[n]?88:45;gx=lx&7;gy=ly&7;on=lx>=0&&lx<5&&ly>=0&&ly<7;
   end
  end
  if(x>=origin&&x<origin+(SMALL?128:256)&&y>=(SMALL?185:324)&&y<(SMALL?188:328))bg=(x-origin)<(SMALL?envelope:envelope*2)?16'h07f0:16'h1924;
 end
endmodule
`default_nettype wire
