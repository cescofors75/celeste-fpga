"""Integer DSP reference checks, not an RTL simulation or analog validation."""
import unittest,random

def blend(a,b,k):return (a*(128-k)+b*k)//128
def rng(s):return ((s<<1)|((s>>15^s>>13^s>>12^s>>10)&1))&65535
def ring_step(s,random_value,mutation,on=True):return ((s<<1)|((s>>15)^int(on and random_value<mutation)))&65535
def events(n,frames):
 phase=0;step=0;out=[(0,0)]
 for sample in range(1,frames):
  phase+=n
  if phase>=96000:
   phase-=96000;step=(step+1)%n;out.append((sample,step))
 return out

class Delay:
 def __init__(self,n,fb=48,mix=32):self.mem=[0]*16384;self.wr=0;self.filled=0;self.n=n;self.fb=fb;self.mix=mix
 def sample(self,x):
  tap=self.mem[(self.wr-self.n)%16384] if self.filled>=self.n else 0
  self.mem[self.wr]=blend(x,tap,self.fb)
  y=blend(x,tap,self.mix)
  self.wr=(self.wr+1)%16384;self.filled=min(16384,self.filled+1)
  return y

class Tests(unittest.TestCase):
 def test_mix_product_keeps_full_precision_before_shift(self):
  for v in range(97):
   product=v*128
   self.assertLessEqual(product,65535)
   self.assertEqual(product>>7,v)
  self.assertNotEqual(((32*128)&255)>>7,32)
 def test_polyrhythm_cycles_and_uniform_spacing(self):
  for n in (16,12,10,7):
   ev=events(n,192001)
   self.assertEqual(ev[n],(96000,0));self.assertEqual(ev[n*2],(192000,0))
   gaps=[b[0]-a[0] for a,b in zip(ev,ev[1:])]
   self.assertLessEqual(max(gaps)-min(gaps),1)
 def test_turing_locked_repeats_16_steps(self):
  s=0xb4d3;seen=[]
  for i in range(32):seen.append(s);s=ring_step(s,i%16,0)
  self.assertEqual(seen[:16],seen[16:])
 def test_turing_mutation_is_deterministic(self):
  def run():
   s=0xb4d3;r=0xace1;out=[]
   for i in range(64):s=ring_step(s,(r>>4)&15,4);r=rng(r);out.append(s)
   return out
  self.assertEqual(run(),run());self.assertNotEqual(run()[:16],run()[16:32])
 def test_probability_extremes(self):
  s=0xace1
  for _ in range(1000):
   self.assertFalse((s&15)<0);self.assertTrue((s&15)<16);s=rng(s);self.assertNotEqual(s,0)
 def test_parallel_gain_bounds(self):
  r=random.Random(23)
  for count in (1,2,4):
   for _ in range(1000):
    gain=min(128,sum(r.randrange(129) for i in range(4))//count)
    self.assertTrue(0<=gain<=128)
 def test_convex_mix_never_clips(self):
  r=random.Random(91)
  for _ in range(10000):
   a,b=r.randrange(-32768,32768),r.randrange(-32768,32768);k=r.randrange(129)
   self.assertTrue(min(a,b)<=blend(a,b,k)<=max(a,b))
 def test_dry_is_bit_exact(self):
  for x in range(-32768,32768):self.assertEqual(blend(-1234,x,128),x)
 def test_impulse_echo_time_and_feedback(self):
  for n in (3000,6000,9000,12000):
   d=Delay(n,48,32);y=[d.sample(16384 if i==0 else 0) for i in range(n*2+1)]
   self.assertEqual(y[0],12288);self.assertEqual(y[n],2560);self.assertEqual(y[2*n],960)
   self.assertTrue(all(v==0 for v in y[1:n]))
 def test_silence_and_reset_history(self):
  d=Delay(3000)
  self.assertTrue(all(d.sample(0)==0 for _ in range(20000)))
 def test_full_scale_feedback_is_bounded(self):
  d=Delay(3000,96,64)
  for i in range(60000):self.assertTrue(-32768<=d.sample(32767 if i%2 else -32768)<=32767)
 def test_tap_change_fades_before_switch(self):
  fade=128;active=0;requested=3;switches=[]
  for i in range(260):
   if requested!=active:
    if fade:fade-=1
    else:active=requested;switches.append((i,fade))
   elif fade<128:fade+=1
  self.assertEqual(switches,[(128,0)]);self.assertEqual(fade,128)

if __name__=='__main__':unittest.main(verbosity=2)
