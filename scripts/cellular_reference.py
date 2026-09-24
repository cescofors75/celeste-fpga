"""Cellular 256 reference and PCM16 renderer; synthetic/reference audio only."""
from dataclasses import dataclass,field
from pathlib import Path
import json,random,math,struct,hashlib
MASK=(1<<256)-1
INITIAL=int('c31e57e1946af02d792bea1085d3c6f029174dba635ef880a73c921d4e6b05af',16)^0xce1e57e1
def evolve(c,rule):
 l=((c<<1)&MASK)|(c>>255);r=(c>>1)|((c&1)<<255)
 return (l^(c|r))&MASK if rule==30 else (l^r) if rule==90 else ((c^r)|(~l&(c|r)))&MASK
def scalar(c,rule):
 return sum(((rule>>((((c>>((i-1)%256))&1)<<2)|(((c>>i)&1)<<1)|((c>>((i+1)%256))&1)))&1)<<i for i in range(256))
def sat(v):return min(32767,max(-32768,v))
@dataclass
class Cellular:
 memory:list=field(default_factory=lambda:[(0,0)]*8192)
 wr:int=0
 filled:int=0
 cells:int=INITIAL
 reseeds:int=0
 pos:list=field(default_factory=lambda:[i*384 for i in range(4)])
 old:list=field(default_factory=lambda:[i*384 for i in range(4)])
 anchor:list=field(default_factory=lambda:[i*384 for i in range(4)])
 age:list=field(default_factory=lambda:[i*47 for i in range(4)])
 fade:list=field(default_factory=lambda:[128]*4)
 reverse:list=field(default_factory=lambda:[False]*4)
 oldreverse:list=field(default_factory=lambda:[False]*4)
 silent:list=field(default_factory=lambda:[False]*4)
 oldsilent:list=field(default_factory=lambda:[False]*4)
 actions:list=field(default_factory=lambda:[0]*8)
 def step(self,frame,amount=65535,size=32768,master=65535,density=65535,rule=30,raw=False,bypass=False):
  freeze=((self.cells>>24)&255)<(density>>8) and ((self.cells>>21)&7)==5
  if not freeze or self.filled<8192:
   self.memory[self.wr]=frame;self.wr=(self.wr+1)&8191;self.filled=min(8192,self.filled+1)
  sums=[0,0];length=128+(size>>4)
  for i in range(4):
   w=128 if raw else self.fade[i];old=self.memory[self.old[i]] if not self.oldsilent[i] else (0,0);new=self.memory[self.pos[i]] if not self.silent[i] else (0,0)
   sample=[((a*(128-w)+b*w)>>7) if self.filled==8192 else 0 for a,b in zip(old,new)]
   sums[0]+=sample[0]*[4,3,1,0][i];sums[1]+=sample[1]*[0,1,3,4][i]
   self.old[i]=(self.old[i]+(-1 if self.oldreverse[i] else 1))&8191
   if self.age[i]>=length+i*4:
    decision=(self.cells>>(i*64))&255;active=((self.cells>>(i*64+8))&255)<(density>>8)
    self.age[i]=0;self.fade[i]=0;self.old[i]=(self.pos[i]+(-1 if self.reverse[i] else 1))&8191;self.oldreverse[i]=self.reverse[i];self.oldsilent[i]=self.silent[i];self.silent[i]=False
    if not active:self.pos[i]=self.anchor[i]=(self.wr-64)&8191;self.reverse[i]=False
    else:
     action=decision&7;self.actions[action]+=1
     if action in (1,3,5):self.pos[i]=self.anchor[i];self.reverse[i]=bool(decision&1 and decision&2)
     elif action==2:self.pos[i]=(self.anchor[i]+length)&8191;self.reverse[i]=True
     elif action==4:self.silent[i]=True;self.pos[i]=(self.wr-64)&8191;self.reverse[i]=False
     else:self.pos[i]=self.anchor[i]=(self.wr-(128+((decision>>3)<<7)))&8191;self.reverse[i]=bool(decision&32)
    if i==0:
     nxt=evolve(self.cells,rule)
     if nxt==0:self.cells=INITIAL;self.reseeds+=1
     else:self.cells=nxt
   else:self.age[i]+=1;self.pos[i]=(self.pos[i]+(-1 if self.reverse[i] else 1))&8191;self.fade[i]=min(128,self.fade[i]+1)
  mix=0 if bypass else amount+(amount==65535);gain=master+(master==65535)
  return tuple(sat(sat((dry*(65536-mix)+(wet>>3)*mix)>>16)*gain>>16) for dry,wet in zip(frame,sums))
def run():
 out=Path('build/cellular-reference');out.mkdir(parents=True,exist_ok=True);rng=random.Random(2026);report={'reference_only':True,'tests':{}}
 for rule in (30,90,110):
  for _ in range(100):
   c=rng.getrandbits(256);assert evolve(c,rule)==scalar(c,rule)
  c=INITIAL
  for _ in range(128):c=evolve(c,90)
  assert c==0
  signal=[(int(18000*math.sin(n*2*math.pi*330/48000)),int(14000*math.sin(n*2*math.pi*550/48000))) for n in range(24000)]
  a=Cellular();wet=[a.step(f,rule=rule) for f in signal];b=Cellular();assert wet==[b.step(f,rule=rule) for f in signal]
  b=Cellular();assert signal==[b.step(f,bypass=True,rule=rule) for f in signal]
  b=Cellular();assert all(b.step((0,0),rule=rule)==(0,0) for _ in range(10000))
  assert wet!=signal and any(f!=(0,0) for f in wet[8192:])
  assert all(-32768<=v<=32767 for f in wet for v in f)
  report['tests'][str(rule)]={'frames':len(signal),'actions':a.actions,'reseeds':a.reseeds,'hash':hashlib.sha256(b''.join(struct.pack('<hh',*f) for f in wet)).hexdigest()}
  (out/f'input-{rule}.hex').write_text('\n'.join(f'{((r&65535)<<16)|(l&65535):08x}' for l,r in signal)+'\n')
  (out/f'expected-{rule}.hex').write_text('\n'.join(f'{((r&65535)<<16)|(l&65535):08x}' for l,r in wet)+'\n')
 # Force rule-90 absorption/reseed using short fragments; ensure not permanently silent.
 a=Cellular()
 for n in range(18000):a.step((12000,-12000),size=0,rule=90)
 assert a.reseeds>=1
 report['rule90_reseed_test']=a.reseeds
 # Adversarial bounded input, dry identity and RAW path, independent of sine fixtures.
 for raw in (False,True):
  a=Cellular();b=Cellular()
  for n in range(20000):
   f=(32767,-32768) if n%2 else (-32768,32767)
   assert b.step(f,amount=0,raw=raw)==f
   y=a.step(f,raw=raw,size=0)
   assert all(-32768<=v<=32767 for v in y)
 report['full_scale_raw_xfade_and_dry_identity']=True
 # Worst-case splice of two opposite full-scale DC fragments: complementary
 # interpolation must stay bounded and reduce the maximum one-sample jump.
 def splice(n):return [((-32768*(n-w)+32767*w)//n) for w in range(n+1)]
 def jump(x):return max(abs(b-a) for a,b in zip(x,x[1:]))
 assert splice(128)[0]==-32768 and splice(128)[-1]==32767
 assert jump(splice(128))<=512
 assert jump(splice(128))*4<=jump(splice(32))
 report['worst_case_splice_step']={'old_32_samples':jump(splice(32)),'new_128_samples':jump(splice(128))}

 (out/'report.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))
if __name__=='__main__':run()
