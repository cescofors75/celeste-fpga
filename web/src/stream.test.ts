import {it,expect} from 'vitest';
import {Streamer,MAX_BUFFERED_FRAMES} from './stream';
import {LIVE_FRAMES} from './live-score';
import type {AudioStore} from './audio';
import type {Status,Transport} from './transport';
it('keeps the long live score on the prebuffered worker transport',async()=>{
 expect(LIVE_FRAMES).toBeLessThan(MAX_BUFFERED_FRAMES);
 const stream=new Streamer();let buffered=false,chunks=0;
 const pcm=new Uint8Array(4);
 const audio={metadata:{frames:LIVE_FRAMES},chunk:async(start:number,count:number)=>{expect(start).toBe(0);expect(count).toBe(LIVE_FRAMES);chunks++;return pcm;}} as unknown as AudioStore;
 const transport={playBuffered:async(data:Uint8Array)=>{expect(data).toBe(pcm);buffered=true;}} as unknown as Transport;
 await stream.play(transport,audio,()=>true);expect(buffered).toBe(true);expect(chunks).toBe(1);
});
it.each([5,41280,48000*48])('caches %i-frame loops and preserves PCM across window and loop boundaries',async(frames)=>{
 const stream=new Streamer();let calls=0,batches=0,received=0;
 const state:Status={sampleRate:48000,capacity:8192,fill:0,underruns:0,overruns:0,sampleCounter:0,protocolErrors:0,engineMask:7,routeMask:1,capabilities:7,running:false};
 const audio={metadata:{frames},chunk:async(start:number,count:number)=>{calls++;const b=new Uint8Array(count*4),v=new DataView(b.buffer);for(let i=0;i<count;i++){v.setInt16(i*4,(start+i)%30000,true);v.setInt16(i*4+2,-((start+i)%30000),true);}return b;}} as unknown as AudioStore;
 const transport:Transport={close:async()=>{},request:async kind=>{
  if(kind===6){state.running=false;state.fill=0;}if(kind===5)state.running=true;
  if(kind===2&&state.running){state.sampleCounter+=state.fill;state.fill=0;}
  const p=new Uint8Array(32),v=new DataView(p.buffer);v.setUint32(0,48000,true);v.setUint16(4,8192,true);v.setUint16(6,state.fill,true);v.setUint32(16,state.sampleCounter,true);v.setUint16(28,7,true);v.setUint16(30,+state.running,true);
  return {kind:kind|128,sequence:0,payload:p};
 },audioBatch:async chunks=>{
  expect(chunks).toHaveLength(32);
  for(const b of chunks){expect(b.length).toBe(1024);const v=new DataView(b.buffer,b.byteOffset,b.byteLength);for(let i=0;i<256;i++){expect(v.getInt16(i*4,true)).toBe((received%frames)%30000);expect(v.getInt16(i*4+2,true)).toBe(-((received%frames)%30000)||0);received++;}}
  state.fill=8192;batches++;if(batches===7)await stream.stop(transport);return {...state};
 }};
 let error:unknown;stream.onError=e=>error=e;await stream.play(transport,audio,()=>true);
 expect(error).toBeUndefined();expect(batches).toBe(7);expect(calls).toBe(1);expect(stream.playing).toBe(false);
});
