"""Read diagnostic command 10; no audio/control mutations."""
import argparse,json,struct,time
from pathlib import Path
from hardware_stream import Device
NAMES=['interval_min_minus_one','interval_max_minus_one','last_bad_interval_minus_one','bad_intervals','frame_timeouts','tx_mailbox_drops','chaos_deadline_faults','chaos_guard_resets']
def main():
 p=argparse.ArgumentParser();p.add_argument('--port',default='COM14');p.add_argument('--seconds',type=float,default=30);p.add_argument('--output',default='build/line-clock-diagnostics.json');a=p.parse_args()
 if a.seconds<=0:p.error('--seconds must be positive')
 d=Device(a.port);rows=[];start=time.monotonic()
 try:
  while True:
   rows.append({'elapsed':time.monotonic()-start,'status':d.status(),'clock':dict(zip(NAMES,struct.unpack('<8I',d.request(10)))),'audio':d.diagnostics()})
   if time.monotonic()-start>=a.seconds:break
   time.sleep(max(0,min(2,a.seconds-(time.monotonic()-start))))
 finally:d.close()
 Path(a.output).write_text(json.dumps(rows,indent=2));print(json.dumps({'first':rows[0],'last':rows[-1]},indent=2))
if __name__=='__main__':main()
