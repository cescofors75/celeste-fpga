"""Load the isolated Euclidean experiment into volatile SRAM; preserve flash."""
from pathlib import Path
import hashlib,json,re,subprocess,time
import serial
ROOT=Path(__file__).resolve().parent.parent
fs=ROOT/'deliverables/celeste_euclidean_test.fs'
expected='91a8f13362803fdf77b8246fbad39f19fbbea999167ab7e9fccaf8cc2c3d3bb5'
assert hashlib.sha256(fs.read_bytes()).hexdigest()==expected,'Unexpected firmware'
report=(ROOT/'build/euclidean-test/impl/pnr/celeste_euclidean_test_tr_content.html').read_text()
for kind in ['Setup','Hold']:
 m=re.search(r'Numbers of '+kind+r' Violated Endpoints</td>\s*<td>(\d+)</td>',report)
 assert m and int(m[1])==0,kind
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
(ROOT/'build/euclidean-loaded.json').write_text(json.dumps({'sha256':expected,'operation':'SRAM only','programmer_returncode':p.returncode,'programmer_output':p.stdout,'clock_hz':12288000,'listening_validation':'pending','loaded_at':time.strftime('%Y-%m-%dT%H:%M:%S')},indent=2))
