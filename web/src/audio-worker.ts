/// <reference lib="webworker" />
import init,{PreparedAudio} from './wasm/celeste_wasm';
import {ambientWav} from './ambient';
import {liveMusicWav} from './live-music';
let audio:PreparedAudio|undefined;
const ready=init();
self.onmessage=async(event:MessageEvent)=>{
 const {id,kind,bytes,start,count,seed,arrangement}=event.data;
 try {
  await ready;
  if(kind==='demo'){
   const wav=arrangement==='live'?liveMusicWav(seed,progress=>self.postMessage({id,progress})):ambientWav(seed);
   const hash=Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',wav)),v=>v.toString(16).padStart(2,'0')).join('');
   const next=new PreparedAudio(new Uint8Array(wav));
   audio?.free();audio=next;
   self.postMessage({id,result:{metadata:JSON.parse(audio.metadata()),waveform:audio.waveform(180),sample:{name:`CELESTE ${arrangement==='live'?'Parallel Tides · 168 BPM':'ambient'} · ${(seed>>>0).toString(16).padStart(8,'0')}.wav`,size:wav.byteLength,sha256:hash}}});
  } else if(kind==='load'){
   const next=new PreparedAudio(new Uint8Array(bytes));
   audio?.free(); audio=next;
   self.postMessage({id,result:{metadata:JSON.parse(audio.metadata()),waveform:audio.waveform(180)}});
  } else if(kind==='chunk'){
   if(!audio)throw new Error('No sample loaded');
   const result=audio.chunk(start,count);self.postMessage({id,result},[result.buffer]);
  }
 }catch(error){self.postMessage({id,error:String(error)});}
};
