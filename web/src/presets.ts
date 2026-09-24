import {defaultPatch,type Patch} from './model';

export const presets=[
 {name:'Folded Light',description:'Wavefolder real: plegado suave con señal directa.',branches:['wavefolder'],values:{'mixer.dry':.25,'mixer.wavefolder':.35,'wavefolder.drive':.45}},
 {name:'Breathing VCA',description:'LFO sobre el nivel del VCA: trémolo real.',branches:['vca'],values:{'mixer.vca':.7,'vca.level':1,'lfo.rate':.15,'lfo.depth':1}},
 {name:'Chaotic Focus',description:'Chaos mueve el cutoff del filtro de forma irregular.',branches:['filter'],values:{'mixer.filter':.65,'filter.cutoff':.18,'filter.resonance':.4,'chaos.amount':1,'chaos.rate':.22}},
 {name:'Clean Reference',description:'Señal directa para comparar con los efectos.',branches:[],values:{'mixer.dry':.8}},
 {name:'Short Echo',description:'Delay de 110 ms mezclado con la señal directa.',branches:['delay'],values:{'mixer.dry':.55,'mixer.delay':.25,'delay.time':.6445,'delay.feedback':.5}},
 {name:'Soft Focus',description:'Filtro grave, sin señal directa.',branches:['filter'],values:{'mixer.filter':.65,'filter.cutoff':.22,'filter.resonance':.25}},
 {name:'Broken Texture',description:'Glitch moderado sobre la señal original.',branches:['glitch'],values:{'mixer.dry':.45,'mixer.glitch':.3,'glitch.amount':.45,'glitch.probability':.24}},
 {name:'Slow Motion',description:'LFO lento sobre el filtro y un eco corto en paralelo.',branches:['filter','delay'],values:{'mixer.dry':.15,'mixer.filter':.4,'mixer.delay':.15,'filter.cutoff':.4,'filter.resonance':.3,'delay.time':.8,'delay.feedback':.4,'lfo.rate':.025,'lfo.depth':.3}},
 {name:'Stutter Memory',description:'Fragmentos estéreo de 42,7 ms repetidos ocho veces, sin señal directa.',branches:['glitch'],values:{'mixer.glitch':.65,'glitch.mode':1,'glitch.size':1,'glitch.repeats':7/15,'glitch.amount':1,'glitch.probability':1}},
 {name:'High Pass Air',description:'Paso alto: elimina graves. Mueve Cutoff para comparar.',branches:['filter'],values:{'mixer.filter':.65,'filter.mode':1/3,'filter.cutoff':.25,'filter.resonance':.3}},
 {name:'Band Focus',description:'Paso banda: aísla una zona del espectro.',branches:['filter'],values:{'mixer.filter':.65,'filter.mode':2/3,'filter.cutoff':.25,'filter.resonance':.65}},
 {name:'Notch Sweep',description:'Filtro notch modulado: mueve una zona de rechazo.',branches:['filter'],values:{'mixer.filter':.65,'filter.mode':1,'filter.cutoff':.1,'filter.resonance':.35,'lfo.rate':.06,'lfo.depth':.7}},

 {name:'Aurora Stereo',description:'Chorus, eco y movimiento estereo en ramas independientes. Firmware ampliado.',branches:['chorus','delay','autopan'],values:{'mixer.chorus':.35,'mixer.delay':.2,'mixer.autopan':.3,'mixer.master':.5,'chorus.rate':.04,'chorus.depth':.65,'delay.time':.85,'delay.feedback':.55,'autopan.rate':.08,'autopan.depth':.8}},
 {name:'Neon Dust',description:'Bitcrusher con chorus y filtro en paralelo. Firmware ampliado.',branches:['crusher','chorus','filter'],values:{'mixer.crusher':.2,'mixer.chorus':.3,'mixer.filter':.35,'mixer.master':.5,'crusher.bits':.5,'crusher.rate':.02,'chorus.depth':.45,'filter.cutoff':.25,'filter.resonance':.2}},
 {name:'Glacial Pulse',description:'Captura Freeze, flanger y tremolo independientes. CAPTURE renueva el fragmento.',branches:['freeze','flanger','tremolo'],values:{'mixer.freeze':.3,'mixer.flanger':.3,'mixer.tremolo':.25,'mixer.master':.5,'freeze.hold':1,'flanger.rate':.025,'flanger.depth':.85,'tremolo.rate':.18,'tremolo.depth':.75}},
 {name:'Living Echo',description:'Auto-wah por intensidad de entrada, chorus y delay. Firmware ampliado.',branches:['filter','chorus','delay'],values:{'mixer.filter':.4,'mixer.chorus':.25,'mixer.delay':.2,'mixer.master':.5,'filter.cutoff':.025,'filter.resonance':.35,'envelope.depth':.9,'envelope.release':.5,'delay.time':.7,'delay.feedback':.45}},

] satisfies {name:string;description:string;branches:string[];values:Record<string,number>}[];

export function presetPatch(index:number):Patch{
 const spec=presets[index];if(!spec)throw new Error('Unknown preset');
 const p=defaultPatch();p.name=spec.name;p.bypass={glitch:false,delay:false,delay2:false,filter:false,wavefolder:false,vca:false,lfo:false,chaos:false};
 Object.assign(p.parameters,{'mixer.dry':0,'mixer.glitch':0,'mixer.delay':0,'mixer.filter':0,'mixer.master':.8,'lfo.depth':0},spec.values);
 p.routes=[['sample','mixer'],['mixer','out']];
 p.nodes={sample:[24,220],mixer:[807,245],out:[957,245]};
 spec.branches.forEach((id,i)=>{p.routes.push(['sample',id],[id,'mixer']);p.nodes![id]=[350+i*205,195];});
 p.modulation=spec.name==='Living Echo'?[['envelope','filter.cutoff']]:(spec.name==='Slow Motion'||spec.name==='Notch Sweep')?[['lfo','filter.cutoff']]:spec.name==='Breathing VCA'?[['lfo','vca.level']]:spec.name==='Chaotic Focus'?[['chaos','filter.cutoff']]:[];
 if(p.modulation.length)p.nodes[p.modulation[0][0]]=[350,25];
 return p;
}
