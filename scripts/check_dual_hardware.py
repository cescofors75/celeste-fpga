"""Verify new controls/snapshot on the real board, stream tone, restore state."""
import json,struct,subprocess,sys
from hardware_stream import Device

def main():
 d=Device('COM14');saved=None
 try:
  status=d.status();assert status['capabilities']&256,status
  saved=d.request(9);assert len(saved) in (96,110) and saved[78] in (5,6)
  assert not status['running'],'Stop playback before this test'
  d.request(6)
  for topology in (1,3):
   for key,value in [(2,4799*8),(3,12000),(6,0),(8,0 if topology==3 else 20000),(10,30000),(20,0),(22,0),(24,2399*16),(25,16000),(26,20000),(27,topology),(32,0 if topology==3 else 4)]:d.request(3,struct.pack('<HH',key,value))
   snap=d.request(9);assert struct.unpack_from('<H',snap,54)[0]==topology
   for bits in (1,2,4,8,16,32,64,128,255,0):
    d.request(3,struct.pack('<HH',22,bits));snap=d.request(9);assert struct.unpack_from('<H',snap,44)[0]==bits
   d.close()
   subprocess.run([sys.executable,'scripts/hardware_stream.py','--seconds','10','--tone','--diagnostics'],check=True)
   d=Device('COM14');after=d.status()
   assert all(after[k]==status[k] for k in ('underruns','overruns','errors')),after
   print('PASS hardware topology',topology,json.dumps(after),flush=True)
 finally:
  if saved:
   if not d.serial.is_open:d=Device('COM14')
   d.request(6)
   for k,v in enumerate(struct.unpack('<32H',saved[:64])):
    if k!=21:d.request(3,struct.pack('<HH',k,v))
   d.request(3,struct.pack('<HH',32,saved[72]))
  d.close()

if __name__=='__main__':main()
