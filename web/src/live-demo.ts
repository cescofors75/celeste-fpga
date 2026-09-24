import {defaultPatch,recommendEncoderBanks,type Patch} from './model';
import {audibleBranches} from './expansion';
import {LIVE_SECONDS,LIVE_SECTION_SECONDS,liveScenes,sectionAt} from './live-score';
export {LIVE_SECONDS,liveScenes} from './live-score';
export function liveDemoFrame(seconds:number,expanded=true):{patch:Patch;scene:number;label:string}{
 const time=((seconds%LIVE_SECONDS)+LIVE_SECONDS)%LIVE_SECONDS,scene=sectionAt(time),local=time-scene*LIVE_SECTION_SECONDS;
 const wet=Math.max(0,Math.min(1,local/2,(LIVE_SECTION_SECONDS-local)/2)),motion=.5-.5*Math.cos(local*Math.PI*2/LIVE_SECTION_SECONDS);
 const p=defaultPatch();if(expanded)recommendEncoderBanks(p);
 p.name='CELESTE · Parallel Tides';p.bypass={};p.mute={};p.solo={};p.modulation=[];
 p.nodes={sample:[24,250],mixer:[807,245],out:[957,245]};
 p.routes=[['sample','mixer'],['mixer','out']];
 for(const branch of audibleBranches)p.parameters['mixer.'+branch]=0;
 Object.assign(p.parameters,{'mixer.dry':.34,'mixer.master':.75,'lfo.depth':0,'chaos.amount':0,'envelope.depth':0,
  'filter.cutoff':.26,'filter.resonance':.18,'filter.mode':0,'wavefolder.drive':.12,
  'delay.time':.523,'delay.feedback':.38,'delay2.time':.785,'delay2.feedback':.32,'vca.level':1,
  'lfo.rate':.04,'chaos.rate':.025,'glitch.amount':.3,'glitch.probability':.15,'glitch.mode':1,'glitch.size':1,'glitch.repeats':0,
  'chorus.rate':.025,'chorus.depth':.36,'flanger.rate':.016,'flanger.depth':.23,'crusher.bits':.18,'crusher.rate':.006,
  'freeze.hold':0,'tremolo.rate':.235,'tremolo.depth':.38,'autopan.rate':.055,'autopan.depth':.5,'envelope.release':.62});
 const branch=(id:string,gain:number)=>{if(!p.routes.some(([a,b])=>a==='sample'&&b===id))p.routes.push(['sample',id],[id,'mixer']);p.parameters['mixer.'+id]+=gain*wet;};
 const extra=(id:string,gain:number)=>{if(expanded)branch(id,gain);else branch(id==='chorus'||id==='freeze'?'delay':id==='tremolo'||id==='autopan'?'vca':'filter',gain);};
 if(scene===0){extra('chorus',.18);extra('autopan',.12);}
 if(scene===1){branch('filter',.2);extra('chorus',.1);p.parameters['filter.cutoff']=.16+.35*motion;}
 if(scene===2){branch('vca',.2);extra('autopan',.18);p.parameters['lfo.depth']=.18;p.modulation=[['lfo','vca.level']];}
 if(scene===3){extra('chorus',.18);branch('delay',.18);}
 if(scene===4){extra('tremolo',.15);extra('autopan',.15);branch('filter',.08);}
 if(scene===5){branch('delay',.18);branch('delay2',.18);extra('chorus',.08);}
 if(scene===6){extra('freeze',.08);extra('chorus',.15);branch('delay',.16);p.parameters['freeze.hold']=local>5&&local<15?1:0;}
 if(scene===7){branch('filter',.2);extra('chorus',.12);branch('wavefolder',.055);p.parameters['filter.cutoff']=.2+.45*motion;}
 if(scene===8){branch('glitch',.09);branch('delay',.16);extra('autopan',.12);p.parameters['glitch.probability']=.12+.12*motion;}
 if(scene===9){branch('filter',.24);extra('tremolo',.12);p.parameters['lfo.depth']=.2;p.parameters['chaos.amount']=.12;p.modulation=[['lfo','filter.cutoff'],['chaos','filter.cutoff']];if(expanded){p.parameters['envelope.depth']=.3;p.modulation.push(['envelope','filter.cutoff']);}}
 if(scene===10){extra('flanger',.12);extra('crusher',.035);p.routes.push(['sample','delay'],['delay','delay2'],['delay2','mixer']);p.parameters['mixer.delay2']=.16*wet;}
 if(scene===11){extra('chorus',.18);branch('delay',.15);extra('autopan',.12);}
 // Display only the engines used in this scene, in readable parallel rows.
 const effects=[...new Set(p.routes.flat().filter(id=>audibleBranches.includes(id)))];
 effects.forEach((id,i)=>{p.nodes![id]=[id==='delay2'&&scene===10?630:465,35+i*135];});
 p.modulation.forEach(([id],i)=>{p.nodes![id]=[220,20+i*170];});
 return {patch:p,scene,label:liveScenes[scene]};
}
// Time follows actual source consumption, not the browser's interval cadence.
export class LiveDemoClock{
 private last=0;seconds=0;paused=false;
 start(counter:number){this.last=counter;this.seconds=0;this.paused=false;}
 rebase(counter:number){this.last=counter;}
 advance(counter:number){const delta=(counter-this.last)>>>0;this.last=counter;if(!this.paused)this.seconds+=delta/48000;return this.seconds;}
}
