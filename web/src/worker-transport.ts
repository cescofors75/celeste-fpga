import type {Packet,Status,Transport} from './transport';
/** The worker owns protocol/PCM scheduling; ambiguous ports use transferred IO. */
export class SerialTransport implements Transport{
 diagnostics:unknown;
 private worker=new Worker(new URL('./serial-worker.ts',import.meta.url),{type:'module'});
 private next=0;private pending=new Map<number,{resolve:(v:any)=>void;reject:(e:Error)=>void}>();
 private statusListener?:(s:Status,position:number)=>void;private activePlay=0;private pumping=false;
 private ownedPort?:SerialPort;
 private releasing?:Promise<void>;
 onDisconnect=()=>{};onProgress=(_message:string)=>{};
 batchControls=():{kind:number;payload:Uint8Array;receive:(p:Packet)=>void}[]=>[];
 constructor(){
  this.worker.onmessage=({data})=>{
   if(data.event==='disconnect'){void this.releasePort().catch(e=>this.onProgress(String(e)));this.onDisconnect();return;}
   if(data.event==='status'){
    this.diagnostics=data.diagnostics;
    if(data.playId===this.activePlay){this.statusListener?.(data.status,data.position);void this.pumpControls();}return;
   }
   if(data.diagnostics)this.diagnostics=data.diagnostics;
   const p=this.pending.get(data.id);this.pending.delete(data.id);if(data.error)p?.reject(new Error(data.error));else p?.resolve(data.result);
  };
  this.worker.onerror=()=>{for(const p of this.pending.values())p.reject(new Error('Serial worker failed'));this.pending.clear();this.onDisconnect();};
 }
 private call(kind:string,data:Record<string,unknown>={},transfer:Transferable[]=[]):Promise<any>{const id=++this.next;return new Promise((resolve,reject)=>{this.pending.set(id,{resolve,reject});try{this.worker.postMessage({id,kind,...data},transfer);}catch(e){this.pending.delete(id);reject(e);}});}
 async connect(baudRate:number):Promise<Status>{
  this.diagnostics=undefined;
  if(!('serial' in navigator))throw new Error('Web Serial requiere Chrome o Edge en localhost.');
  const authorized=await navigator.serial.getPorts();
  this.onProgress(authorized.length===1?'Reconectando la placa autorizada…':'Selecciona COM14 y pulsa Conectar en el selector. «Vinculado» solo indica permiso.');
  const port=authorized.length===1?authorized[0]:await navigator.serial.requestPort();
  this.onProgress('Abriendo COM14 en el hilo de audio independiente…');
  const info=port.getInfo();
  const matches=(await navigator.serial.getPorts()).filter(p=>{const other=p.getInfo();return other.usbVendorId===info.usbVendorId&&other.usbProductId===info.usbProductId;});
  if(matches.length===1)return this.call('connect',{baudRate,info});
  // USB IDs identify a model, not a port. Never guess an enumeration index or
  // probe another authorized device. Transfer the selected port's IO streams.
  this.onProgress('Abriendo el puerto seleccionado y verificando CELESTE…');
  try{
   await port.open({baudRate,bufferSize:131072});this.ownedPort=port;
   const readable=port.readable,writable=port.writable;
   if(!readable||!writable)throw new Error('El puerto seleccionado no ofrece lectura y escritura.');
   return await this.call('connectStreams',{baudRate,readable,writable},[readable,writable]);
  }catch(e){await this.releasePort();throw e;}
 }
 request(command:number,payload:Uint8Array=new Uint8Array()):Promise<Packet>{return this.call('request',{command,payload});}
 async audioBatch(payloads:Uint8Array[]):Promise<Status>{await this.pumpControls();return this.call('batch',{payloads});}
 private async pumpControls(){if(this.pumping)return;this.pumping=true;try{await Promise.all(this.batchControls().map(async c=>c.receive(await this.request(c.kind,c.payload))));}catch{ /* Stream/poll reports connection faults. */ }finally{this.pumping=false;}}
 async playBuffered(pcm:Uint8Array,start:number,loop:boolean,onStatus:(s:Status,p:number)=>void){
  this.statusListener=onStatus;const id=this.activePlay=this.next+1;
  try{await this.call('play',{pcm,start,loop},[pcm.buffer as ArrayBuffer]);}finally{if(this.activePlay===id)this.statusListener=undefined;}
 }
 async stopPlayback(){await this.call('stop');}
 setLoop(loop:boolean){void this.call('loop',{loop});}
 private releasePort():Promise<void>{
  if(this.releasing)return this.releasing;
  const port=this.ownedPort;if(!port)return Promise.resolve();
  this.releasing=(async()=>{
   // Stream cancellation/closure crosses a MessagePort after the worker reply.
   const deadline=performance.now()+1500;
   while((port.readable?.locked||port.writable?.locked)&&performance.now()<deadline)await new Promise(resolve=>setTimeout(resolve,10));
   await port.close();if(this.ownedPort===port)this.ownedPort=undefined;
  })().finally(()=>{this.releasing=undefined;});
  return this.releasing;
 }
 async close(){try{await this.call('close');}finally{await this.releasePort();}}
}
