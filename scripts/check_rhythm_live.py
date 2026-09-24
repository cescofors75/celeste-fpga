"""Read-only physical FPGA snapshots; no audio/control commands are sent."""
import json,struct,time
from pathlib import Path
import serial
frames=[];buffer=b''
with serial.Serial('COM14',3000000,timeout=.1) as s:
 s.reset_input_buffer();end=time.monotonic()+6
 while time.monotonic()<end:
  buffer+=s.read(4096)
  while True:
   start=buffer.find(b'RHL1')
   if start<0:buffer=buffer[-3:];break
   if len(buffer)<start+52:buffer=buffer[start:];break
   data=buffer[start+4:start+52];buffer=buffer[start+52:]
   frames.append({'knobs':list(data[:8]),'patterns':list(struct.unpack_from('<4H',data,8)),
    'steps':[(int.from_bytes(data[16:18],'little')>>(i*4))&15 for i in range(4)],
    'levels':list(data[18:22]),'ring':int.from_bytes(data[22:24],'little'),'flags':data[24],
    'source':struct.unpack_from('<h',data,32)[0],'gated':struct.unpack_from('<h',data,34)[0],
    'out_l':struct.unpack_from('<h',data,36)[0],'out_r':struct.unpack_from('<h',data,38)[0],
    'samples':int.from_bytes(data[40:44],'little'),'faults':int.from_bytes(data[44:48],'little')})
assert frames,'No diagnostic frames received'
result={'count':len(frames),'first':frames[0],'last':frames[-1],
 'steps_seen':[sorted({f['steps'][i] for f in frames}) for i in range(4)],
 'levels_range':[[min(f['levels'][i] for f in frames),max(f['levels'][i] for f in frames)] for i in range(4)],
 'source_peak':max(abs(f['source']) for f in frames),'gate_peak':max(abs(f['gated']) for f in frames),'output_peak':max(abs(f['out_l']) for f in frames),
 'gate_zero_frames':sum(f['gated']==0 for f in frames),'flags_seen':sorted({f['flags'] for f in frames})}
Path('build/rhythm-live-snapshots.json').write_text(json.dumps(frames,indent=2))
Path('build/rhythm-live-summary.json').write_text(json.dumps(result,indent=2))
print(json.dumps(result,indent=2))
