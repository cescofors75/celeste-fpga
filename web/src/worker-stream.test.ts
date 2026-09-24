import {it,expect,vi} from 'vitest';
import {Streamer} from './stream';
import type {AudioStore} from './audio';
import type {Transport,Status} from './transport';
const audio={metadata:{frames:48000*48},chunk:async()=>new Uint8Array(48000*48*4)} as unknown as AudioStore;
it('delegates the whole demo once and uses device progress, without UI-driven refills',async()=>{
 const s=new Streamer(),request=vi.fn(),end=vi.fn(),status=vi.fn();s.onEnd=end;s.onStatus=status;
 const device={sampleCounter:96000} as Status;
 const playBuffered=vi.fn(async(pcm,start,loop,notify)=>{expect(pcm.length).toBe(48000*48*4);expect(start).toBe(123);expect(loop).toBe(true);notify(device,96000);});
 await s.play({request,playBuffered,close:async()=>{}} as Transport,audio,()=>true,123);
 expect(request).not.toHaveBeenCalled();expect(playBuffered).toHaveBeenCalledOnce();expect(status).toHaveBeenCalledWith(device);expect(s.position).toBe(96000);expect(end).toHaveBeenCalledOnce();
});
it('STOP during PCM preparation prevents a late worker start',async()=>{
 const s=new Streamer();let ready!:(pcm:Uint8Array)=>void;
 const a={metadata:{frames:48000},chunk:()=>new Promise<Uint8Array>(resolve=>ready=resolve)} as unknown as AudioStore;
 const t={request:vi.fn(),playBuffered:vi.fn(),stopPlayback:vi.fn(async()=>{}),close:async()=>{}};
 const run=s.play(t,a,()=>true);await s.stop(t);ready(new Uint8Array(192000));await run;
 expect(t.playBuffered).not.toHaveBeenCalled();expect(t.stopPlayback).toHaveBeenCalledOnce();
});
it('surfaces worker stream faults and sends STOP',async()=>{
 const s=new Streamer(),error=vi.fn(),request=vi.fn(async()=>({kind:134,sequence:0,payload:new Uint8Array()}));s.onError=error;
 await s.play({request,close:async()=>{},playBuffered:async()=>{throw new Error('underrun');}},audio,()=>true);
 expect(s.playing).toBe(false);expect(error).toHaveBeenCalledOnce();expect(request).toHaveBeenCalledWith(6);
});
