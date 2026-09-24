"""Live line-in expansion readback, per-branch output, mute and solo. Restores controls."""
import json,struct,time
from pathlib import Path
from hardware_stream import Device

d=Device('COM14');saved=None;extra=None;rows=[]
def put(k,v):d.request(3,struct.pack('<HH',k,v))
def levels():
 b=d.request(11);assert len(b)==72;return list(b[64:72])
try:
 status=d.status();assert status['capabilities']&16384 and status['engines']==63
 saved=d.request(9);extra=d.request(11)
 if struct.unpack_from('<H',saved,80)[0]<256:raise RuntimeError('No continuous LINE IN signal: play music through PCM1808 and repeat.')
 Path('build/expanded-before-test.json').write_text(json.dumps({'controls':list(struct.unpack('<32H',saved[:64])),'routes':saved[72],'extra':list(struct.unpack('<32H',extra[:64])),'running':status['running']},indent=2))
 for k in (6,7,8,9,12,15,16,17,18,19,20,22,26,27):put(k,0)
 put(10,22937);put(32,0)
 defaults={64:0,65:0,66:24000,67:50000,68:50000,69:12000,70:60000,71:50000,72:36000,73:2000,74:50000,75:65535,77:50000,78:35000,79:65535,80:50000,81:27000,82:65535,83:50000,84:65535,85:32768,88:0,89:0}
 for k,v in defaults.items():put(k,v)
 readback=struct.unpack('<32H',d.request(11)[:64])
 for k,v in defaults.items():assert readback[k-64]==v,('register readback',k,readback[k-64],v)
 d.request(5)
 for i,name in enumerate(['chorus','flanger','crusher','freeze','tremolo','autopan']):
  put(64,1<<i);time.sleep(.6);v=levels();assert v[i]>0 and v[6]>0,(name,v)
  assert all(v[j]==0 for j in range(6) if j!=i),(name,'branch isolation',v)
  rows.append({'case':name,'levels':v});print(rows[-1],flush=True)
 # All branches allocated concurrently, then silence all through Mute.
 for k in (68,71,74,77,80,83):put(k,12000)
 put(64,63);time.sleep(.6);v=levels();assert all(v[i]>0 for i in range(6));rows.append({'case':'all_parallel','levels':v})
 put(88,8191);time.sleep(.6);v=levels();assert v[6]==0,('mute',v);rows.append({'case':'mute_all','levels':v})
 put(88,0);put(89,1<<8);time.sleep(.6);v=levels();assert v[2]>0 and v[6]>0 and all(v[i]==0 for i in (0,1,3,4,5));rows.append({'case':'solo_crusher','levels':v})
 put(89,0);put(64,64);put(32,8);put(9,50000);put(4,1500);put(5,12000);put(28,0);time.sleep(.6);snap=d.request(9);v=levels();assert struct.unpack_from('<H',snap,80+4*2)[0]>0 and v[7]>0;rows.append({'case':'envelope_filter','levels':v})
 # Legacy engines still produce output, and their individual Mute reaches silence.
 put(64,0);put(9,0)
 for name,route,mix,bit,settings in [
  ('glitch',2,7,0,{0:65535,1:65535,23:65535,29:65535,30:32768}),
  ('delay',4,8,1,{2:42000,3:32000}),
  ('filter',8,9,2,{4:18000,5:12000,28:0})]:
  put(32,route);put(mix,40000)
  for k,vv in settings.items():put(k,vv)
  time.sleep(.6);v=levels();assert v[6]>0,(name,'legacy output',v)
  put(88,1<<bit);time.sleep(.6);muted=levels();assert muted[6]==0,(name,'legacy mute',muted)
  rows.append({'case':name+'_legacy_mute','active':v,'muted':muted});put(88,0);put(mix,0)
 # Series dependency: solo either delay keeps the chain; mute either silences it.
 put(32,0);put(27,3);put(26,40000);put(24,24000);put(25,22000)
 for bit in (1,5):
  put(89,1<<bit);time.sleep(.6);v=levels();assert v[6]>0,('series solo',bit,v)
  put(89,0);put(88,1<<bit);time.sleep(.6);muted=levels();assert muted[6]==0,('series mute',bit,muted)
  rows.append({'case':'series_delay_'+str(bit),'solo':v,'muted':muted});put(88,0)
 put(27,0);put(26,0)
 # Master Mute must also silence a globally bypassed patch.
 put(20,65535);put(88,8191);time.sleep(.6);assert levels()[6]==0
 end=d.status();clock=struct.unpack('<8I',d.request(10));assert end['errors']==status['errors'] and end['underruns']==status['underruns'];assert clock[6]==0,clock
 result={'live_input_not_deterministic':True,'rows':rows,'status':end,'clock':clock};Path('build/expanded-live-validation.json').write_text(json.dumps(result,indent=2));print('PASS live output, isolation, all parallel, mute and solo',flush=True)
finally:
 if saved:
  for k,v in enumerate(struct.unpack('<32H',saved[:64])):
   if k!=21:put(k,v)
  put(32,saved[72])
 if extra:
  for k,v in enumerate(struct.unpack('<32H',extra[:64])):
   if k<26 and k not in (12,22,23):put(64+k,v)
 if saved and not status['running']:d.request(6)
 d.close()
