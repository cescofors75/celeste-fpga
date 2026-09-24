import {encode_packet,validate_packet} from './wasm/celeste_wasm';
export interface Packet {kind:number;sequence:number;payload:Uint8Array}
export interface Status {sampleRate:number;capacity:number;fill:number;underruns:number;overruns:number;sampleCounter:number;protocolErrors:number;engineMask:number;routeMask:number;capabilities:number;running:boolean}
export interface Transport {request(kind:number,payload?:Uint8Array):Promise<Packet>;audioBatch?(payloads:Uint8Array[]):Promise<Status>;close():Promise<void>;playBuffered?(pcm:Uint8Array,start:number,loop:boolean,onStatus:(s:Status,position:number)=>void):Promise<void>;stopPlayback?():Promise<void>;setLoop?(loop:boolean):void}
export function parseStatus(p:Uint8Array):Status{
 if(p.length!==32&&p.length!==40)throw new Error('Unsupported status payload');const v=new DataView(p.buffer,p.byteOffset,p.byteLength);
 const wide=!!(v.getUint16(28,true)&4096);if(wide!==(p.length===40))throw new Error('Inconsistent FIFO status width');
 return {sampleRate:v.getUint32(0,true),capacity:wide?v.getUint32(32,true):v.getUint16(4,true),fill:wide?v.getUint32(36,true):v.getUint16(6,true),underruns:v.getUint32(8,true),overruns:v.getUint32(12,true),sampleCounter:v.getUint32(16,true),protocolErrors:v.getUint32(20,true),engineMask:v.getUint16(24,true),routeMask:v.getUint16(26,true),capabilities:v.getUint16(28,true),running:!!v.getUint16(30,true)};
}
export class PacketFramer {
 private buffer=new Uint8Array(0);
 errors=0;
 push(bytes:Uint8Array):Packet[]{
  const joined=new Uint8Array(this.buffer.length+bytes.length);joined.set(this.buffer);joined.set(bytes,this.buffer.length);this.buffer=joined;
  const packets:Packet[]=[];
  while(this.buffer.length>=12){
   if(this.buffer[0]!==0x43||this.buffer[1]!==0x45||this.buffer[2]!==1){this.buffer=this.buffer.slice(1);this.errors++;continue;}
   const view=new DataView(this.buffer.buffer,this.buffer.byteOffset,this.buffer.byteLength),len=view.getUint16(8,true);
   if(len>1024){this.buffer=this.buffer.slice(1);this.errors++;continue;}
   if(this.buffer.length<len+12)break;
   const frame=this.buffer.slice(0,len+12);
   try{validate_packet(frame);packets.push({kind:frame[3],sequence:view.getUint32(4,true),payload:frame.slice(10,-2)});this.buffer=this.buffer.slice(len+12);}
   catch{this.buffer=this.buffer.slice(1);this.errors++;}
  }return packets;
 }
}
export type SerialConnection=Pick<SerialPort,'open'|'close'|'readable'|'writable'>;
export class SerialTransport implements Transport {
 diagnostics:{ms:number;encodeMs:number;writeMs:number;ackMs:number;frames:number;fill:number;under:number}[]=[];
 private port?:SerialConnection;private reader?:ReadableStreamDefaultReader<Uint8Array>;private writer?:WritableStreamDefaultWriter<Uint8Array>;
 private sequence=0;private framer=new PacketFramer();private loop?:Promise<void>;private queue=Promise.resolve();
 private pending=new Map<number,{resolve:(p:Packet)=>void;reject:(e:Error)=>void;timer:ReturnType<typeof setTimeout>}>();
 onDisconnect=()=>{};
 onProgress=(_message:string)=>{};
 batchControls=():{kind:number;payload:Uint8Array;receive:(p:Packet)=>void}[]=>[];
 async connect(baudRate:number,selectedPort?:SerialConnection){
  if(this.port)await this.close();
  if(!('serial' in navigator))throw new Error('Web Serial requires a supported Chromium browser on localhost or HTTPS');
  this.onProgress('Selecciona COM14 y pulsa Conectar en el selector. «Vinculado» solo indica permiso.');
  this.port=selectedPort??await navigator.serial.requestPort();
  this.onProgress(`Abriendo puerto a ${baudRate.toLocaleString()} baudios…`);
  try{await this.port.open({baudRate,bufferSize:131072});this.framer=new PacketFramer();this.reader=this.port.readable!.getReader();this.writer=this.port.writable!.getWriter();this.loop=this.read();
   this.onProgress('Puerto abierto. Esperando respuesta CELESTE de la FPGA…');
   const ping=await this.request(1);if(new TextDecoder().decode(ping.payload)!=='CELESTE/1')throw new Error('Device is not CELESTE protocol v1');
   return parseStatus((await this.request(2)).payload);
  }catch(e){await this.close();const message=e instanceof Error?e.message:String(e);throw new Error(message.includes('timeout')?'COM14 abierto, pero la FPGA no responde. Comprueba COM14, 3 000 000 baudios y el firmware CELESTE cargado.':`No se pudo conectar: ${message}. Si el puerto está ocupado, desconéctalo en las otras pestañas o aplicaciones.`);}
 }
 private async read(){try{while(this.reader){const {value,done}=await this.reader.read();if(done)break;for(const p of this.framer.push(value)){const pending=this.pending.get(p.sequence);if(pending){clearTimeout(pending.timer);this.pending.delete(p.sequence);if(p.kind===0xff)pending.reject(new Error(`FPGA rejected command (${p.payload[0]})`));else pending.resolve(p);}}}}
 catch(e){this.fail(e);}finally{this.fail(new Error('Serial connection closed'));this.onDisconnect();}}
 private fail(e:unknown){for(const p of this.pending.values()){clearTimeout(p.timer);p.reject(e instanceof Error?e:new Error(String(e)));}this.pending.clear();}
 request(kind:number,payload=new Uint8Array()):Promise<Packet>{
  const operation=this.queue.then(async()=>{
   if(!this.writer)throw new Error('Not connected');const sequence=this.sequence++>>>0;
   const response=new Promise<Packet>((resolve,reject)=>{const timer=setTimeout(()=>{this.pending.delete(sequence);reject(new Error('FPGA response timeout'));},3500);this.pending.set(sequence,{resolve,reject,timer});});
   // Attach a rejection handler before the potentially slow write.
   const outcome=response.then(p=>({p}),e=>({e}));
   try{await this.writer.write(encode_packet(kind,sequence,payload));}catch(e){this.fail(e);}
   const result=await outcome;if('e'in result)throw result.e;
   if(result.p.kind!==(kind|0x80))throw new Error('Unexpected FPGA response');return result.p;
  });this.queue=operation.then(()=>{},()=>{});return operation;
 }
 audioBatch(payloads:Uint8Array[]):Promise<Status>{
  // A depleted SDRAM reservoir needs a larger recovery burst, already queued
  // in the OS while the worker waits for ACKs. Honor the caller's FIFO credit.
  if(payloads.length>64){
   return (async()=>{let status:Status|undefined;for(let i=0;i<payloads.length;i+=64)status=await this.audioBatch(payloads.slice(i,i+64));return status!;})();
  }
  const operation=this.queue.then(async()=>{
   if(!this.writer)throw new Error('Not connected');
   const began=performance.now();
   if(payloads.length<1||payloads.length>64)throw new Error('Invalid audio window');
   const outcomes:Promise<{p?:Packet;e?:unknown}>[]=[];
   const sideband=this.batchControls();
   const commands=[...sideband.filter(c=>c.kind===3),...payloads.map(payload=>({kind:4,payload,receive:(_p:Packet)=>{}})),...sideband.filter(c=>c.kind!==3),{kind:2,payload:new Uint8Array(),receive:(_p:Packet)=>{}}];
   const frames=commands.map(({kind,payload})=>{
    const sequence=this.sequence++>>>0;
    const response=new Promise<Packet>((resolve,reject)=>{const timer=setTimeout(()=>{this.pending.delete(sequence);reject(new Error('Audio window ACK timeout'));},3500);this.pending.set(sequence,{resolve,reject,timer});});
    outcomes.push(response.then(p=>({p}),e=>({e})));
    return encode_packet(kind,sequence,payload);
   });
   const bytes=new Uint8Array(frames.reduce((sum,f)=>sum+f.length,0));let offset=0;
   for(const frame of frames){bytes.set(frame,offset);offset+=frame.length;}
   const encoded=performance.now();
   try{await this.writer.write(bytes);}catch(e){this.fail(e);}
   const written=performance.now();
   const results=await Promise.all(outcomes);
   results.forEach((result,i)=>{if(result.e)throw result.e;if(result.p?.kind!==(commands[i].kind|128))throw new Error('Invalid stream acknowledgement');commands[i].receive(result.p);});
   const status=parseStatus(results.at(-1)!.p!.payload);
   this.diagnostics.push({ms:Math.round(performance.now()-began),encodeMs:Math.round(encoded-began),writeMs:Math.round(written-encoded),ackMs:Math.round(performance.now()-written),frames:payloads.reduce((sum,p)=>sum+p.length/4,0),fill:status.fill,under:status.underruns});if(this.diagnostics.length>16)this.diagnostics.shift();
   return status;
  });this.queue=operation.then(()=>{},()=>{});return operation;
 }
 async close(){
  this.fail(new Error('Disconnected'));
  if(this.reader){await this.reader.cancel().catch(()=>{});await this.loop;this.reader.releaseLock();this.reader=undefined;}
  if(this.writer){await this.writer.close().catch(()=>{});this.writer.releaseLock();this.writer=undefined;}
  if(this.port){await this.port.close().catch(()=>{});this.port=undefined;}
 }
}
