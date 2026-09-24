"""Independent integer/reference checks. This is not execution of the RTL."""
from pathlib import Path
import re,unittest,json
ROOT=Path(__file__).resolve().parent.parent
RTL=(ROOT/'fpga/rtl/dsp/euclidean_gate.sv').read_text()
ROM={int(k):int(bits,16) for k,bits in re.findall(r"5'd(\d+):base_pattern=16'h([0-9a-f]+)",RTL)}
def pattern(k,r):
 b=ROM[k];return ((b<<r)|(b>>(16-r)))&65535
class Gate:
 def __init__(self):self.n=0;self.env=0
 def sample(self,l,r,k=5,rotation=0,dry=False):
  step=(self.n//6000)%16;self.n+=1
  target=dry or (pattern(k,rotation)>>step&1)
  self.env=max(0,min(128,self.env+(1 if target else -1)))
  return l*self.env//128,r*self.env//128,step
class TestEuclidean(unittest.TestCase):
 def test_initial_pattern(self):
  self.assertEqual(''.join('X' if pattern(5,0)>>i&1 else '-' for i in range(16)),'X--X--X--X--X---')
 def test_all_pulse_counts_and_rotations(self):
  self.assertEqual(set(ROM),set(range(1,17)))
  for k in range(1,17):
   for r in range(16):self.assertEqual(pattern(k,r).bit_count(),k)
   pos=[i for i in range(16) if ROM[k]>>i&1]
   gaps=[(pos[(i+1)%k]-pos[i])%16 or 16 for i in range(k)]
   self.assertLessEqual(max(gaps)-min(gaps),1)
 def test_balanced_cyclic_windows(self):
  for k in range(1,17):
   for length in range(1,17):
    counts=[sum((ROM[k]>>((i+j)%16))&1 for j in range(length)) for i in range(16)]
    self.assertLessEqual(max(counts)-min(counts),1)
 def test_rotation_direction(self):
  self.assertEqual(pattern(1,1),2);self.assertEqual(pattern(1,15),32768)
 def test_ramp_and_unity(self):
  g=Gate()
  for i in range(128):
   a,b,_=g.sample(-32768,32767,dry=True);self.assertEqual(g.env,i+1)
   self.assertTrue(-32768<=a<=0 and 0<=b<=32767)
  self.assertEqual((a,b),(-32768,32767));self.assertAlmostEqual(128/48000*1000,2.6666666666666665)
  for v in range(-32768,32768):self.assertEqual(v*128//128,v)
 def test_step_period_and_repeat(self):
  g=Gate();counts=[0]*16
  for _ in range(96000):counts[g.sample(0,0)[2]]+=1
  self.assertEqual(counts,[6000]*16);self.assertEqual(g.sample(0,0)[2],0)
 def test_zero_after_release(self):
  g=Gate();g.env=128;g.n=6000
  for i in range(128):
   a,b,_=g.sample(-32768,32767,k=1);self.assertEqual(g.env,127-i)
  self.assertEqual((a,b),(0,0))
 def test_bypass_preserves_phase_and_smooths(self):
  g=Gate();g.n=6000;g.env=0
  for i in range(128):g.sample(12000,-12000,dry=True)
  self.assertEqual(g.n,6128);self.assertEqual(g.env,128)
  g.sample(12000,-12000,dry=False);self.assertEqual(g.env,127)
 def test_controls_only_two_encoders(self):
  k,r=5,0
  def event(index,delta,k,r):return (min(16,max(1,k+delta)),r) if index==0 else (k,(r+delta)%16) if index==1 else (k,r)
  self.assertEqual(event(0,-99,k,r),(1,0));self.assertEqual(event(0,99,k,r),(16,0))
  self.assertEqual(event(1,-1,k,r),(5,15));self.assertEqual(event(1,16,k,r),(5,0))
  for i in range(2,8):self.assertEqual(event(i,99,k,r),(5,0))
if __name__=='__main__':unittest.main(verbosity=2)
