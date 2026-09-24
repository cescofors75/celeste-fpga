// Snapshot v6 adds pre-mixer effect meters without changing legacy indices.
const mixed:Record<string,number>={sample:1,glitch:2,delay:3,filter:4,wavefolder:5,vca:6,delay2:14,mixer:7,out:7};
const raw:Record<string,number>={sample:0,glitch:8,delay:9,filter:10,wavefolder:11,vca:12,delay2:13,mixer:7,out:7};
export const nodeMeter=(id:string,detailed:boolean)=>detailed?raw[id]:id==='sample'?0:mixed[id];
export function wireMeter(from:string,to:string,detailed:boolean){
 if(from==='sample')return to==='mixer'?1:0;
 if(to==='delay2')return detailed?raw[from]:undefined;
 return mixed[from];
}
export function wireLevel(from:string,to:string,meters:number[]|undefined,bypass:boolean){
 if(!meters||bypass&&to==='mixer')return undefined;
 const index=wireMeter(from,to,meters.length>=15);
 return index===undefined?undefined:meters[index];
}
// Four PCM16 LSBs: visible low-level activity, not a claim of audible loudness.
export const signalActive=(value:number|undefined)=>(value??0)>=4/32768;
export const meterPercent=(value:number|undefined)=>value&&value>0?Math.max(0,Math.min(100,(20*Math.log10(value)+78)/78*100)):0;
