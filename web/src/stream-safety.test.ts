import {it,expect,vi} from 'vitest';
import {Streamer} from './stream';
import type {AudioStore} from './audio';
import type {Transport,Status} from './transport';
const state=():Status=>({sampleRate:48000,capacity:8192,fill:0,underruns:0,overruns:0,sampleCounter:0,protocolErrors:0,engineMask:63,routeMask:1,capabilities:255,running:false});
it.each([32768,131072])('fills the entire %i-frame SDRAM reservoir before START',async(capacity)=>{
 const stream=new Streamer(),s={...state(),capacity};let batches=0,starts=0;
 const t:Transport={close:async()=>{},request:async kind=>{
  if(kind===5){starts++;expect(s.fill).toBe(capacity);await stream.stop();}
  return statusPacket(s);
 },audioBatch:async chunks=>{const n=chunks.reduce((sum,c)=>sum+c.length/4,0);expect(n).toBeLessThanOrEqual(s.capacity-s.fill);s.fill+=n;batches++;return {...s};}};
 const a={metadata:{frames:48000},chunk:async()=>new Uint8Array(48000*4)} as unknown as AudioStore;
 await stream.play(t,a,()=>true);expect(starts).toBe(1);expect(batches).toBe(capacity/16384);
});
function statusPacket(s:Status){const wide=s.capacity>65535,p=new Uint8Array(wide?40:32),v=new DataView(p.buffer);v.setUint32(0,s.sampleRate,true);v.setUint16(4,s.capacity,true);v.setUint16(6,s.fill,true);v.setUint32(8,s.underruns,true);v.setUint32(12,s.overruns,true);v.setUint32(16,s.sampleCounter,true);v.setUint32(20,s.protocolErrors,true);v.setUint16(28,s.capabilities|(wide?4096:0),true);if(wide){v.setUint32(32,s.capacity,true);v.setUint32(36,s.fill,true);}v.setUint16(30,+s.running,true);return {kind:130,sequence:0,payload:p};}
it('recovers a depleted SDRAM queue with a larger credit-safe burst',async()=>{
 const stream=new Streamer(),s={...state(),capacity:32768};let recovery=0;
 const t:Transport={close:async()=>{},request:async kind=>{
  if(kind===5){s.running=true;s.fill=4000;}
  return statusPacket(s);
 },audioBatch:async chunks=>{
  const n=chunks.reduce((sum,c)=>sum+c.length/4,0);
  expect(n).toBeLessThanOrEqual(s.capacity-s.fill);
  if(s.running){recovery=n;await stream.stop();}else s.fill+=n;
  return {...s};
 }};
 const a={metadata:{frames:48000},chunk:async()=>new Uint8Array(48000*4)} as unknown as AudioStore;
 await stream.play(t,a,()=>true);expect(recovery).toBeGreaterThan(8192);
});
it.each(['underruns','overruns','protocolErrors'] as const)('stops and reports a %s delta instead of continuing corrupted audio',async counter=>{
 const stream=new Streamer(),s=state();let stops=0,batches=0;
 const t:Transport={close:async()=>{},request:async kind=>{if(kind===6)stops++;return statusPacket(s);},audioBatch:async chunks=>{batches++;expect(chunks.reduce((n,c)=>n+c.length/4,0)).toBeLessThanOrEqual(8192);return {...s,[counter]:1};}};
 const audio={metadata:{frames:4000},chunk:async()=>new Uint8Array(16000)} as unknown as AudioStore;
 const failure=vi.fn();stream.onError=failure;await stream.play(t,audio,()=>true);
 expect(failure).toHaveBeenCalledOnce();expect(stream.playing).toBe(false);expect(stops).toBe(2);expect(batches).toBe(1);
});
it('does not send PCM or START after cancellation during asynchronous preparation',async()=>{
 const stream=new Streamer(),commands:number[]=[];let resolve!:(b:Uint8Array)=>void;
 const t:Transport={close:async()=>{},request:async kind=>{commands.push(kind);return statusPacket(state());},audioBatch:vi.fn()};
 const audio={metadata:{frames:4000},chunk:()=>new Promise<Uint8Array>(r=>{resolve=r;})} as unknown as AudioStore;
 const pending=stream.play(t,audio,()=>true);await vi.waitFor(()=>expect(resolve).toBeDefined());await stream.stop(t);resolve(new Uint8Array(16000));await pending;
 expect(commands).not.toContain(5);expect(t.audioBatch).not.toHaveBeenCalled();expect(stream.playing).toBe(false);
});
it('rejects incompatible sample clocks before reading PCM',async()=>{
 const stream=new Streamer(),s={...state(),sampleRate:44100};const read=vi.fn();let error:unknown;
 const t:Transport={close:async()=>{},request:async()=>statusPacket(s)};
 stream.onError=e=>error=e;await stream.play(t,{metadata:{frames:4},chunk:read} as unknown as AudioStore,()=>true);
 expect(error).toBeInstanceOf(Error);expect(read).not.toHaveBeenCalled();
});
