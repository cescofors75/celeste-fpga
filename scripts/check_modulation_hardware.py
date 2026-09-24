"""Compare measured FPGA filter output with Chaos disabled/enabled; restore controls."""
import sys,struct,math,json
from hardware_stream import Device

def main():
 d=Device('COM14');saved=d.request(9);n=32 if len(saved)>=96 else 24;original=list(struct.unpack('<'+str(n)+'H',saved[:n*2]));rows=[]
 def put(k,v):d.request(3,struct.pack('<HH',k,v))
 try:
  d.request(6)
  for k,v in [(4,7864),(5,22937),(9,50000),(10,40000),(12,0),(19,1),(20,0),(32,8)]:put(k,v)
  for amount in [0,65535]:
   d.request(6);put(15,amount);s=d.status();base=s.copy();cursor=0;total=48000*6;started=False;levels=[]
   pcm=b''.join(struct.pack('<hh',v,v) for i in range(total) for v in [round(6000*math.sin(2*math.pi*2000*i/48000))])
   while cursor<total or s['running']:
    free=s['capacity']-s['fill']
    if cursor<total and (not started or free>=3072):
     count=min(free,total-cursor);data=pcm[cursor*4:(cursor+count)*4];chunks=[data[i:i+1024] for i in range(0,len(data),1024)]
     s=d.batch(chunks,7864);cursor+=count
     # Sideband meter readback inside the audio batch is handled by Device.
     if not started:d.request(5);started=True
     if cursor==total:d.request(7)
    else:
     import time
     time.sleep(.004);s=d.status()
    if started:
     # Read meters only when sufficient audio credit remains.
     if s['fill']>4096:
      snap=d.request(9);levels.append(struct.unpack_from('<H',snap,88 if len(snap)>=96 else 72)[0])
    if any(s[k]!=base[k] for k in ['underruns','overruns','errors']):raise RuntimeError(s)
   rows.append(dict(amount=amount,peak=max(levels),minimum=min(levels[3:]),mean=sum(levels[3:])/len(levels[3:]),readings=len(levels),status=s))
  assert rows[1]['peak']>rows[0]['peak']*3,rows
  print(json.dumps(rows,indent=2));print('PASS measured FPGA filter changes with Chaos')
 finally:
  d.request(6)
  for k,v in enumerate(original):
   if k!=21:put(k,v)
  put(32,saved[n*2+8]);d.close()
if __name__=='__main__':main()
