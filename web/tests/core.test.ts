import {beforeAll,describe,it,expect} from 'vitest';
import {readFileSync} from 'node:fs';
import init,{PreparedAudio,validate_patch,validate_session,encode_packet} from '../src/wasm/celeste_wasm';
import {defaultPatch,normalize} from '../src/model';
import {presets,presetPatch} from '../src/presets';
import {ControlLink,routeMask} from '../src/control';
import {PacketFramer,parseStatus} from '../src/transport';
beforeAll(async()=>{await init({module_or_path:readFileSync(new URL('../src/wasm/celeste_wasm_bg.wasm',import.meta.url))});});
describe('Actual Rust WASM exports',()=>{
 it('preserves all PCM16 codes and stereo isolation through real Rust decoding',()=>{
  const frames=65536,b=new Uint8Array(44+frames*4),v=new DataView(b.buffer);
  b.set(new TextEncoder().encode('RIFF'));v.setUint32(4,b.length-8,true);b.set(new TextEncoder().encode('WAVEfmt '),8);v.setUint32(16,16,true);v.setUint16(20,1,true);v.setUint16(22,2,true);v.setUint32(24,48000,true);v.setUint32(28,192000,true);v.setUint16(32,4,true);v.setUint16(34,16,true);b.set(new TextEncoder().encode('data'),36);v.setUint32(40,frames*4,true);
  for(let i=0;i<frames;i++)v.setInt16(44+4*i,i-32768,true);
  const a=new PreparedAudio(b),pcm=a.chunk(0,frames),out=new DataView(pcm.buffer,pcm.byteOffset,pcm.byteLength);
  try{for(let i=0;i<frames;i++){expect(out.getInt16(4*i,true)).toBe(i-32768);expect(out.getInt16(4*i+2,true)).toBe(0);}}finally{a.free();}
 });
 it('measures resampler bandwidth and error through the shipped Rust/WASM',()=>{
  for(const frequency of [100,1000,10000,18000,20000]){
   const frames=8820,b=new Uint8Array(44+frames*4),v=new DataView(b.buffer);
   b.set(new TextEncoder().encode('RIFF'));v.setUint32(4,b.length-8,true);b.set(new TextEncoder().encode('WAVEfmt '),8);v.setUint32(16,16,true);v.setUint16(20,1,true);v.setUint16(22,2,true);v.setUint32(24,44100,true);v.setUint32(28,176400,true);v.setUint16(32,4,true);v.setUint16(34,16,true);b.set(new TextEncoder().encode('data'),36);v.setUint32(40,frames*4,true);
   for(let i=0;i<frames;i++)v.setInt16(44+i*4,Math.round(12000*Math.sin(2*Math.PI*frequency*i/44100)),true);
   const a=new PreparedAudio(b);try{
    expect(JSON.parse(a.metadata()).frames).toBe(9600);const pcm=a.chunk(0,9600),out=new DataView(pcm.buffer,pcm.byteOffset,pcm.byteLength);let real=0,imag=0,error=0;
    for(let i=480;i<9120;i++){const phase=2*Math.PI*frequency*i/48000,x=out.getInt16(i*4,true);expect(out.getInt16(i*4+2,true)).toBe(0);real+=x*Math.cos(phase);imag+=x*Math.sin(phase);error+=(x-12000*Math.sin(phase))**2;}
    const gain=20*Math.log10(2*Math.hypot(real,imag)/8640/12000),residual=20*Math.log10(Math.sqrt(error/8640)/32768);
    console.log(`RESAMPLE ${frequency} Hz: ${gain.toFixed(3)} dB, error ${residual.toFixed(2)} dBFS`);expect(Math.abs(gain)).toBeLessThan(1);expect(residual).toBeLessThan(-35);
   }finally{a.free();}
  }
 },15000);
 it('ships presets that roundtrip in WASM and compile to supported FPGA controls',()=>{
  presets.forEach((_,i)=>{const patch=presetPatch(i);expect(JSON.parse(validate_patch(JSON.stringify(patch)))).toEqual(patch);expect(routeMask(patch,true,true,true)).toBeGreaterThan(0);const controls=new ControlLink();controls.expanded=controls.extended=controls.dual=controls.sonic=true;expect(()=>controls.queue(patch)).not.toThrow();});
 });
 it('roundtrips patch/session independently of WAV bytes',()=>{
  const patch=JSON.parse(validate_patch(JSON.stringify(defaultPatch())));
  const session={format:'celeste-session',version:1,patch,sample:{name:'test.wav',size:200,sha256:'a'.repeat(64)},position:400,looping:true,tempo:120};
  expect(JSON.parse(validate_session(JSON.stringify(session)))).toEqual(session);
 });
 it('rejects cyclic graphs and unknown parameters in WASM',()=>{
  const patch=defaultPatch();patch.routes=[['glitch','delay'],['delay','glitch']];expect(()=>validate_patch(JSON.stringify(patch))).toThrow();
  const other=defaultPatch();other.parameters['unknown']=.5;expect(()=>validate_patch(JSON.stringify(other))).toThrow();
  const invalidMute=defaultPatch();invalidMute.mute={unknown:true};expect(()=>validate_patch(JSON.stringify(invalidMute))).toThrow();
  const invalidSolo=defaultPatch();invalidSolo.solo={lfo:true};expect(()=>validate_patch(JSON.stringify(invalidSolo))).toThrow();
 });
 it('rejects duplicate audio sources and invalid session hashes',()=>{
  const patch=defaultPatch();patch.routes.push(['delay','filter']);expect(()=>validate_patch(JSON.stringify(patch))).toThrow();
  expect(()=>validate_session(JSON.stringify({format:'celeste-session',version:1,patch:defaultPatch(),sample:{name:'a',size:1,sha256:'x'},position:0,looping:false,tempo:null}))).toThrow();
 });
 it('normalizes boundary and nonfinite parameter input',()=>{expect([-1,.5,2,NaN,Infinity].map(normalize)).toEqual([0,.5,1,0,0]);});
 it('decodes mono PCM to paired stereo with bounded chunks',()=>{
  const b=new Uint8Array(48),v=new DataView(b.buffer);b.set(new TextEncoder().encode('RIFF'));v.setUint32(4,40,true);b.set(new TextEncoder().encode('WAVEfmt '),8);v.setUint32(16,16,true);v.setUint16(20,1,true);v.setUint16(22,1,true);v.setUint32(24,48000,true);v.setUint32(28,96000,true);v.setUint16(32,2,true);v.setUint16(34,16,true);b.set(new TextEncoder().encode('data'),36);v.setUint32(40,4,true);v.setInt16(44,-32768,true);v.setInt16(46,32767,true);
  const a=new PreparedAudio(b);expect(JSON.parse(a.metadata()).frames).toBe(2);expect([...a.chunk(0,256)]).toEqual([0,128,0,128,255,127,255,127]);expect(a.chunk(4,1).length).toBe(0);a.free();
 });
 it('recovers fragmented/coalesced serial frames and corrupt CRCs',()=>{
  const f=new PacketFramer(),a=encode_packet(0x81,7,new TextEncoder().encode('CELESTE/1')),b=encode_packet(0x82,8,new Uint8Array(32));
  expect(f.push(a.slice(0,5))).toEqual([]);expect(f.push(new Uint8Array([...a.slice(5),...b])).map(p=>p.sequence)).toEqual([7,8]);
  const corrupt=a.slice();corrupt[10]^=1;expect(f.push(new Uint8Array([...corrupt,...a])).map(p=>p.sequence)).toEqual([7]);expect(f.errors).toBeGreaterThan(0);
 });
 it('status cannot be invented from short data',()=>{expect(()=>parseStatus(new Uint8Array(3))).toThrow();});
 it('decodes 32-bit SDRAM credits without truncating at 65535 frames',()=>{
  const p=new Uint8Array(40),v=new DataView(p.buffer);v.setUint32(0,48000,true);v.setUint16(4,65535,true);v.setUint16(6,65535,true);v.setUint16(28,8191,true);v.setUint32(32,131072,true);v.setUint32(36,100000,true);
  expect(parseStatus(p)).toMatchObject({capacity:131072,fill:100000,capabilities:8191});
  expect(()=>parseStatus(p.slice(0,32))).toThrow();v.setUint16(28,4095,true);expect(()=>parseStatus(p)).toThrow();
 });
});
