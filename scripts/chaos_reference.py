"""Integer reference for CBM-4 laboratory RTL. Not a recording of FPGA audio."""
from dataclasses import dataclass,field
import math,json,wave,struct,hashlib
from pathlib import Path

def sat(v):return min(32767,max(-32768,v))
def henon(x,y):
 nx=1048576-(((x*x)>>20)*1468006>>20)+y
 ny=(x*314573)>>20
 return nx,ny
@dataclass
class Buffer:
 memory:list=field(default_factory=lambda:[(0,0)]*2048)
 wr:int=0
 filled:int=0
 x:list=field(default_factory=lambda:[(1638+i*997)*64 for i in range(4)])
 y:list=field(default_factory=lambda:[0]*4)
 pos:list=field(default_factory=lambda:[i*384 for i in range(4)])
 old:list=field(default_factory=lambda:[i*384 for i in range(4)])
 age:list=field(default_factory=lambda:[i*47 for i in range(4)])
 fade:list=field(default_factory=lambda:[32]*4)
 reverse:list=field(default_factory=lambda:[False]*4)
 oldreverse:list=field(default_factory=lambda:[False]*4)
 guards:int=0
 def step(self,frame,amount=65535,size=32768,master=65535,raw=False,bypass=False):
  self.memory[self.wr]=frame;self.wr=(self.wr+1)&2047;self.filled=min(2048,self.filled+1)
  sums=[0,0];length=256+(size>>6)
  for i in range(4):
   w=32 if raw else self.fade[i]
   old,new=self.memory[self.old[i]],self.memory[self.pos[i]]
   sample=[((a*(32-w)+b*w)>>5) if self.filled==2048 else 0 for a,b in zip(old,new)]
   sums[0]+=sample[0]*[4,3,1,0][i];sums[1]+=sample[1]*[0,1,3,4][i]
   self.old[i]=(self.old[i]+(-1 if self.oldreverse[i] else 1))&2047
   if self.age[i]>=length+i*4:
    self.age[i]=0;self.fade[i]=0;self.old[i]=(self.pos[i]+(-1 if self.reverse[i] else 1))&2047;self.oldreverse[i]=self.reverse[i]
    nx,ny=henon(self.x[i],self.y[i]);magnitude=abs(nx)
    if abs(nx)>1920000:self.x[i],self.y[i]=(1638+i*997)*64,0;self.guards+=1
    else:self.x[i],self.y[i]=nx,ny
    self.pos[i]=(self.wr-(64+(magnitude&1023)))&2047;self.reverse[i]=nx<0
   else:
    self.age[i]+=1;self.pos[i]=(self.pos[i]+(-1 if self.reverse[i] else 1))&2047;self.fade[i]=min(32,self.fade[i]+1)
  mix=0 if bypass else amount+(amount==65535);gain=master+(master==65535)
  return tuple(sat((sat((dry*(65536-mix)+(wet>>3)*mix)>>16)*gain)>>16) for dry,wet in zip(frame,sums))

def run():
 out=Path('build/chaos-reference');out.mkdir(parents=True,exist_ok=True)
 report={'reference_only':True,'tests':{},'henon':[]}
 for i in range(4):
  x,y=(1638+i*997)*64,0;seen={};repeat=None;lo=99999999;hi=-99999999
  for n in range(100000):
   if (x,y) in seen:repeat={'first':seen[x,y],'period':n-seen[x,y]};break
   seen[x,y]=n;lo=min(lo,x);hi=max(hi,x);x,y=henon(x,y)
   assert abs(x)<=1920000,'Henon escaped guard range'
  assert repeat is None or repeat['period']>=10000,'Unacceptable short state cycle'
  report['henon'].append({'seed':i,'x_min':lo,'x_max':hi,'first_repeat':repeat,'iterations':n+1})
 sources={
  'silence':[(0,0)]*8000,
  'impulse':[(20000,-18000) if n==2300 else (0,0) for n in range(8000)],
  'sine':[(int(16000*math.sin(n*2*math.pi*440/48000)),int(12000*math.sin(n*2*math.pi*660/48000))) for n in range(12000)],
  'transients':[(18000 if n%1300<20 else 0,-18000 if n%1100<20 else 0) for n in range(10000)],
  'fullscale':[(32767,-32768)]*8000}
 for name,frames in sources.items():
  a=Buffer();render=[a.step(f) for f in frames];b=Buffer();assert render==[b.step(f) for f in frames]
  assert all(-32768<=v<=32767 for f in render for v in f)
  c=Buffer();assert [c.step(f,bypass=True) for f in frames]==frames
  c=Buffer();assert [c.step(f,amount=0) for f in frames]==frames
  if name=='silence':assert all(f==(0,0) for f in render)
  if name in ('sine','transients','impulse'):assert any(f!=(0,0) for f in render[2048:])
  packed=b''.join(struct.pack('<hh',*f) for f in render)
  report['tests'][name]={'frames':len(frames),'sha256':hashlib.sha256(packed).hexdigest(),'guard_resets':a.guards,'max_abs':max(abs(v) for f in render for v in f)}
  if name=='sine':
   with wave.open(str(out/'cbm4-sine-reference.wav'),'wb') as w:w.setnchannels(2);w.setsampwidth(2);w.setframerate(48000);w.writeframes(packed)
 # Test vectors include exact integer expected results for HDL simulation.
 a=Buffer();frames=sources['sine'];render=[a.step(f) for f in frames];a=Buffer();render += [a.step(f,raw=True) for f in frames];frames=frames+frames
 (out/'input.hex').write_text('\n'.join(f'{((r&65535)<<16)|(l&65535):08x}' for l,r in frames)+'\n')
 (out/'expected.hex').write_text('\n'.join(f'{((r&65535)<<16)|(l&65535):08x}' for l,r in render)+'\n')
 (out/'report.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))
if __name__=='__main__':run()
