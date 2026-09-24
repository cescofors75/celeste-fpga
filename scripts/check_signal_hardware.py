"""Measure both real delay branches before/after mixer, restoring the patch."""
import json,math,struct,time
from hardware_stream import Device
d=Device('COM14');saved=None
try:
 s=d.status();assert not s['running'],'Stop browser playback first';assert s['capabilities']&512
 saved=d.request(9);assert len(saved)==110 and saved[78]==6
 def put(k,v):d.request(3,struct.pack('<HH',k,v))
 for serial in (False,True):
  d.request(6)
  for k,v in [(2,4799*8),(3,10000),(24,2399*16),(25,15000),(26,30000),(27,3 if serial else 1),(6,0),(8,0 if serial else 30000),(10,40000),(20,0),(22,0),(32,0 if serial else 4)]:put(k,v)
  total=240000;pcm=b''.join(struct.pack('<hh',round(3000*math.sin(2*math.pi*440*i/48000)),round(2000*math.sin(2*math.pi*660*i/48000))) for i in range(total));cursor=0;started=False;peaks=[0]*15;s=d.status();initial=s.copy();began=time.monotonic()
  while cursor<total or s['running']:
   free=s['capacity']-s['fill']
   if cursor<total and (not started or free>=3072):
    count=min(free,total-cursor);data=pcm[cursor*4:(cursor+count)*4]
    s=d.batch([data[i:i+1024] for i in range(0,len(data),1024)]);cursor+=count
    if not started:d.request(5);started=True
    if cursor==total:d.request(7)
    if s['fill']>4096:
     snap=d.request(9);peaks=[max(a,b) for a,b in zip(peaks,struct.unpack_from('<15H',snap,80))]
   else:time.sleep(.004);s=d.status()
   assert all(s[k]==initial[k] for k in ('underruns','overruns','errors')),s
   assert time.monotonic()-began<20,'stream timeout'
  assert peaks[9]>4 and peaks[13]>4 and peaks[14]>4,peaks
  assert peaks[3]==0 if serial else peaks[3]>4,peaks
  assert s['samples']-initial['samples']==total
  print(json.dumps({'mode':'series' if serial else 'parallel','frames':total,'peaks':peaks,'status':s}),flush=True)
 print('PASS physical raw Delay 1 and Delay 2 activity; separate mix meters; muted D1 still feeds D2; zero transport errors')
finally:
 if saved:
  d.request(6)
  for k,v in enumerate(struct.unpack('<32H',saved[:64])):
   if k!=21:d.request(3,struct.pack('<HH',k,v))
  put(32,saved[72])
 d.close()
