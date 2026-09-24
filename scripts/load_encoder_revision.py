"""Load the expanded encoder revision in SRAM and restore the live controls afterward."""
from pathlib import Path
import json,struct,subprocess,sys,time
from hardware_stream import Device
root=Path(__file__).resolve().parent.parent
d=Device('COM14')
try:
 status=d.status();snap=d.request(9);extra=d.request(11)
 saved={'status':status,'controls':list(struct.unpack('<32H',snap[:64])),'mappings':list(snap[64:72]),'routes':snap[72],'extra':list(struct.unpack('<32H',extra[:64]))}
 (root/'build/encoders-before-load.json').write_text(json.dumps(saved,indent=2))
finally:d.close()
subprocess.run([sys.executable,str(root/'scripts/prepare_board.py'),'--line-in'],check=True,cwd=root)
d=Device('COM14')
try:
 def put(k,v):d.request(3,struct.pack('<HH',k,v))
 d.request(6);put(10,0)
 for k,v in enumerate(saved['controls']):
  if k not in (10,21):put(k,v)
 for k,v in enumerate(saved['extra']):
  if k<26 and k not in (12,22,23):put(64+k,v)
 profile=[0,2,24,4,13,14,12,15,67,70,72,75,79,82,84,10]
 for k,v in enumerate(profile):put(40+k,v)
 put(32,saved['routes']);put(10,saved['controls'][10])
 d.request(5 if status['running'] else 6)
 rb=d.request(9);eb=d.request(11)
 for k,v in enumerate(saved['controls']):
  if k!=21:assert struct.unpack_from('<H',rb,k*2)[0]==v,(k,'restore')
 assert eb[:64]==extra[:64]
 assert list(rb[64:72])==profile[8*(rb[73]>>4&1):8*(rb[73]>>4&1)+8]
 assert d.status()['capabilities']&32768
 before=d.status();time.sleep(10);after=d.status();clock=struct.unpack('<8I',d.request(10))
 for k in ['errors','underruns','overruns']:assert after[k]==before[k],(k,before,after)
 assert clock[6]==0,clock
 result={'controls_restored':True,'before':before,'after':after,'clock':clock,'input_peak':struct.unpack_from('<H',d.request(9),80)[0],'hdmi_visual_confirmation_pending':True}
 (root/'build/encoders-loaded-validation.json').write_text(json.dumps(result,indent=2));print(json.dumps(result),flush=True)
finally:d.close()
