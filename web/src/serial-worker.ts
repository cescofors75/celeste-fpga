/// <reference lib="webworker" />
import init from './wasm/celeste_wasm';
import {SerialTransport,type Packet,type Status} from './transport';
import {Streamer} from './stream';
import type {AudioStore} from './audio';
const ready=init(),transport=new SerialTransport(),stream=new Streamer();
let looping=true,lastUpdate=0,playId=0,playFailure:unknown,startIntent=0,linked=false,lineInput=false;
const sideband:{id:number;kind:number;payload:Uint8Array;receive:(p:Packet)=>void}[]=[];
const controlIds=new Set<number>();
transport.batchControls=()=>sideband.splice(0,3);
function cancelSideband(){sideband.length=0;for(const id of controlIds)self.postMessage({id,error:'Playback stopped before control was acknowledged'});controlIds.clear();}
transport.onDisconnect=()=>{linked=false;cancelSideband();void stream.stop();self.postMessage({event:'disconnect'});};
stream.onStatus=status=>{if(performance.now()-lastUpdate>100){lastUpdate=performance.now();self.postMessage({event:'status',playId,status,position:stream.position,diagnostics:transport.diagnostics.slice(-4)});}};
stream.onError=e=>{playFailure=e;};
self.onmessage=async({data})=>{
 const {id,kind}=data;
 try{
  await ready;let result:unknown;
  if(kind==='connectStreams'){
   result=await transport.connect(data.baudRate,{
    readable:data.readable,writable:data.writable,
    open:async()=>{},close:async()=>{}
   });linked=true;lineInput=!!((result as Status).capabilities&8192);
  }else if(kind==='connect'){
   const serial=(navigator as unknown as {serial:Serial}).serial;
   if(!serial)throw new Error('Este navegador no permite Web Serial en un worker. Usa Chrome o Edge actualizado.');
   const ports=(await serial.getPorts()).filter(p=>{const info=p.getInfo();return info.usbVendorId===data.info.usbVendorId&&info.usbProductId===data.info.usbProductId;});
   if(ports.length!==1)throw new Error('No se puede identificar una única placa autorizada. Desconecta otras placas iguales y vuelve a conectar.');
   result=await transport.connect(data.baudRate,ports[0]);linked=true;lineInput=!!((result as Status).capabilities&8192);
  }else if(kind==='request'){
   if(stream.playing&&(data.command===3||data.command===9)){
    controlIds.add(id);sideband.push({id,kind:data.command,payload:data.payload,receive:packet=>{controlIds.delete(id);self.postMessage({id,result:packet});}});return;
   }
   result=await transport.request(data.command,data.payload);
  }
  else if(kind==='batch')result=await transport.audioBatch(data.payloads);
  else if(kind==='loop')looping=data.loop;
  else if(kind==='stop'){startIntent++;cancelSideband();await stream.stop(linked?transport:undefined);}
  else if(kind==='close'){startIntent++;cancelSideband();try{await stream.stop(linked&&!lineInput?transport:undefined);}finally{await transport.close();linked=false;lineInput=false;}}
  else if(kind==='play'){
   const intent=++startIntent;await stream.stop(transport);
   if(intent!==startIntent){self.postMessage({id});return;}
   playId=id;looping=data.loop;playFailure=undefined;lastUpdate=0;
   const pcm:Uint8Array=data.pcm;
   const store={metadata:{frames:pcm.length/4},chunk:async(start:number,count:number)=>pcm.subarray(start*4,(start+count)*4)} as unknown as AudioStore;
   await stream.play(transport,store,()=>looping,data.start);
   cancelSideband();
   if(playFailure)throw playFailure;
  }else throw new Error('Unknown serial worker command');
  self.postMessage({id,result});
 }catch(e){self.postMessage({id,error:String(e),diagnostics:transport.diagnostics});}
};
