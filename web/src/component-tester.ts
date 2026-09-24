import {defaultPatch,type Patch} from './model';
import {audibleBranches,expandedBranches} from './expansion';
export const componentTests=[['glitch','Glitch · Stutter'],['delay','Delay'],['delay2','Delay 2'],['filter','Filter · LPF'],['hpf','Filter · HPF'],['bpf','Filter · BPF'],['notch','Filter · Notch'],['wavefolder','Wavefolder'],['vca','VCA'],['chorus','Chorus'],['flanger','Flanger'],['crusher','Bitcrusher'],['freeze','Freeze · captura'],['tremolo','Tremolo'],['autopan','Auto-pan'],['envelope','Envelope · Auto-wah']];
export function componentTestPatch(id:string,source:Patch):Patch{
 if(!componentTests.some(([key])=>key===id))throw new Error('Unknown component test');
 const p=defaultPatch();p.name='TEST · '+componentTests.find(([key])=>key===id)![1];
 p.parameters={...p.parameters,...source.parameters};p.hardware={...source.hardware};p.hardwareBank1=source.hardwareBank1?{...source.hardwareBank1}:undefined;
 p.mute={};p.solo={};p.bypass={};p.modulation=[];
 for(const key of ['dry',...audibleBranches])p.parameters['mixer.'+key]=0;
 p.parameters['mixer.master']=Math.min(source.parameters['mixer.master']??.4,.5);
 p.parameters['lfo.depth']=0;p.parameters['chaos.amount']=0;
 const node=['hpf','bpf','notch','envelope'].includes(id)?'filter':id;
 p.nodes={sample:[24,220],[node]:[390,220],mixer:[807,245],out:[957,245]};p.routes=[['sample',node],[node,'mixer'],['mixer','out']];p.parameters['mixer.'+node]=.75;
 if(node==='filter')Object.assign(p.parameters,{'filter.cutoff':id==='hpf'?.65:.12,'filter.resonance':.2,'filter.mode':id==='hpf'?1/3:id==='bpf'?2/3:id==='notch'?1:0});
 if(node==='glitch')Object.assign(p.parameters,{'glitch.mode':1,'glitch.size':1,'glitch.repeats':7/15,'glitch.amount':1,'glitch.probability':1});
 if(node==='delay'||node==='delay2')Object.assign(p.parameters,{[node+'.time']:.7,[node+'.feedback']:.5});
 if(node==='wavefolder')p.parameters['wavefolder.drive']=.65;
 if(node==='vca')p.parameters['vca.level']=.5;
 if(id==='freeze')p.parameters['freeze.hold']=1;
 if(id==='chorus')Object.assign(p.parameters,{'chorus.rate':.06,'chorus.depth':.75});
 if(id==='flanger')Object.assign(p.parameters,{'flanger.rate':.04,'flanger.depth':.9});
 if(id==='crusher')Object.assign(p.parameters,{'crusher.bits':.55,'crusher.rate':.03});
 if(id==='tremolo'||id==='autopan'){p.parameters[id+'.depth']=1;p.parameters[id+'.rate']=.2;}
 if(id==='envelope'){p.parameters['filter.cutoff']=.02;p.parameters['envelope.depth']=1;p.parameters['envelope.release']=.5;p.nodes.envelope=[380,30];p.modulation=[['envelope','filter.cutoff']];}
 return p;
}
export const isExpandedTest=(id:string)=>expandedBranches.includes(id)||id==='envelope';
