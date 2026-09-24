"""Software reference for independent expansion; does not replace RTL simulation."""
from dataclasses import dataclass,field
from pathlib import Path
import math,json,struct,hashlib

def sat(x):return min(32767,max(-32768,x))
def slew(x,t,n=64):return min(t,x+n) if t>x else max(t,x-n)
def blend(a,b,f):return a+((b-a)*f>>16)
@dataclass
class Expansion:
 motion:list=field(default_factory=lambda:[(0,0)]*2048)
 frozen:list=field(default_factory=lambda:[(0,0)]*2048)
 wr:int=0;fw:int=0;fr:int=0;anchor:int=0;was_held:bool=False;filled:int=0;ffilled:int=0
 phase:list=field(default_factory=lambda:[0]*4)
 gains:list=field(default_factory=lambda:[0]*6)
 depths:list=field(default_factory=lambda:[0]*2)
 held:tuple=(0,0);count:int=0;env:int=0
 def step(self,frame,p,base=(0,0),master=26214,bypass=0):
  self.motion[self.wr]=frame;self.wr=(self.wr+1)%2048;self.filled=min(2048,self.filled+1)
  if p[11]<32768 or self.ffilled<2048:
   self.frozen[self.fw]=frame;self.fr=0;self.fw=(self.fw+1)%2048;self.anchor=self.fw;self.was_held=False;self.ffilled=min(2048,self.ffilled+1)
  else:
   if not self.was_held:self.fr=0;self.anchor=self.fw
   else:self.fr=128 if self.fr==2047 else self.fr+1
   self.was_held=True
  if self.count==0:self.held=frame;self.count=p[9]>>8
  else:self.count-=1
  peak=max(abs(v) for v in frame);drop=(self.env>>(8+2*(p[21]>>14)))+1
  self.env=peak if peak>self.env else max(0,self.env-drop)
  tri=[]
  for i,k in enumerate((2,5,14,17)):
   self.phase[i]=(self.phase[i]+4474+(p[k]<<4))&0xffffffff
   t=(self.phase[i]>>15)&65535;tri.append((~t)&65535 if self.phase[i]>>31 else t)
  self.depths=[slew(v,p[k]) for v,k in zip(self.depths,(3,6))]
  active=p[0]&~(p[24]>>6)&((p[25]>>6) if p[25]&8191 else 63)
  self.gains=[slew(g,(p[k]>>8) if active&(1<<i) else 0,1) for i,(g,k) in enumerate(zip(self.gains,(4,7,10,13,16,19)))]
  wet=[]
  for i in range(2):
   motion=(tri[i]*self.depths[i])>>(18 if i else 15)
   rd=(self.wr-(3 if i else 384)-(motion>>8))%2048;f=(motion&255)<<8
   tap=[blend(a,b,f) for a,b in zip(self.motion[rd],self.motion[(rd-1)%2048])]
   wet.append(tuple(sat((a+b)>>1) for a,b in zip(frame,tap)) if self.filled==2048 else frame)
  bits=p[8]>>12;wet.append(tuple((v>>bits)<<bits for v in self.held))
  f=(self.fr&127)<<9 if self.fr>=1920 else 0
  wet.append(tuple(sat(blend(a,b,f)) for a,b in zip(self.frozen[(self.anchor+self.fr)%2048],self.frozen[(self.anchor+(self.fr&127))%2048])) if self.ffilled==2048 and p[11]>=32768 else frame)
  depth=tri[2]*p[15]>>16;wet.append(tuple(v*(65535-depth)>>16 for v in frame))
  depth=tri[3]*p[18]>>16;wet.append((frame[0]*(65535-depth)>>16,frame[1]*(65535-(p[18]-depth))>>16))
  sums=[0,0]
  for i,w in enumerate(wet):
   if p[1]&(1<<i):w=frame
   for ch in range(2):sums[ch]+=w[ch]*(self.gains[i]<<8)>>16
  gain=master if bypass==0 else master*(65535-bypass)>>16
  return tuple(sat(b+(s*gain>>16)) for b,s in zip(base,sums))
def run():
 # The compact RTL applies the signed high three bits in three clock slots.
 # Check exact equivalence over the complete 19-bit sum range, including carry.
 for gain in (0,1,12345,32768,65535):
  for x in range(-262144,262144):
   hi=(x>>16)&7;v=((x&65535)*gain)>>16
   for bit in range(3):
    if hi&(1<<bit):v+=(-1 if bit==2 else 1)*(gain<<bit)
    assert -262144<=v<=262143
   assert v==(x*gain>>16)
 p=[0]*32;p[0]=63
 for k in (4,7,10,13,16,19):p[k]=10000
 for k in (2,5,14,17):p[k]=16000
 p[3]=p[6]=40000;p[8]=32768;p[9]=1500;p[11]=65535;p[15]=p[18]=65535
 src=[(int(20000*math.sin(n*.09)),int(16000*math.sin(n*.13))) for n in range(12000)]
 all_fx=Expansion();rows=[all_fx.step(f,p) for f in src];assert any(v!=(0,0) for v in rows[4096:])
 model=Expansion();assert rows==[model.step(f,p) for f in src]
 signatures=[]
 for b in range(6):
  solo=p.copy();solo[25]=1<<(6+b);isolated=p.copy();isolated[0]=1<<b
  a=Expansion();c=Expansion();x=[a.step(f,solo) for f in src];assert x==[c.step(f,isolated) for f in src]
  signatures.append(hashlib.sha256(b''.join(struct.pack('<hh',*v) for v in x)).hexdigest())
 assert len(set(signatures))==6
 mute=p.copy();mute[24]=8191;assert all(Expansion().step(f,mute)==(0,0) for f in src[:100])
 a=Expansion();assert all(a.step((0,0),p)==(0,0) for _ in range(5000))
 a=Expansion();q=p.copy();q[0]=0;assert all(a.step(f,q,base=f)==f for f in src[:200])
 a=Expansion();assert all(a.step(f,p,base=f,bypass=65535)==f for f in src[:200])
 out=Path('build/expansion-reference');out.mkdir(parents=True,exist_ok=True)
 for name,data in [('input',src),('expected',rows)]: (out/(name+'.hex')).write_text('\n'.join(f'{((r&65535)<<16)|(l&65535):08x}' for l,r in data)+'\n')
 report={'reference_only':True,'frames':len(rows),'exact_serial_master_cases':2621440,'independent_solo_equivalence':6,'distinct_signatures':signatures,'silence':True,'mute':True,'dry_and_global_bypass_identity':True}
 (out/'report.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))
if __name__=='__main__':run()
