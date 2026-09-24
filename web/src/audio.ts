export interface Metadata {source_rate:number;source_channels:number;source_bits:number;frames:number;target_rate:number;duration:number}
export class AudioStore {
 private worker=new Worker(new URL('./audio-worker.ts',import.meta.url),{type:'module'});
 private sequence=0;
 private requests=new Map<number,{resolve:(v:any)=>void;reject:(e:Error)=>void}>();
 metadata?:Metadata;
 onProgress=(percent:number)=>{};
 constructor(){this.worker.onmessage=({data})=>{if(data.progress!==undefined){this.onProgress(data.progress);return;}const task=this.requests.get(data.id);this.requests.delete(data.id);if(data.error)task?.reject(new Error(data.error));else task?.resolve(data.result);};this.worker.onerror=()=>{for(const task of this.requests.values())task.reject(new Error('Audio worker failed; reload the page'));this.requests.clear();};}
 private request(kind:string,data:Record<string,unknown>,transfer:Transferable[]=[]):Promise<any>{return new Promise((resolve,reject)=>{const id=++this.sequence;this.requests.set(id,{resolve,reject});this.worker.postMessage({id,kind,...data},transfer);});}
 async load(bytes:ArrayBuffer):Promise<{metadata:Metadata;waveform:Float32Array}>{const r=await this.request('load',{bytes},[bytes]);this.metadata=r.metadata;return r;}
 async demo(seed:number,arrangement:'ambient'|'live'='ambient'):Promise<{metadata:Metadata;waveform:Float32Array;sample:{name:string;size:number;sha256:string}}>{const r=await this.request('demo',{seed,arrangement});this.metadata=r.metadata;return r;}
 chunk(start:number,count:number):Promise<Uint8Array>{return this.request('chunk',{start,count});}
 dispose(){this.worker.terminate();for(const task of this.requests.values())task.reject(new Error('Audio store closed'));this.requests.clear();}
}
// Local dry monitor only. No effect emulation, and never presented as FPGA playback.
export class Monitor {
 private context?:AudioContext;
 private sources=new Set<AudioBufferSourceNode>();
 private generation=0;
 private timer?:number;
 playing=false;
 position=0;
 consumedFrames=0;
 onend=()=>{};
 onerror=(error:unknown)=>{};
 async unlock(){this.context??=new AudioContext({sampleRate:48000});await this.context.resume();}
 async play(store:AudioStore,loop:()=>boolean,start=0){
  this.stop();const generation=this.generation;
  await this.unlock();
  if(generation!==this.generation)return;
  this.playing=true;this.consumedFrames=0;const ctx=this.context!;const frames=store.metadata!.frames;
  let cursor=Math.min(start,frames-1),nextTime=ctx.currentTime+0.06;
  const pump=async()=>{
   if(generation!==this.generation)return;
   try {
    while(nextTime<ctx.currentTime+0.8){
     if(cursor>=frames){if(loop())cursor=0;else {if(this.sources.size===0){this.playing=false;this.onend();return;}break;}}
     const count=Math.min(8192,frames-cursor);const pcm=await store.chunk(cursor,count);
     if(generation!==this.generation)return;
     const buffer=ctx.createBuffer(2,count,48000),view=new DataView(pcm.buffer,pcm.byteOffset,pcm.byteLength);
     for(let c=0;c<2;c++){const output=buffer.getChannelData(c);for(let i=0;i<count;i++)output[i]=view.getInt16(i*4+c*2,true)/32768;}
     const source=ctx.createBufferSource();source.buffer=buffer;source.connect(ctx.destination);this.sources.add(source);
     const chunkEnd=cursor+count;
     source.onended=()=>{this.sources.delete(source);if(generation===this.generation){this.position=chunkEnd;this.consumedFrames+=count;}source.disconnect();};
     nextTime=Math.max(nextTime,ctx.currentTime+0.015);source.start(nextTime);nextTime+=count/48000;cursor+=count;
    }
    this.timer=window.setTimeout(()=>void pump(),25);
   }catch(e){this.stop();this.onerror(e);}
  };await pump();
 }
 stop(){this.generation++;clearTimeout(this.timer);for(const s of this.sources){s.onended=null;s.stop();s.disconnect();}this.sources.clear();this.playing=false;}
}
