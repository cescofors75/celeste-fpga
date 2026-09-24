"""Restore the saved full CELESTE encoder/HDMI version into SRAM."""
from pathlib import Path
import hashlib,json,re,subprocess,time
import serial
ROOT=Path(__file__).resolve().parent.parent
fs=ROOT/'deliverables/checkpoints/2026-09-24-encoder-banks/celeste_line_in_encoder_banks.fs'
expected='adcd8ecdfa6d671aaf86671159a24c0c3b8afdb99148b025418bac6149804247'
assert hashlib.sha256(fs.read_bytes()).hexdigest()==expected,'Unexpected firmware'
validation=json.loads((ROOT/'deliverables/checkpoints/2026-09-24-encoder-banks/encoder-banks-validation.json').read_text())
assert validation['sha256']==expected and validation['timing']=={'Setup':0,'Hold':0}
with serial.Serial('COM14',115200,timeout=.3,write_timeout=2) as console:
 time.sleep(.5)
 for b in [b'\x18',b'\x03',b'\n']:
  console.write(b);console.flush();time.sleep(.08)
 console.read(8192)
 console.write(b'pll P1:35,1217,3125 D2@P1:72,0,1 O2@D2:0\n');console.flush();time.sleep(.2);console.read(8192)
 console.write(b'pll_clk\n');console.flush();time.sleep(.2)
 result=console.read(8192).decode(errors='replace');print(result,flush=True)
 console.write(b'choose uart\n');console.flush();time.sleep(.2)
 assert '12288000' in result,'Audio clock readback failed'
programmer='C:/DEV/tools/Gowin_V1.9.11.03_Education/Gowin_V1.9.11.03_Education_x64/Programmer/bin/programmer_cli.exe'
p=subprocess.run([programmer,'--device','GW2AR-18C','--cable-index','4','--channel','0','--operation_index','2','--fsFile',str(fs)],capture_output=True,text=True,timeout=40)
print(p.stdout,flush=True);print(p.stderr,flush=True)
p.check_returncode()
(ROOT/'build/restored-full-loaded.json').write_text(json.dumps({'sha256':expected,'operation':'SRAM only','programmer_returncode':p.returncode,'programmer_output':p.stdout,'clock_hz':12288000,'listening_validation':'pending','loaded_at':time.strftime('%Y-%m-%dT%H:%M:%S')},indent=2))

from hardware_stream import Device
import struct
saved=json.loads((ROOT/'build/encoders-before-load.json').read_text())
d=Device('COM14')
try:
 assert d.request(1)==b'CELESTE/1'
 d.request(6)
 def put(k,v):d.request(3,struct.pack('<HH',k,v))
 put(10,0)
 for k,v in enumerate(saved['controls']):
  if k not in (10,21):put(k,v)
 for k,v in enumerate(saved['extra']):
  if k<26 and k not in (12,22,23):put(64+k,v)
 profile=[0,2,24,4,13,14,12,15,67,70,72,75,79,82,84,10]
 for k,v in enumerate(profile):put(40+k,v)
 put(32,saved['routes']);put(10,saved['controls'][10]);d.request(5)
 snap=d.request(9)
 assert list(snap[64:72])==profile[8*((snap[73]>>4)&1):8*((snap[73]>>4)&1)+8]
 before=d.status();assert before['capabilities']==59391
 time.sleep(10)
 after=d.status();clock=struct.unpack('<8I',d.request(10))
 for k in ['errors','underruns','overruns']:assert after[k]==before[k],(k,before,after)
 assert after['running']==1 and after['samples']>before['samples']
 result={'before':before,'after':after,'clock':clock,'mappings':list(snap[64:72]),'saved_controls_restored':True,'hdmi_layout':'encoder values in left column','web_url':'http://127.0.0.1:5173/'}
 (ROOT/'build/restored-full-validation.json').write_text(json.dumps(result,indent=2))
 print(json.dumps(result,indent=2))
finally:d.close()
