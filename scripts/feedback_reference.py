"""Integer FDN reference. These are software tests, not captured FPGA audio."""
from pathlib import Path
from dataclasses import dataclass,field
import math,json,struct,hashlib
LENGTHS=(1493,1601,1867,1999)
def sat(x,lo=-32768,hi=32767):return min(hi,max(lo,x))
def slew(x,t):return x+min(32,t-x) if t>x else x-min(32,x-t)
def hadamard(t):
 a,b,c,d=t
 return [a+b+c+d,a-b+c-d,a+b-c-d,a-b-c+d]
@dataclass
class FDN:
 ram:list=field(default_factory=lambda:[[0]*n for n in LENGTHS])
 ptr:list=field(default_factory=lambda:[0]*4)
 damp:list=field(default_factory=lambda:[0]*4)
 controls:list=field(default_factory=lambda:[0]*4)
 limits:int=0
 def step(self,l,r,amount=32768,feedback=45875,tone=24576,master=26214,bypass=False):
  self.controls=[slew(x,t) for x,t in zip(self.controls,[0 if bypass else amount,feedback,tone,master])]
  mix,fb,tone,master=self.controls;alpha=2048+(tone>>1);gain=fb-(fb>>4)
  taps=[old+((self.ram[i][self.ptr[i]]-old)*alpha>>16) for i,old in enumerate(self.damp)]
  self.damp=taps;h=hadamard(taps)
  for i,inj in enumerate([l,r,-l,-r]):
   val=((h[i]>>1)*gain>>16)+(inj>>2)
   self.limits+=int(val>131071 or val< -131071)
   self.ram[i][self.ptr[i]]=sat(val,-131071,131071);self.ptr[i]=(self.ptr[i]+1)%LENGTHS[i]
  wet=[(taps[0]-taps[2])>>1,(taps[1]-taps[3])>>1]
  mix+=mix==65535;master+=master==65535
  return tuple(sat(sat((dry*(65536-mix)+w*mix)>>16)*master>>16) for dry,w in zip((l,r),wet))
def run():
 out=Path('build/feedback-reference');out.mkdir(parents=True,exist_ok=True)
 # H/2 preserves squared vector norm before fixed-point rounding.
 for v in ([1,2,3,4],[-32768,32767,-20000,18000],[131071]*4):assert sum(x*x for x in hadamard(v))==4*sum(x*x for x in v)
 f=FDN();assert all(f.step(0,0)==(0,0) for _ in range(6000))
 f=FDN()
 for _ in range(2048):f.step(0,0,amount=0,master=65535)
 for v in ((32767,-32768),(-32768,32767),(0,0),(1234,-5678)):assert f.step(*v,amount=0,master=65535)==v
 f=FDN()
 for _ in range(2048):f.step(0,0,amount=65535,feedback=0,master=65535)
 impulse=[f.step(32767 if n==0 else 0,0,amount=65535,feedback=0,master=65535) for n in range(6000)]
 assert next(i for i,v in enumerate(impulse) if v!=(0,0))==1493
 f=FDN();sig=[(int(20000*math.sin(n*.071)),int(18000*math.sin(n*.103))) for n in range(30000)]
 frames=[f.step(*v) for v in sig];g=FDN();assert frames==[g.step(*v) for v in sig]
 for name,data in [('input',sig),('expected',frames)]:
  (out/(name+'.hex')).write_text('\n'.join(f'{((r&65535)<<16)|(l&65535):08x}' for l,r in data)+'\n')
 # Maximum feedback, sustained worst-case bipolar/DC excitation, then six-second decay.
 f=FDN()
 for n in range(48000):
  y=f.step(32767,-32768,feedback=65535,amount=65535,master=65535)
  assert all(-32768<=x<=32767 for x in y)
 energy=[]
 for n in range(288000):
  y=f.step(0,0,feedback=65535,amount=65535,master=65535)
  if n%48000==0:energy.append(0)
  energy[-1]+=sum(x*x for x in y)
 assert energy[-1]<energy[0]*.001,(energy,f.limits)
 report={'reference_only':True,'matrix_energy_identity':True,'silence':True,'dry_identity_after_slew':True,'first_impulse_sample':1493,'deterministic_frames':len(frames),'max_feedback_decay_energy_per_second':energy,'limiter_events_during_stress':f.limits,'output_hash':hashlib.sha256(b''.join(struct.pack('<hh',*v) for v in frames)).hexdigest()}
 (out/'report.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))
if __name__=='__main__':run()
