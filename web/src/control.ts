import {expandedBranches,expandedParameters,expansionMask,performanceMasks,requiresExpansion} from './expansion';
import type {Transport} from './transport';
import {bankMapping,type Patch} from './model';
// Bypass-capable laboratory firmware also implements command 9 snapshots.
export const supportsControlSnapshots=(capabilities:number)=>!!(capabilities&(2|16));
export const parameterIds=['glitch.amount','glitch.probability','delay.time','delay.feedback','filter.cutoff','filter.resonance','mixer.dry','mixer.glitch','mixer.delay','mixer.filter','mixer.master','lfo.rate','lfo.depth','wavefolder.drive','vca.level','chaos.amount','mixer.wavefolder','mixer.vca'];
export const extraParameters:Record<number,string>={24:'delay2.time',25:'delay2.feedback',26:'mixer.delay2'};
export const sonicParameters:Record<number,string>={23:'glitch.mode',28:'filter.mode',29:'glitch.size',30:'glitch.repeats',31:'chaos.rate'};
export const hardwareParameters:Record<number,string>={...Object.fromEntries(parameterIds.map((key,id)=>[id,key])),...extraParameters,...sonicParameters,...expandedParameters};
export const bypassNodes=['glitch','delay','filter','wavefolder','vca','delay2','lfo','chaos'];
export interface Controls {values:number[];mappings:number[];routes:number;online:boolean;selected:number;revision:number;bank:number;meters?:number[]}
export function decodeControls(bytes:Uint8Array):Controls{
 if(bytes.length!==48&&bytes.length!==64&&bytes.length!==80&&bytes.length!==96&&bytes.length!==110)throw new Error('Unsupported control snapshot');const v=new DataView(bytes.buffer,bytes.byteOffset,bytes.byteLength),n=bytes.length>=96?32:bytes.length>=64?24:16,o=n*2;
 return {values:Array.from({length:n},(_,i)=>v.getUint16(i*2,true)/65535),mappings:Array.from(bytes.slice(o,o+8)),routes:bytes[o+8],online:!!(bytes[o+9]&1),selected:(bytes[o+9]>>1)&7,bank:(bytes[o+9]>>4)&1,revision:v.getUint32(o+10,true),...(bytes.length>=80?{meters:Array.from({length:bytes.length===110?15:8},(_,i)=>v.getUint16(o+16+i*2,true)/32768)}:{})};
}
export function routeMask(patch:Patch,extended=true,dual=false,expanded=false){
 const branches=extended?['glitch','delay','filter','wavefolder','vca']:['glitch','delay','filter'];
 const allowed=new Set([...(dual?['sample,delay2','delay,delay2','delay2,mixer']:[]),'sample,mixer','mixer,out',...(expanded?expandedBranches.flatMap(b=>[`sample,${b}`,`${b},mixer`]):[]),...branches.flatMap(b=>[`sample,${b}`,`${b},mixer`])]);
 if(patch.routes.some(r=>!allowed.has(r.join(','))))throw new Error(dual?'Ruta no disponible. La cascada admitida es Delay → Delay 2; los demás efectos reciben Sample In.':'Use parallel routes: Sample -> effect -> Mixer -> Audio Out. Serial effect chains are not supported by this firmware.');
 if(patch.modulation.some(([a,b])=>!(['lfo',...(extended?['chaos']:[]),...(expanded?['envelope']:[])].includes(a))||!['filter.cutoff',...(extended?['vca.level']:[])].includes(b)||(a==='envelope'&&b!=='filter.cutoff')))throw new Error('Modulacion: LFO / Chaos → Filter o VCA; Envelope → Filter cutoff.');
 const has=(a:string,b:string)=>patch.routes.some(r=>r[0]===a&&r[1]===b);
 if(!has('mixer','out'))return 0;
 return (has('sample','mixer')?1:0)|branches.reduce((mask,b,i)=>mask|(has('sample',b)&&has(b,'mixer')?1<<(i+1):0),0);
}
export function delay2Config(patch:Patch){
 const has=(a:string,b:string)=>patch.routes.some(r=>r[0]===a&&r[1]===b);
 if(!has('mixer','out')||!has('delay2','mixer'))return 0;
 if(has('sample','delay2')&&has('delay','delay2'))throw new Error('Delay 2 acepta una sola entrada.');
 return has('sample','delay2')?1:has('sample','delay')&&has('delay','delay2')?3:0;
}
export class ControlLink{
 expandedEncoders=false;expanded=false;onExpansion=(values:number[],levels?:number[])=>{};
 extended=false;banked=false;dual=false;sonic=false;
 pending=new Map<number,number>();private known=new Map<number,number>();private busy=false;private lastRead=0;
 onSnapshot=(snapshot:Controls)=>{};onError=(e:unknown)=>{};
 reset(){this.pending.clear();this.known.clear();this.lastRead=0;}
 private accept(snapshot:Controls){
  snapshot.values.forEach((v,i)=>{if(!this.pending.has(i))this.known.set(i,Math.round(v*65535));});
  snapshot.mappings.forEach((v,i)=>{const id=40+snapshot.bank*8+i;if(!this.pending.has(id))this.known.set(id,v);});this.known.set(32,snapshot.routes);this.onSnapshot(snapshot);
 }
 batch(){
  const commands:{kind:number;payload:Uint8Array;receive:(p:{payload:Uint8Array})=>void}[]=[];
  for(const [id,value]of Array.from(this.pending).slice(0,2)){
   this.pending.delete(id);const payload=new Uint8Array(4),view=new DataView(payload.buffer);view.setUint16(0,id,true);view.setUint16(2,value,true);
   commands.push({kind:3,payload,receive:()=>{this.known.set(id,value);}});
  }
  if(performance.now()-this.lastRead>150){this.lastRead=performance.now();commands.push({kind:9,payload:new Uint8Array(),receive:p=>this.accept(decodeControls(p.payload))});}
  if(this.expanded&&commands.some(c=>c.kind===9))commands.push({kind:11,payload:new Uint8Array(),receive:p=>{const v=new DataView(p.payload.buffer,p.payload.byteOffset,p.payload.byteLength);this.onExpansion(Array.from({length:32},(_,i)=>v.getUint16(i*2,true)),Array.from(p.payload.slice(64,72)));}});
  return commands;
 }
 queue(patch:Patch){
  const mask=routeMask(patch,this.extended,this.dual,this.expanded);
  if(!this.expanded&&requiresExpansion(patch))throw new Error('Estos componentes / Mute / Solo requieren firmware ampliado.');
  const writes=new Map<number,number>();
  if(this.expanded){for(const [id,key]of Object.entries(expandedParameters))writes.set(Number(id),Math.round((patch.parameters[key]??0)*65535));writes.set(64,expansionMask(patch));writes.set(65,[...expandedBranches,'envelope'].reduce((m,id,i)=>m|(patch.bypass?.[id]?1<<i:0),0));const masks=performanceMasks(patch);writes.set(88,masks.mute);writes.set(89,masks.solo);}
  parameterIds.slice(0,this.extended?18:13).forEach((key,id)=>writes.set(id,Math.round(((key==='lfo.depth'&&!patch.modulation.some(r=>r[0]==='lfo'))||(key==='chaos.amount'&&!patch.modulation.some(r=>r[0]==='chaos'))?0:patch.parameters[key]??0)*65535)));
  for(let bank=0;bank<(this.banked?2:1);bank++)for(let i=0;i<8;i++){const key=bankMapping(patch,bank)[`encoder${i+1}`],id=Number(Object.entries(hardwareParameters).find(([,value])=>value===key)?.[0]??-1);if(id<0||(!this.extended&&id>=13)||(!this.dual&&id>=23&&id<64)||(!this.expandedEncoders&&id>=64)||(!this.sonic&&id in sonicParameters))throw new Error(`Encoder ${i+1}: parameter is not supported by this FPGA`);writes.set(40+bank*8+i,id);}
  if(this.extended)for(const [id,source] of [[18,'lfo'],[19,'chaos']] as const)writes.set(id,(patch.modulation.some(r=>r[0]===source&&r[1]==='filter.cutoff')?1:0)|(patch.modulation.some(r=>r[0]===source&&r[1]==='vca.level')?2:0));
  if(!this.dual&&(Object.values(patch.bypass??{}).some(Boolean)||patch.routes.some(r=>r.includes('delay2'))))throw new Error('Bypass por componente y Delay 2 requieren el nuevo firmware.');
  if(this.dual){
   writes.set(22,bypassNodes.reduce((bits,id,i)=>bits|(patch.bypass?.[id]?1<<i:0),0));
   for(const [id,key]of Object.entries(extraParameters))writes.set(Number(id),Math.round((patch.parameters[key]??0)*65535));
   writes.set(27,delay2Config(patch));
  }
  if(this.sonic)for(const [id,key]of Object.entries(sonicParameters))writes.set(Number(id),Math.round((patch.parameters[key]??0)*65535));
  writes.set(32,mask);
  for(const [id,value]of writes)if(this.known.get(id)!==value)this.pending.set(id,value);
 }
 async service(transport:Transport,all=false){
  if(this.busy)return;this.busy=true;
  try{
   for(let count=0;this.pending.size&&(all||count<1);count++){
    const [id,value]=this.pending.entries().next().value!;this.pending.delete(id);
    const p=new Uint8Array(4),v=new DataView(p.buffer);v.setUint16(0,id,true);v.setUint16(2,value,true);
    await transport.request(3,p);this.known.set(id,value);
   }
   if(!this.pending.size&&(all||performance.now()-this.lastRead>180)){
    const snapshot=decodeControls((await transport.request(9)).payload);this.lastRead=performance.now();
    this.accept(snapshot);
    if(this.expanded){const bytes=(await transport.request(11)).payload;const v=new DataView(bytes.buffer,bytes.byteOffset,bytes.byteLength);const values=Array.from({length:32},(_,i)=>v.getUint16(i*2,true));values.forEach((x,i)=>{if(!this.pending.has(64+i))this.known.set(64+i,x);});this.onExpansion(values,Array.from(bytes.slice(64,72)));}
   }
  }catch(e){this.onError(e);if(all)throw e;}finally{this.busy=false;}
 }
}
