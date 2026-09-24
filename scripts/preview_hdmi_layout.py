"""Layout reference preview (not an RTL simulation or a hardware capture)."""
from pathlib import Path
import re,json
from PIL import Image,ImageDraw
root=Path(__file__).resolve().parent.parent
font={int(c):b.replace('_','') for c,b in re.findall(r"8'd(\d+):bits=35'b([01_]+)",(root/'fpga/reference/video/ui_font.v').read_text())}
im=Image.new('RGB',(640,480),(0,8,8));d=ImageDraw.Draw(im)
def text(x,y,s,c='#62e5ec',scale=1):
 for i,ch in enumerate(s):
  bits=font.get(ord(ch),'0'*35)
  for p,b in enumerate(bits):
   if b=='1':d.rectangle((x+i*8*scale+(p%5)*scale,y+(p//5)*scale,x+i*8*scale+(p%5+1)*scale-1,y+(p//5+1)*scale-1),fill=c)
text(16,12,'CELESTE / PARALLEL FABRIC',scale=2)
text(16,40,'DSP 23/24   RAM 38/46');text(304,40,'LIVE / 48 KHZ / REAL METERS')
d.line((16,56,624,56),fill='#205860');d.line((192,64,192,464),fill='#205860')
text(16,68,'ENCODERS / BANK 0');text(208,68,'IN / PARALLEL ENGINES');text(544,68,'MIX / OUT')
palette=json.loads((root/'shared/palette.json').read_text())['colors']
colors=[palette[k] for k in ['mixer','glitch','delay','filter','wavefolder','vca','delay2','chorus','flanger','crusher','freeze','tremolo','autopan']]
labels=['GLITCH AMOUNT','GLITCH PROB','FILTER CUTOFF','FILTER RES','DELAY TIME','DELAY FEEDBACK','LFO RATE','MASTER LEVEL']
for i,(name,v,ci) in enumerate(zip(labels,[71,33,34,60,45,41,23,100],[1,1,3,3,2,2,11,0])):
 y=88+i*40;c=colors[ci];text(16,y,f'{i+1} {name}',c);text(16,y+12,f'{v:3}%',c);d.rectangle((16,y+25,143,y+27),fill='#18282a');d.rectangle((16,y+25,16+int(v*127/100),y+27),fill=c)
text(16,428,'PRESS: MUTE');text(16,444,'HOLD: SOLO')
for x in [208,496]:d.rectangle((x,84,x+127,91),fill='#18282a');d.rectangle((x,84,x+88,91),fill='#20e8ac')
for i,name in enumerate(['DRY','GLITCH STUTTER','DELAY','FILTER LOW PASS','WAVEFOLDER','VCA','DELAY 2 PARALLEL','CHORUS','FLANGER','BITCRUSHER','FREEZE','TREMOLO','AUTO PAN']):
 y=100+i*24;c=colors[i];d.rectangle((264,y,560,y+22),outline=c);text(272,y+5,name,c);text(496,y+5,'FX ON',c);d.line((224,y+11,263,y+11),fill=c);d.line((561,y+11,608,y+11),fill=c);d.rectangle((272,y+17,527,y+19),fill='#18282a');d.rectangle((272,y+17,272+(i*29+70)%250,y+19),fill=c)
for x in [224,608]:d.line((x,100,x,411),fill='#205860')
text(208,424,'LFO ACTIVE','#00efba');text(424,424,'DELAYS IN PARALLEL','#58d8ff');text(208,440,'CHAOS ACTIVE','#ac78ff');text(424,440,'ENVELOPE > FILTER','#20e8ac')
text(16,464,'METERS: FPGA PEAK LEVELS');text(304,464,'MUTE: SILENCE / BYPASS: DRY')
out=root/'build/hdmi-expanded-layout-reference.png';im.resize((1280,960),Image.Resampling.NEAREST).save(out);print(out)
