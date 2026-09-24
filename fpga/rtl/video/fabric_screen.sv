`default_nettype none
module fabric_screen #(parameter SMALL=0,EXPANDED=0,MAP_BITS=5)(input wire [9:0] x,y,input wire [511:0] values,
 input wire [8*MAP_BITS-1:0] mappings,input wire [5:0] routes,input wire running,online,
 input wire [2:0] selected,output wire [15:0] pixel,input wire [239:0] meters,input wire [3:0] flow_phase,input wire clk,input wire [103:0] expansion,input wire [127:0] mapped_values);
 reg [7:0] character;wire [34:0] glyph;
 reg [15:0] background,base_q,color_q;reg glyph_on,glyph_q;
 reg [7:0] character_q;reg [2:0] gx_q,gy_q;
 ui_font font(character_q,glyph);
 reg [5:0] col;reg [2:0] gx,gy,index;reg [6:0] id;reg [15:0] value,color;
 reg [63:0] enum_text;reg enum_value;
 reg [127:0] label;reg [255:0] textline;reg text_on,row_on;
 integer lx,ly,row_y,barwidth,branch,by,mi;reg [6:0] percent;reg [3:0] tens,ones;reg [15:0] level,mix_level;reg active;reg muted,soloed,excluded,bypassed;integer bit_id;
 wire [12:0] mute_mask=expansion[90:78],solo_mask=expansion[103:91];
 wire [6:0] new_routes=expansion[70:64],new_bypass=expansion[77:71];
 always @(posedge clk)begin base_q<=background;color_q<=color;character_q<=character;gx_q<=gx;gy_q<=gy;glyph_q<=glyph_on;end
 assign pixel=glyph_q&&glyph[34-gy_q*5-gx_q]?color_q:base_q;
 // Physical encoder mappings include the extended sonic parameters.
 wire [511:0] encoder_values=values;
 function automatic [127:0] name(input [6:0] n);
 begin case(n)
 0:name="GLITCH AMOUNT   ";1:name="GLITCH PROB     ";2:name="DELAY TIME      ";3:name="DELAY FEEDBACK  ";
 4:name="FILTER CUTOFF   ";5:name="FILTER RES      ";6:name="DRY MIX         ";7:name="GLITCH MIX      ";
 8:name="DELAY MIX       ";9:name="FILTER MIX      ";10:name="MASTER LEVEL    ";11:name="LFO RATE        ";12:name="LFO DEPTH       ";13:name="WAVEFOLD DRIVE  ";14:name="VCA LEVEL       ";15:name="CHAOS AMOUNT    ";16:name="WAVEFOLD MIX    ";17:name="VCA MIX         ";23:name="GLITCH MODE     ";24:name="DELAY 2 TIME    ";25:name="DELAY 2 FEEDBACK";26:name="DELAY 2 MIX     ";28:name="FILTER MODE     ";29:name="GLITCH SIZE     ";30:name="GLITCH REPEATS  ";31:name="CHAOS RATE      ";66:name="CHORUS RATE     ";67:name="CHORUS DEPTH    ";68:name="CHORUS MIX      ";69:name="FLANGER RATE    ";70:name="FLANGER DEPTH   ";71:name="FLANGER MIX     ";72:name="CRUSHER BITS    ";73:name="CRUSHER RATE    ";74:name="CRUSHER MIX     ";75:name="FREEZE HOLD     ";77:name="FREEZE MIX      ";78:name="TREMOLO RATE    ";79:name="TREMOLO DEPTH   ";80:name="TREMOLO MIX     ";81:name="AUTOPAN RATE    ";82:name="AUTOPAN DEPTH   ";83:name="AUTOPAN MIX     ";84:name="ENVELOPE DEPTH  ";85:name="ENVELOPE RELEASE";default:name="UNASSIGNED      ";
 endcase end endfunction
 function automatic [15:0] branch_color(input integer n);
 begin case(n)
  0:branch_color=16'hbe9b;
  1:branch_color=16'hfa8f;
  2:branch_color=16'h355f;
  3:branch_color=16'hfd27;
  4:branch_color=16'hfb37;
  5:branch_color=16'habdf;
  6:branch_color=16'h5e7f;
  7:branch_color=16'h46df;
  8:branch_color=16'h6c5f;
  9:branch_color=16'hfd0b;
  10:branch_color=16'h775b;
  11:branch_color=16'he5bf;
  12:branch_color=16'hbc5f;
  default:branch_color=16'hbe9b;
 endcase end endfunction
 function automatic [15:0] tint(input [6:0] n);
 begin case(n)
  0,1,7,23,29,30:tint=16'hfa8f;
  2,3,8:tint=16'h355f;
  24,25,26:tint=16'h5e7f;
  4,5,9,28:tint=16'hfd27;
  11,12:tint=16'h06f4;
  13,16:tint=16'hfb37;
  14,17:tint=16'habdf;
  15,31:tint=16'hab9f;
  66,67,68:tint=16'h46df;
  69,70,71:tint=16'h6c5f;
  72,73,74:tint=16'hfd0b;
  75,77:tint=16'h775b;
  78,79,80:tint=16'he5bf;
  81,82,83:tint=16'hbc5f;
  84,85:tint=16'heead;
  default:tint=16'hbe9b;
 endcase end endfunction
 always @*begin
  background=16'h0041;glyph_on=0;character=32;col=0;gx=0;gy=0;index=0;id=0;value=0;color=16'h07ff;
  enum_text=0;enum_value=0;label=0;textline=0;text_on=0;row_on=0;lx=0;ly=0;row_y=0;percent=0;tens=0;ones=0;barwidth=0;branch=0;by=0;mi=0;level=0;mix_level=0;active=0;muted=0;soloed=0;excluded=0;bypassed=0;bit_id=0;
  if(SMALL)begin
   if(y>=8&&y<24)begin lx=(x-8)>>1;ly=(y-8)>>1;text_on=x>=8&&x<232;textline="CELESTE                         ";end
   else if(y>=32&&y<40)begin lx=x-8;ly=y-32;text_on=x>=8&&x<232;
    textline=values[20*16]?"BYPASS / DRY                    ":running ?"48 KHZ  /  STREAMING            ":"48 KHZ  /  READY                ";end
   else if(y>=44&&y<52)begin lx=x-8;ly=y-44;text_on=x>=8&&x<232;textline=MAP_BITS==7?(values[21*16]?"BANK 1 / SPATIAL + MASTER        ":"BANK 0 / CORE + MODULATION       "):values[21*16]?"BANK 1 / MODULATION + FX        ":"BANK 0 / GLITCH DELAY FILTER    ";end
   else if(y>=56&&y<216)begin
    index=y>=196?7:y>=176?6:y>=156?5:y>=136?4:y>=116?3:y>=96?2:y>=76?1:0;
    row_y=56+index*20;lx=x-8;ly=y-row_y;row_on=x>=8&&x<232;
   end else if(y>=224)begin lx=x-8;ly=y-224;text_on=x>=8&&x<232&&y<232;textline=online?"8 ENCODERS / CONNECTED          ":"8 ENCODERS / OFFLINE            ";end
  end else if(EXPANDED)begin
   // One row decoder is shared by all thirteen branches; no duplicated renderers.
   if(y>=12&&y<28)begin lx=(x-16)>>1;ly=(y-12)>>1;text_on=x>=16&&x<624;textline="CELESTE / PARALLEL FABRIC       ";end
   if(y>=40&&y<48)begin lx=x-16;ly=y-40;text_on=x>=16&&x<272;textline="DSP 23/24   RAM 38/46           ";end
   if(y>=40&&y<48&&x>=304)begin lx=x-304;ly=y-40;text_on=x<624;textline=values[20*16]?"GLOBAL BYPASS / DRY             ":running?"LIVE / 48 KHZ / REAL METERS     ":"READY / 48 KHZ                  ";end
   if(y==56&&x>=16&&x<624||x==192&&y>=64&&y<464)background=16'h236b;
   if(y>=68&&y<76&&x>=16&&x<184)begin lx=x-16;ly=y-68;text_on=1;textline=values[21*16]?"ENCODERS / BANK 1               ":"ENCODERS / BANK 0               ";end
   if(y>=88&&y<408&&x>=16&&x<184)begin
    index=y>=368?7:y>=328?6:y>=288?5:y>=248?4:y>=208?3:y>=168?2:y>=128?1:0;
    row_y=88+index*40;lx=x-16;ly=y-row_y;row_on=1;
   end
   if(y>=428&&y<436&&x>=16&&x<184)begin lx=x-16;ly=y-428;text_on=1;textline="PRESS: MUTE                     ";end
   if(y>=444&&y<452&&x>=16&&x<184)begin lx=x-16;ly=y-444;text_on=1;textline="HOLD: SOLO                      ";end
   if(y>=68&&y<76&&x>=208)begin lx=x-208;ly=y-68;text_on=x<624;textline="IN / PARALLEL ENGINES           ";end
   if(y>=68&&y<76&&x>=544&&x<624)begin lx=x-544;ly=y-68;text_on=1;textline="MIX / OUT                       ";end
   if(y>=84&&y<92&&x>=208&&x<336)background=running&&(x-208)<(meters[15:0]>>8)?16'h07d4:16'h1924;
   if(y>=84&&y<92&&x>=496&&x<624)background=running&&(x-496)<(expansion[55:48]>>1)?16'h07d4:16'h1924;
   if(values[20*16]&&y==96&&x>=208&&x<624)background=running&&meters[15:0]>=128?16'hfd20:16'h6b20;
   if(y>=100&&y<412)begin
    branch=y>=388?12:y>=364?11:y>=340?10:y>=316?9:y>=292?8:y>=268?7:y>=244?6:y>=220?5:y>=196?4:y>=172?3:y>=148?2:y>=124?1:0;
    by=100+branch*24;
    bit_id=branch==0?12:branch-1;
    active=branch<6?routes[branch]:branch==6?values[27*16]:new_routes[branch-7];
    if(branch==2&&values[27*16+1])active=1;
    muted=mute_mask[bit_id];soloed=solo_mask[bit_id];excluded=(|solo_mask)&&!soloed;
    if(branch==6&&values[27*16+1])begin muted=muted||mute_mask[1];excluded=(|solo_mask)&&!(solo_mask[5]||solo_mask[1]);end
    if(branch==2&&values[27*16+1]&&solo_mask[5])excluded=0;
    bypassed=branch==0?0:branch<=6?values[22*16+branch-1]:new_bypass[branch-7];
    mix_level=branch<=6?meters[(branch==6?14:branch+1)*16+:16]:{1'b0,expansion[(branch-7)*8+:8],7'b0};
    level=branch<=6?meters[(branch==0?0:branch+7)*16+:16]:mix_level;
    color=branch_color(branch);
    if(!active||muted||excluded)color=16'h5269;
    if(x>=264&&x<=560&&(y==by||y==by+22||x==264||x==560))background=color;
    if(y>=by+5&&y<by+13&&x>=272&&x<448)begin
     lx=x-272;ly=y-by-5;text_on=1;
     case(branch)
      0:textline="DRY                             ";1:textline=values[23*16+15]?"GLITCH STUTTER                  ":"GLITCH TEXTURE                  ";
      2:textline="DELAY                           ";3:case(values[28*16+14+:2])
       0:textline="FILTER LOW PASS                 ";1:textline="FILTER HIGH PASS                ";2:textline="FILTER BAND PASS                ";3:textline="FILTER NOTCH                    ";endcase
      4:textline="WAVEFOLDER                      ";5:textline="VCA                             ";6:textline=values[27*16+1]?"DELAY 2 SERIES                  ":"DELAY 2 PARALLEL                ";
      7:textline="CHORUS                          ";8:textline="FLANGER                         ";9:textline="BITCRUSHER                      ";10:textline="FREEZE                          ";11:textline="TREMOLO                         ";12:textline="AUTO PAN                        ";
     endcase
    end
    if(y>=by+5&&y<by+13&&x>=496&&x<560)begin lx=x-496;ly=y-by-5;text_on=1;
     textline=!active?"OFF                             ":muted?"MUTE                            ":excluded?"--                              ":soloed?"SOLO                            ":bypassed?"BYPASS                          ":"FX ON                           ";
    end
    if(y>=by+17&&y<by+20&&x>=272&&x<528)background=active&&!muted&&!excluded&&running&&!values[20*16]&&(x-272)<(mix_level>>7)?color:16'h1924;
    if(y==by+11&&x>=224&&x<264&&!(branch==6&&values[27*16+1]))background=active&&running&&meters[15:0]>=128?(((x+flow_phase)&15)<5?16'hffff:color):16'h1924;
    if(y==by+11&&x>560&&x<=608)background=active&&!muted&&!excluded&&running&&!values[20*16]&&mix_level>=128?(((x+flow_phase)&15)<5?16'hffff:color):16'h1924;
    if((x==224||x==608))background=16'h236b;
   end
   // Delay 2 receives Delay 1, rather than input, in series mode.
   if(values[27*16+1]&&((x==248&&y>=159&&y<=255)||(y==159&&x>=248&&x<264)||(y==255&&x>=248&&x<264)))background=running&&meters[9*16+:16]>=128?(((x+y+flow_phase)&15)<5?16'hffff:16'h5e7f):16'h1924;
   if(y>=424&&y<432&&x>=208)begin lx=x-208;ly=y-424;text_on=x<624;color=tint(11);textline=values[22*16+6]?"LFO BYPASS                      ":values[12*16+:16]!=0?"LFO ACTIVE                      ":"LFO DEPTH 0                     ";end
   if(y>=424&&y<432&&x>=424)begin lx=x-424;ly=y-424;text_on=x<624;color=16'h5e7f;textline=values[27*16+1]?"DELAY 1 > DELAY 2               ":"DELAYS IN PARALLEL              ";end
   if(y>=440&&y<448&&x>=208)begin lx=x-208;ly=y-440;text_on=x<408;color=tint(15);textline=values[22*16+7]?"CHAOS BYPASS                    ":values[15*16+:16]!=0?"CHAOS ACTIVE                    ":"CHAOS AMOUNT 0                  ";end
   if(y>=440&&y<448&&x>=424)begin lx=x-424;ly=y-440;text_on=x<624;color=16'h07d4;textline=!new_routes[6]?"ENVELOPE OFF                    ":new_bypass[6]?"ENVELOPE BYPASS                 ":"ENVELOPE > FILTER               ";end
   if(y>=464&&y<472)begin lx=x-16;ly=y-464;text_on=x>=16&&x<272;textline="METERS: FPGA PEAK LEVELS        ";end
   if(y>=464&&y<472&&x>=304)begin lx=x-304;ly=y-464;text_on=x<624;textline="MUTE: SILENCE / BYPASS: DRY     ";end
  end else begin
   if(y>=16&&y<32)begin lx=(x-24)>>1;ly=(y-16)>>1;text_on=x>=24&&x<600;textline="CELESTE / PARALLEL DSP          ";end
   else if(y>=48&&y<56)begin lx=x-24;ly=y-48;text_on=x>=24&&x<600;textline=values[20*16]?"BYPASS / DIRECT TO OUTPUT       ":running?"LIVE / 48 KHZ / STEREO          ":"READY / 48 KHZ / STEREO         ";end
   if(y>=48&&y<56&&x>=336)begin lx=x-336;ly=y-48;text_on=x<616;textline=values[21*16]?"ENCODERS / BANK 1               ":"ENCODERS / BANK 0               ";end
   if(y>=72&&y<80)begin lx=x-24;ly=y-72;text_on=x>=24&&x<280;textline=EXPANDED?"DSP 23 OF 24 UNITS              ":"DSP 22 OF 24 UNITS              ";end
   if(y>=72&&y<80&&x>=336)begin lx=x-336;ly=y-72;text_on=x<616;textline=EXPANDED?"RAM 38 OF 46 BLOCKS             ":"RAM 30 OF 46 BLOCKS             ";end
   if(x>=24&&x<616&&y==92)background=16'h1a88;
   if(x>=24&&x<280&&y>=86&&y<89)background=x<(EXPANDED?269:258)?16'h07d4:16'h1924;
   if(x>=336&&x<616&&y>=86&&y<89)background=x<(EXPANDED?567:518)?16'h353f:16'h1924;
   // Inputs, pre-mixer effect outputs and mixer contributions are distinct.
   for(integer k=0;k<7;k=k+1)begin
    by=112+k*26;mi=k==0?0:k+7;level=running?meters[mi*16+:16]:0;
    mix_level=running?meters[(k==6?14:k+1)*16+:16]:0;
    active=k==6?values[27*16]:k==2?(routes[2]||values[27*16+1]):routes[k];
    if(y>=by&&y<by+26&&x>=232&&x<=400)begin
     if(x==232||x==400||y==by||y==by+25)background=active?branch_color(k):16'h2945;
     if(y>=by+5&&y<by+13&&x>=248&&x<392)begin lx=x-248;ly=y-by-5;text_on=1;color=active?branch_color(k):16'h6b4d;
      case(k)0:textline="DRY                             ";1:textline=values[23*16+15]?"GLITCH / STUTTER                ":"GLITCH / TEXTURE                ";2:textline="DELAY                           ";3:case(values[28*16+14+:2])
       0:textline="FILTER / LOW PASS               ";1:textline="FILTER / HIGH PASS              ";2:textline="FILTER / BAND PASS              ";3:textline="FILTER / NOTCH                  ";endcase 4:textline="WAVEFOLDER                      ";5:textline="VCA                             ";6:textline=values[27*16+1]?"DELAY 2 / SERIES                ":"DELAY 2 / PARALLEL              ";endcase
      if(k>0&&values[22*16+(k==6?5:k-1)])color=16'hfd20;
     end
     if(y>=by+18&&y<by+22&&x>=248&&x<384)background=active&&level>=4&&((x-248)<(level>=32768?136:level>=8192?112:level>=2048?88:level>=512?64:level>=128?40:level>=32?24:8))?branch_color(k):16'h1924;
    end
    if(y==by+12&&x>=144&&x<232&&!(k==6&&values[27*16+1]))background=active&&running&&meters[15:0]>=4?(((x+flow_phase)&15)<5?16'hffff:branch_color(k)):16'h1924;
    if(y==by+12&&x>400&&x<=496&&!(k==2&&!routes[2]))background=active&&running&&!values[20*16]&&mix_level>=4?(((x+flow_phase)&15)<5?16'hffff:branch_color(k)):16'h1924;
   end
   if(values[27*16+1]&&((x==412&&y>=176&&y<=302)||(y==176&&x>=400&&x<=412)||(y==302&&x>=216&&x<=412)||(x==216&&y>=280&&y<=302)||(y==280&&x>=216&&x<=232)))background=running&&meters[9*16+:16]>=4?(((x+y+flow_phase)&15)<5?16'hffff:16'h5fff):16'h1924;
   if(x==176&&y>=124&&y<=280)background=16'h236b;
   if(x==464&&y>=124&&y<=280)background=16'h236b;
   if((x==24||x==144)&&y>=190&&y<=242||(y==190||y==242)&&x>=24&&x<=144)background=branch_color(0);
   if((x==496||x==616)&&y>=190&&y<=242||(y==190||y==242)&&x>=496&&x<=616)background=branch_color(0);
   if(y>=200&&y<208&&x>=40&&x<136)begin lx=x-40;ly=y-200;text_on=1;textline="SAMPLE IN                       ";end
   if(y>=200&&y<208&&x>=512&&x<608)begin lx=x-512;ly=y-200;text_on=1;textline="MIX / OUT                       ";end
   if(y>=224&&y<230&&x>=40&&x<128)background=(x-40)<(meters[15:0]>>9)?16'h07e0:16'h1924;
   if(y>=224&&y<230&&x>=512&&x<600)background=(x-512)<(meters[127:112]>>9)?16'h07e0:16'h1924;
   if(values[20*16]&&y==108&&x>=84&&x<=556)background=meters[15:0]>128?16'hfd20:16'h6b20;
   if(values[20*16]&&(x==84||x==556)&&y>=108&&y<190)background=16'hfd20;
   if(y>=310&&y<318)begin lx=x-24;ly=y-310;text_on=x>=24&&x<280;textline=values[22*16+6]?"LFO / BYPASS                    ":values[12*16+:16]!=0?"LFO / MODULATION ACTIVE         ":"LFO / DEPTH ZERO                ";color=tint(11);end
   if(y>=310&&y<318&&x>=336)begin lx=x-336;ly=y-310;text_on=x<616;textline=values[22*16+7]?"CHAOS / BYPASS                  ":values[15*16+:16]!=0?"CHAOS / MODULATION ACTIVE       ":"CHAOS / AMOUNT ZERO             ";color=tint(15);end
   if(y==324&&x>=24&&x<616)background=16'h1a88;
   if(y>=336&&y<448)begin index=(y>=420?3:y>=392?2:y>=364?1:0)+(x>=320?4:0);row_y=y>=420?420:y>=392?392:y>=364?364:336;
    lx=x-(x>=320?336:24);ly=y-row_y;row_on=lx>=0&&lx<280;
   end
   if(y>=464&&y<472)begin lx=x-24;ly=y-464;text_on=x>=24&&x<280;textline="METERS: MEASURED FPGA SIGNAL    ";end
   if(y>=464&&y<472&&x>=336)begin lx=x-336;ly=y-464;text_on=x<616;textline="CAPACITY 20736 LOGIC CELLS      ";end
  end
  if(row_on)begin
   id=mappings[index*MAP_BITS+:MAP_BITS];value=MAP_BITS==7?mapped_values[index*16+:16]:encoder_values[id*16+:16];label=name(id);color=tint(id);
   if(index==selected)background=16'h10e4;
   if(id==28)begin enum_value=1;case(value[15:14])0:enum_text="LPF     ";1:enum_text="HPF     ";2:enum_text="BPF     ";3:enum_text="NOTCH   ";endcase end
   if(id==23)begin enum_value=1;enum_text=value[15]?"STUTTER ":"TEXTURE ";end
   if(id==29)begin enum_value=1;case(value[15:14])0:enum_text="5.3 MS  ";1:enum_text="10.7 MS ";2:enum_text="21.3 MS ";3:enum_text="42.7 MS ";endcase end
   if(id==75)begin enum_value=1;enum_text=value[15]?"HOLD    ":"CAPTURE ";end
   percent=(value*100)>>16;if(value==65535)percent=100;
   tens=percent>=90?9:percent>=80?8:percent>=70?7:percent>=60?6:percent>=50?5:percent>=40?4:percent>=30?3:percent>=20?2:percent>=10?1:0;
   ones=percent-tens*10;if(percent==100)begin tens=0;ones=0;end
   col=lx>>3;gx=lx&7;gy=ly&7;
   if(EXPANDED&&!SMALL)begin
    if(ly<8)begin
     if(col==0)character=49+index;
     else if(col>=2&&col<18)character=label[127-(col-2)*8-:8];
     glyph_on=gx<5&&gy<7;
    end else if(ly>=12&&ly<20)begin
     gy=ly-12;
     if(col==0)character=percent==100?49:32;
     else if(col==1)character=48+tens;
     else if(col==2)character=48+ones;
     else if(col==3)character=37;
     if(enum_value&&col<8)character=enum_text[63-col*8-:8];
     glyph_on=gx<5&&gy<7;
    end
    if(ly>=25&&ly<28&&lx<128)background=lx<(value>>9)?color:16'h1924;
   end else begin
   if(ly<8)begin
    if(col==0)character=49+index;
    else if(col>=2&&col<18)character=label[127-(col-2)*8-:8];
    else if(col==22)character=percent==100?49:32;
    else if(col==23)character=48+tens;
    else if(col==24)character=48+ones;
    else if(col==25)character=37;
    if(enum_value&&col>=22&&col<30)character=enum_text[63-(col-22)*8-:8];
    if(col<32&&gx<5&&gy<7)glyph_on=1;
   end
   barwidth=SMALL?216:272;
   if(ly>=11&&ly<14&&lx<barwidth)background=lx<((value*barwidth)>>16)?color:16'h1924;
   end
  end else if(text_on)begin
   col=lx>>3;gx=lx&7;gy=ly&7;character=textline[255-col*8-:8];
   if(lx<256&&col<32&&gx<5&&gy<7)glyph_on=1;
  end
 end
endmodule
`default_nettype wire
