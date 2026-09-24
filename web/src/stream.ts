import type {AudioStore} from './audio';
import {parseStatus,type Status,type Transport} from './transport';
export const MAX_BUFFERED_FRAMES=64*1024*1024/4;
export class Streamer {
 playing=false;position=0;private generation=0;
 onStatus=(s:Status)=>{};onEnd=()=>{};onError=(e:unknown)=>{};
 async play(transport:Transport,audio:AudioStore,loop:()=>boolean,start=0){
  const generation=++this.generation;this.playing=true;
  try {
   if(transport.playBuffered&&audio.metadata!.frames<=MAX_BUFFERED_FRAMES){
    const pcm=await audio.chunk(0,audio.metadata!.frames);
    if(generation!==this.generation)return;
    await transport.playBuffered(pcm,start,loop(),(s,p)=>{if(generation===this.generation){this.position=p;this.onStatus(s);}});
    if(generation===this.generation){this.playing=false;this.onEnd();}return;
   }
   await transport.request(6);
   let status=parseStatus((await transport.request(2)).payload);
   if(status.sampleRate!==48000||!(status.capabilities&1)||status.capacity<512)throw new Error('Device does not advertise 48 kHz stereo streaming');
   const frames=audio.metadata!.frames,baseCounter=status.sampleCounter;
   const playbackPosition=()=>(start+((status.sampleCounter-baseCounter)>>>0))%frames;
   // Bound PCM cache to 64 MiB; includes the complete long live arrangement.
   // Preload before START so scene updates never compete with worker chunk requests.
   const cached=frames<=MAX_BUFFERED_FRAMES?await audio.chunk(0,frames):undefined;
   if(generation!==this.generation)return;
   const refill=Math.min(8192,Math.floor(status.capacity/4));
   let cursor=Math.min(start,frames-1),started=false,drained=false;
   const underruns=status.underruns,overruns=status.overruns,errors=status.protocolErrors;
   while(generation===this.generation){
    this.onStatus(status);
    if(status.underruns!==underruns||status.overruns!==overruns||status.protocolErrors!==errors)throw new Error(`Reproducción detenida: faltaron datos de audio (${status.underruns-underruns} frames); desbordamientos ${status.overruns-overruns}, errores de protocolo ${status.protocolErrors-errors}.`);
    if(drained&&started&&status.fill===0&&!status.running)break;
    let free=status.capacity-status.fill;
    // Amortize USB turnaround; never exceed the last device credit.
    if(!drained&&(!started||free>=refill||(!loop()&&frames-cursor<status.capacity/2))){
     const chunks:Uint8Array[]=[],repeat=loop();
     const wanted=Math.min(free,16384,repeat?16384:frames-cursor),window=new Uint8Array(wanted*4);
     let prepared=0;
     while(prepared<wanted){
      if(cursor>=frames)cursor=0;
      const count=Math.min(wanted-prepared,frames-cursor);
      window.set(cached?cached.subarray(cursor*4,(cursor+count)*4):await audio.chunk(cursor,count),prepared*4);
      cursor+=count;prepared+=count;
      if(generation!==this.generation)return;
     }
     for(let offset=0;offset<window.length;offset+=1024)chunks.push(window.subarray(offset,offset+1024));
     if(chunks.length){
      if(transport.audioBatch)status=await transport.audioBatch(chunks);
      else for(const bytes of chunks)await transport.request(4,bytes);
     }
     if(generation!==this.generation)return;
     if(cursor>=frames&&!loop()){await transport.request(7);drained=true;}
     if(!started){
      // Fill the advertised hardware reservoir before START, including SDRAM.
      if(!drained&&status.fill<status.capacity&&transport.audioBatch)continue;
      if(generation!==this.generation)return;await transport.request(5);started=true;
     }
     if(started&&!drained&&transport.audioBatch){this.position=playbackPosition();continue;}
    } else if(!transport.audioBatch)await new Promise(resolve=>setTimeout(resolve,Math.max(5,(status.fill-(status.capacity-refill))/48-20)));
    // Serial ACKs pace the real transport. Browser timers can be throttled well
    // beyond the 171 ms hardware FIFO when the tab is in the background.
    if(generation!==this.generation)return;
    status=parseStatus((await transport.request(2)).payload);
    this.position=playbackPosition();
   }
   if(generation===this.generation){await transport.request(6);this.playing=false;this.onEnd();}
  }catch(e){if(generation===this.generation){this.playing=false;await transport.request(6).catch(()=>{});this.onError(e);}}
 }
 async stop(transport?:Transport){this.generation++;this.playing=false;if(transport?.stopPlayback)await transport.stopPlayback();else if(transport)await transport.request(6);}
}
