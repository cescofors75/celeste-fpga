import {expansionDefaults} from './expansion';
import palette from '../../shared/palette.json';
import initial from '../../patches/parallel-dreams.json';
export interface Patch {mute?:Record<string,boolean>;solo?:Record<string,boolean>;bypass?:Record<string,boolean>;nodes?:Record<string,[number,number]>;format:string;version:number;name:string;routes:[string,string][];parameters:Record<string,number>;hardware:Record<string,string>;hardwareBank1?:Record<string,string>;modulation:[string,string][];touch:Record<string,string>}
export const defaultBank1=():Record<string,string>=>Object.fromEntries(['wavefolder.drive','mixer.wavefolder','vca.level','mixer.vca','lfo.rate','lfo.depth','chaos.amount','mixer.master'].map((p,i)=>[`encoder${i+1}`,p]));
export const recommendedEncoderKeys=[
 ['glitch.amount','delay.time','delay2.time','filter.cutoff','wavefolder.drive','vca.level','lfo.depth','chaos.amount'],
 ['chorus.depth','flanger.depth','crusher.bits','freeze.hold','tremolo.depth','autopan.depth','envelope.depth','mixer.master']
];
export function recommendEncoderBanks(p:Patch){[p.hardware,p.hardwareBank1]=recommendedEncoderKeys.map(keys=>Object.fromEntries(keys.map((key,i)=>[`encoder${i+1}`,key])));return p;}
export function migrateEncoderBanks(p:Patch){if(Object.entries(initial.hardware).every(([k,v])=>p.hardware[k]===v)&&(!p.hardwareBank1||Object.entries(defaultBank1()).every(([k,v])=>p.hardwareBank1?.[k]===v)))recommendEncoderBanks(p);return p;}
export const bankMapping=(patch:Patch,bank:number)=>bank===1?(patch.hardwareBank1??=defaultBank1()):patch.hardware;
export interface SampleRef {name:string;size:number;sha256:string}
export interface Session {format:string;version:number;sample:SampleRef|null;patch:Patch;position:number;looping:boolean;tempo:number|null}
export const sonicDefaults={'glitch.mode':1,'glitch.size':1,'glitch.repeats':.2,'filter.mode':0,'chaos.rate':.15};
export const defaultPatch=():Patch=>({...structuredClone(initial),parameters:{...initial.parameters,'delay2.time':.5,'delay2.feedback':.25,'mixer.delay2':.5,...sonicDefaults,...expansionDefaults},routes:initial.routes.map(([a,b])=>[a,b])});
export const normalize=(value:number)=>Number.isFinite(value)?Math.min(1,Math.max(0,value)):0;
export const colors:Record<string,string>=palette.colors;
export function parameterColor(parameter:string):string {
 const [module,key]=parameter.split('.');
 return colors[module==='mixer'&&colors[key]?key:module]??colors.mixer;
}
export const names:Record<string,string>={chorus:'Chorus',flanger:'Flanger',crusher:'Bitcrusher',freeze:'Freeze',tremolo:'Tremolo',autopan:'Auto-pan',envelope:'Envelope',sample:'Sample In',glitch:'Glitch',delay:'Delay',delay2:'Delay 2',filter:'Filter',wavefolder:'Wavefolder',vca:'VCA',mixer:'Mixer',out:'Audio Out',lfo:'LFO',chaos:'Chaos'};
export function valueLabel(key:string,v:number):string {
 if(key==='crusher.bits')return `${16-(Math.round(v*65535)>>>12)} bits`;
 if(key==='crusher.rate')return `${(48000/(1+(Math.round(v*65535)>>>8))).toFixed(0)} Hz`;
 if(key==='freeze.hold')return v>=.5?'HOLD':'CAPTURE';
 if(['chorus.rate','flanger.rate','tremolo.rate','autopan.rate'].includes(key))return `${((4474+Math.round(v*65535)*16)*48000/4294967296).toFixed(2)} Hz`;
 if(key==='filter.mode')return ['LPF · Paso bajo','HPF · Paso alto','BPF · Paso banda','Notch'][Math.min(3,Math.round(v*65535)>>>14)];
 if(key==='glitch.mode')return v>=32768/65535?'Stutter':'Textura';
 if(key==='glitch.size')return `${((256<<Math.min(3,Math.round(v*65535)>>>14))/48).toFixed(1)} ms`;
 if(key==='glitch.repeats')return `${1+(Math.round(v*65535)>>>12)} rep.`;
 if(key==='delay.feedback'||key==='delay2.feedback')return `${Math.round(v*50)}%`;
 if(key==='delay2.time')return `${((1+Math.floor(v*65535/16))/48).toFixed(1)} ms`;
 if(key==='delay.time')return `${( (1+Math.floor(v*65535/8))/48 ).toFixed(1)} ms`;
 if(key==='filter.cutoff')return `${(48000*Math.asin((86+Math.floor(v*65535/4))/65536)/Math.PI/1000).toFixed(2)} kHz`;
 if(key==='lfo.rate'||key==='chaos.rate')return `${((4474+Math.round(v*65535)*16)*48000/4294967296).toFixed(2)} Hz`;
 return `${Math.round(v*100)}%`;
}
export const parameterName=(key:string)=>key.split('.')[1].replace(/\b\w/g,c=>c.toUpperCase());
export const escape=(s:string)=>s.replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]!));

// Match fabric_screen.sv: truncate the 16-bit register percentage, except full scale.
export function hardwarePercent(v:number):number {
 const raw=Math.round(normalize(v)*65535);
 return raw===65535?100:Math.floor(raw*100/65536);
}
export function hardwareValueLabel(key:string,v:number):string {
 return ['filter.mode','glitch.mode','glitch.size','freeze.hold'].includes(key)?valueLabel(key,v):`${hardwarePercent(v)}%`;
}

export function componentValueLabel(key:string,v:number):string {
 const physical=valueLabel(key,v),hardware=hardwareValueLabel(key,v);
 return physical===hardware?physical:`${hardware} · ${physical}`;
}
