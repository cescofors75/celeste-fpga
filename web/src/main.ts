import {expandedBranches,audibleBranches,expandedParameters,expansionMask,requiresExpansion} from './expansion';
import {componentTests,componentTestPatch,isExpandedTest} from './component-tester';
import {moduleWave} from './module-wave';
import './style.css';
import {liveDemoFrame,LiveDemoClock} from './live-demo';
import {LIVE_SECONDS} from './live-score';
import {nodeMeter,wireLevel,signalActive,meterPercent} from './signal';
import {presets,presetPatch} from './presets';
import init,{validate_patch,validate_session} from './wasm/celeste_wasm';
import {bankMapping,defaultPatch,recommendEncoderBanks,migrateEncoderBanks,colors,parameterColor,names,valueLabel,componentValueLabel,hardwareValueLabel,hardwarePercent,parameterName,escape,normalize,type Patch,type SampleRef,type Session} from './model';
import {AudioStore,Monitor} from './audio';
import {parseStatus,type Status} from './transport';
import {SerialTransport} from './worker-transport';
import {Streamer} from './stream';
import {ControlLink,supportsControlSnapshots,parameterIds,extraParameters,sonicParameters,hardwareParameters,bypassNodes,delay2Config,routeMask,type Controls} from './control';
const controls=new ControlLink();let deviceControls:Controls|undefined;let encoderBank=0;
const activeMapping=()=>bankMapping(patch,encoderBank);
const extendedDSP=()=>liveDSP()&&!!(status?.capabilities!&8);
const dualDSP=()=>connected&&!!(status?.capabilities!&256);
const expandedFX=()=>liveDSP()&&!!(status?.capabilities!&16384);
const sonicDSP=()=>connected&&!!(status?.capabilities!&1024);
const modulationTargets=(id:string)=>id==='filter'?['filter.cutoff']:id==='vca'?['vca.level']:[];
const auditedAudio=()=>!!(status?.capabilities!&128);
const deviceControlLink=()=>connected&&supportsControlSnapshots(status?.capabilities??0);
const liveDSP=()=>connected&&!!(status?.capabilities!&2);
function queueControls(){if(liveDSP())try{controls.queue(patch);}catch(e){notify(String(e),true);}}

const app=document.querySelector<HTMLDivElement>('#app')!;
let patch=recommendEncoderBanks(defaultPatch()),selected='filter',tab='PATCH',sample:SampleRef|null=null,expectedSample:SampleRef|null=null;
let waveform:Float32Array=new Float32Array(),looping=true,mode='monitor',loaded=false,loading=false,wasmReady=false,connected=false,connecting=false,position=0;
let status:Status|undefined,notice='Load a WAV to begin. Your sample stays on this computer.',isError=false;
let connectionError='';
let expansionLevels:number[]=[];
let testerSaved:{patch:Patch;bypass:boolean}|undefined;let testerOpen=false;
let bypass=false,bypassPending:boolean|undefined;
const lineIn=()=>connected&&!!(status?.capabilities!&8192);
const hasBypass=()=>connected&&!!(status?.capabilities!&16);
function toggleBypass(){if(!hasBypass())return;pauseLive();const target=!(bypassPending??bypass);bypassPending=target;controls.pending.set(20,target?65535:0);updateStatus();}
let pendingPort:string|null=null,baudRate=3000000;
let graphObserver:ResizeObserver|undefined;
let audio=new AudioStore();const monitor=new Monitor(),streamer=new Streamer(),transport=new SerialTransport();
type LiveRun={saved:{patch:Patch;audio:AudioStore;sample:SampleRef|null;expected:SampleRef|null;waveform:Float32Array;loaded:boolean;position:number;looping:boolean;mode:string;bypass:boolean};store:AudioStore;clock:LiveDemoClock;scene:number;starting:boolean;lineInput:boolean};
let liveRun:LiveRun|undefined;
function persistPatch(){if(!liveRun&&!testerSaved)localStorage.setItem('celeste-patch',JSON.stringify(patch));}
function pauseLive(){if(liveRun&&!liveRun.starting){liveRun.clock.paused=true;controls.pending.clear();updateStatus();}}
const playing=()=>monitor.playing||streamer.playing;
const coords:Record<string,[number,number]>={chorus:[465,80],flanger:[640,80],crusher:[465,210],freeze:[640,210],tremolo:[465,340],autopan:[640,340],envelope:[230,30],sample:[24,250],lfo:[210,32],chaos:[210,390],delay2:[635,122],glitch:[465,12],delay:[465,122],filter:[465,232],wavefolder:[465,342],vca:[465,452],mixer:[807,245],out:[957,245]};
const branches=audibleBranches;
const meterIndex:Record<string,number>={sample:0,glitch:2,delay:3,filter:4,wavefolder:5,vca:6,delay2:13,mixer:7,out:7};
const activeNodes=()=>patch.nodes??Object.fromEntries(Object.entries(coords).filter(([id])=>id!=='delay2'&&!expandedBranches.includes(id)&&id!=='envelope'));
let previousPatch:Patch|undefined;let mixBeforeSolo:Record<string,number>|undefined;
const canConnect=(a:string,b:string)=>((expandedFX()||!connected)&&((a==='sample'&&expandedBranches.includes(b))||(expandedBranches.includes(a)&&b==='mixer')||(a==='envelope'&&b==='filter')))||((dualDSP()||!connected)&&((a==='sample'&&b==='delay2')||(a==='delay'&&b==='delay2')||(a==='delay2'&&b==='mixer')))||(['lfo','chaos'].includes(a)?(b==='filter'||(b==='vca'&&extendedDSP()))&&(a==='lfo'||extendedDSP()):a==='sample'?['glitch','delay','filter','mixer',...(extendedDSP()?['wavefolder','vca']:[])].includes(b):['glitch','delay','filter',...(extendedDSP()?['wavefolder','vca']:[])].includes(a)?b==='mixer':a==='mixer'&&b==='out');
const supportedNodes=new Set(['sample','out','mixer','glitch','delay','filter','lfo']);
const width=(id:string)=>['sample','mixer','out'].includes(id)?108:148;
const height=(id:string)=>branches.includes(id)?130:['sample','mixer','out'].includes(id)?125:145;
const notify=(message:string,error=false)=>{notice=message;isError=error;updateStatus();};
const icons:Record<string,string>={chorus:'~',flanger:'~',crusher:'#',freeze:'*',tremolo:'~',autopan:'<>',envelope:'~',sample:'≋',glitch:'ϟ',delay:'◷',delay2:'◷',filter:'⌁',wavefolder:'∿',vca:'▷',mixer:'☷',out:'◖',lfo:'∿',chaos:'◎'};
const nodeParams=(id:string)=>Object.keys(patch.parameters).filter(k=>k.startsWith(id+'.'));

function graphWires(){
 const coords=activeNodes();
 const paths=patch.routes.filter(([a,b])=>coords[a]&&coords[b]).map(([a,b],i)=>{
  const [ax,ay]=coords[a],[bx,by]=coords[b],x1=ax+width(a),y1=ay+height(a)/2,x2=bx,y2=by+height(b)/2;
  const bend=Math.max(35,Math.abs(x2-x1)*.45);
  const d=`M${x1},${y1} C${x1+bend},${y1} ${x2-bend},${y2} ${x2},${y2}`;
  const meter=a==='sample'?(b==='mixer'?1:meterIndex[b]):meterIndex[a];
  return `<path d="${d}" stroke="${colors[a]}" class="cable" data-flow="${meter??-1}" data-flow-from="${a}" data-flow-to="${b}"/><circle cx="${x1}" cy="${y1}" r="4" fill="${colors[a]}"/>`;
 }).join('');
 const mods=patch.modulation.map(([a,param])=>{const b=param.split('.')[0];if(!coords[a]||!coords[b])return '';const [ax,ay]=coords[a],[bx,by]=coords[b];return `<path d="M${ax+74},${ay+145} C${ax+74},${by-20} ${bx+74},${by-30} ${bx+74},${by}" stroke="${colors[a]}" class="mod-cable"/>`;}).join('');
 const input=coords.sample,output=coords.out;
 const bypassWire=input&&output?`<path class="bypass-wire" d="M${input[0]+width('sample')},${input[1]+height('sample')/2} C500,570 800,570 ${output[0]},${output[1]+height('out')/2}"/>`:'';
 return paths+mods+bypassWire;
}
function graph(){
 const coords=activeNodes();
 return `<div class="graph-scroll"><div class="graph-stage"><svg class="wires" viewBox="0 0 1090 575" aria-label="Patch signal routing">${graphWires()}</svg>${!Object.keys(coords).length?'<div class="empty-patch"><h2>Tu nuevo patch</h2><p>Añade módulos desde la biblioteca. Después conecta una salida con una entrada.</p><p>Empieza por Sample In → Mixer → Audio Out.</p></div>':''}${Object.entries(coords).map(([id,[x,y]])=>`<article class="node ${branches.includes(id)?'fx-node':''} ${selected===id?'selected':''}" style="--accent:${colors[id]};left:${x}px;top:${y}px;width:${width(id)}px;height:${height(id)}px" data-node="${id}" tabindex="0" role="button" aria-label="Edit ${names[id]}">
  <div class="node-heading" title="Arrastrar para mover"><i></i>${names[id]}</div>${moduleWave(id)}
  ${['sample','out'].includes(id)?`<small>${id==='sample'?(lineIn()?'LINE IN · 48 kHz':'WAV · 48 kHz'):'PCM5102'}</small>`:nodeParams(id).slice(0,2).map(k=>`<div class="node-value"><span>${parameterName(k)}</span><b data-value="${k}">${componentValueLabel(k,patch.parameters[k])}</b></div>`).join('')}
  ${branches.includes(id)?`<div class="component-switches"><button data-mute="${id}" aria-pressed="${!!patch.mute?.[id]}">${patch.mute?.[id]?'MUTED':'MUTE'}</button><button data-solo="${id}" aria-pressed="${!!patch.solo?.[id]}">SOLO</button></div>`:''}${[...bypassNodes,...expandedBranches,'envelope'].includes(id)?`<button class="component-bypass ${patch.bypass?.[id]?'active':''}" data-bypass="${id}" aria-pressed="${!!patch.bypass?.[id]}" ${connected&&!dualDSP()?'disabled':''}>${patch.bypass?.[id]?'BYPASS':'FX ON'}</button>`:''}${branches.includes(id)?`<small class="branch-state" data-branch-state="${id}"></small>`:''}
  ${meterIndex[id]!==undefined?`<div class="signal-meter" title="Pico real medido en FPGA" data-meter="${meterIndex[id]}" data-meter-node="${id}"><i></i></div>`:''}
  ${!['sample','lfo','chaos','envelope'].includes(id)?`<button class="port input" ${liveDSP()&&pendingPort&&!canConnect(pendingPort,id)?'disabled title="Ruta no disponible en esta FPGA"':''} data-in="${id}" aria-label="Connect to ${names[id]}"></button>`:''}
  ${id!=='out'?`<button class="port output" data-out="${id}" aria-label="Route from ${names[id]}"></button>`:''}
 </article>`).join('')}<div class="fabric-note"><span>↗</span> ${delay2Config(patch)===3?'DELAY 1 → DELAY 2 · SERIE':'ENTRADA → RAMAS → SUMA'}<small>Entrada · salida del efecto · aportación al Mixer</small></div></div></div>`;
}
function sliders(id:string){return [...nodeParams(id),...(branches.includes(id)?['mixer.'+id]:[])].map(key=>{
 const disabled=liveDSP()&&![...parameterIds.slice(0,extendedDSP()?18:13),...(dualDSP()?Object.values(extraParameters):[]),...(sonicDSP()?Object.values(sonicParameters):[]),...(expandedFX()?Object.values(expandedParameters):[])].includes(key);
 const options=key==='freeze.hold'?['CAPTURE','HOLD']:key==='filter.mode'?['LPF · Paso bajo','HPF · Paso alto','BPF · Paso banda','Notch']:key==='glitch.mode'?['Textura','Stutter']:key==='glitch.size'?['5,3 ms','10,7 ms','21,3 ms','42,7 ms']:null;
 const current=key==='freeze.hold'?(patch.parameters[key]>=.5?1:0):key==='glitch.mode'?(patch.parameters[key]>=.5?1:0):Math.min(3,Math.round(patch.parameters[key]*65535)>>>14);
 return `<label class="parameter"><span>${key==='mixer.'+id?'Mix de esta rama':parameterName(key)}<b data-value="${key}">${componentValueLabel(key,patch.parameters[key])}</b></span>${options?`<select data-param="${key}" aria-label="${key}" ${disabled?'disabled':''}>${options.map((label,i)=>`<option value="${i/(options.length-1)}" ${i===current?'selected':''}>${label}</option>`).join('')}</select>`:`<input type="range" min="0" max="1" step="0.001" ${disabled?'disabled':''} value="${patch.parameters[key]}" data-param="${key}" aria-label="${key}" style="--accent:${colors[id]}">`}</label>`;
 }).join('');}
function inspector(){
 if(!activeNodes()[selected])return '<h2>Construye tu patch</h2><p>Añade un módulo desde la biblioteca para editarlo.</p><p>FPGA: Sample In → efecto → Mixer → Audio Out. El firmware ampliado añade Wavefolder, VCA y Chaos.</p>';
 const mods=patch.modulation.filter(([,p])=>p.startsWith(selected+'.'));
 return `<button id="remove-node" class="wide">Quitar módulo del patch</button><div class="inspector-title"><i style="background:${colors[selected]}"></i><h2>${names[selected]}</h2><span>↗</span></div><p class="muted">${branches.includes(selected)?(selected==='delay2'?'Delay 2: entrada Sample In o salida de Delay 1. Máximo 85,3 ms.':'Entrada Sample In · salida al Mixer'+(selected==='delay'?' o a Delay 2. Máximo 170,7 ms.':'.')):'Control del patch'}</p>${patch.bypass?.[selected]?'<p class="error">Este módulo está en BYPASS. Pulsa BYPASS en el bloque para activar FX ON.</p>':''}${selected==='lfo'||selected==='chaos'?'<p>Asigna un destino: Filter → Cutoff o VCA → Level. Sin destino no modifica el sonido.</p>':''}${sliders(selected)||'<p class="muted">'+(selected==='sample'?'Stereo PCM from Rust/WASM. Use the sample deck below.':'Dedicated stereo I²S output. Hardware verification pending.')+'</p>'}
 ${selected==='delay'?'<button id="duplicate-delay" class="wide">＋ Añadir Delay 2</button>':''}${selected==='delay2'?'<button id="delays-parallel" class="wide">Dos delays en paralelo</button><button id="delays-series" class="wide">Dos delays en serie</button>':''}${branches.includes(selected)?'<button id="solo-branch" class="wide">Escuchar solo esta rama</button>':''}${mixBeforeSolo?'<button id="restore-mix" class="wide">Restaurar mezcla</button>':''}<div class="inspector-section"><h3>Signal routing</h3><p class="muted">Select an output port, then an input. Click a route to remove it.</p><div class="route-list">${patch.routes.filter(r=>r.includes(selected)).map(([a,b])=>`<button data-remove-route="${a},${b}">${names[a]??a}<span>→</span>${names[b]??b}<b>×</b></button>`).join('')||'<small>No audio routes</small>'}</div></div>
 <div class="inspector-section"><h3>Modulation inputs</h3>${mods.map(([a,b])=>`<button class="mapping" data-remove-mod="${a},${b}"><i style="background:${colors[a]}"></i>${names[a]} → ${parameterName(b)} <span>×</span></button>`).join('')}
 ${modulationTargets(selected).length?`<div class="mod-form"><select id="mod-source" aria-label="Modulation source"><option value="lfo">LFO</option><option value="chaos">Chaos</option></select><select id="mod-target" aria-label="Modulation parameter">${modulationTargets(selected).map(k=>`<option value="${k}">${parameterName(k)}</option>`).join('')}</select></div><button class="wide" id="add-mod">＋ Add modulation</button>`:'<small>No modulation targets</small>'}</div>
 <div class="inspector-section"><h3>Hardware mapping</h3>${Object.entries(activeMapping()).filter(([,v])=>v.startsWith(selected+'.')).map(([e,p])=>`<div class="mapping"><i style="background:${colors[selected]}"></i>${e.replace('encoder','Encoder ')}<span>${parameterName(p)}</span></div>`).join('')||'<small>Assign controls in Hardware</small>'}</div>
 <div class="draft-note">PATCH EDITOR <b>${liveDSP()?'LIVE FPGA CONTROL':'OFFLINE DESIGN'}</b><small>${extendedDSP()?'Glitch · Delay · Filter · Wavefolder · VCA. LFO / Chaos → Filter cutoff / VCA level.':'Glitch · Delay · Filter. Other modules remain offline.'}</small></div>`;
}
function testerPanel(){return `<section class="component-tester"><button id="toggle-tester">Tester de componentes</button>${testerOpen?`<p>Aisla un componente y guarda tu patch para restaurarlo.</p><select id="tester-component" aria-label="Componente a probar">${componentTests.map(([id,label])=>`<option value="${id}" ${connected&&isExpandedTest(id)&&!expandedFX()?'disabled':''}>${label}</option>`).join('')}</select><button id="run-component-test">Probar solo</button>${testerSaved?'<button id="restore-component-test">Restaurar mi patch</button>':''}<small>Mute silencia la rama. Bypass deja pasar sonido seco. Freeze captura 42,7 ms; CAPTURE renueva el audio.</small>`:''}</section>`;}
function deck(){return `${testerPanel()}<section class="sample-deck"><div class="sample-title"><div><small>SAMPLE SOURCE</small><strong id="filename">${escape(sample?.name??'No sample loaded')}</strong></div><div class="source-actions"><button id="live-demo" title="Parallel Tides · 4:34 · 168 BPM · 12 escenas con efectos reales.">▶ DEMO LIVE · 4:34</button><button id="ambient-demo" title="Generar una pieza ambient estéreo de 48 segundos">♫ Demo ambient</button><label class="button primary">＋ Load WAV<input id="sample-file" type="file" accept=".wav,audio/wav" hidden></label></div></div><div class="waveform"><svg id="waveform" viewBox="0 0 1000 64" preserveAspectRatio="none" aria-label="Sample waveform"></svg><span id="wave-placeholder">${loaded?'':'Drop a WAV here · mono / stereo · 44.1 / 48 kHz'}</span></div><div class="transport-bar"><button id="play" class="primary" ${!loaded?'disabled':''}>▶ Play</button><button id="stop">■ Stop</button><button id="bypass" aria-pressed="false">BYPASS</button><label class="loop"><input id="loop" type="checkbox" ${looping?'checked':''}> Loop</label><select id="output-mode" aria-label="Playback output"><option value="monitor" ${mode==='monitor'?'selected':''}>Local dry monitor</option><option value="fpga" ${mode==='fpga'?'selected':''}>FPGA → PCM5102</option></select><button id="connect-deck" class="primary">Conectar FPGA</button><span id="sample-info">48 kHz target · Q1.15 stereo</span><b id="position">00:00</b></div><div id="playback-help" role="status"></div><div class="live-demo-panel" id="live-demo-panel" hidden><strong id="live-demo-stage"></strong><span id="live-demo-path">Automatización FPGA · tu patch está guardado</span><button id="live-demo-pause">Pausar automatización</button><button id="live-demo-exit">Salir y restaurar mi patch</button></div></section>`;}
function bankSelector(){return `<div class="bank-selector" aria-label="Banco de encoders"><span>BANCO</span>${[0,1].map(b=>`<button data-bank="${b}" aria-pressed="${encoderBank===b}" ${connected?'disabled':''}>${b}</button>`).join('')}<small>${connected?'Selector físico 0 / 1':'Vista previa · selector 0 / 1'}</small></div>`;}
function encoders(){return `<section class="hardware-strip"><div class="hardware-brand"><strong>CELESTE</strong><small>TANG NANO 20K</small>${bankSelector()}<p>PARALLEL DSP<br>MODULAR ENGINE<br>FOR A BRIGHTER TOMORROW</p></div><div class="encoders">${Object.entries(activeMapping()).map(([e,p],i)=>`<button class="encoder" data-encoder="${e}" role="slider" aria-label="${e} ${p}" aria-valuemin="0" aria-valuemax="100" aria-valuenow="${hardwarePercent(patch.parameters[p])}" title="Drag / arrows to adjust. Double-click to map." style="--accent:${parameterColor(p)}"><small>${i+1}</small><div class="knob" style="--turn:${-135+patch.parameters[p]*270}deg"><span></span></div><div class="encoder-display"><span>${p.replace('.','<br>')}</span><b data-value="${p}">${hardwareValueLabel(p,patch.parameters[p])}</b></div></button>`).join('')}</div><div class="device-display"><strong>CELESTE</strong><div class="mini-values">${Object.entries(activeMapping()).map(([e,p],i)=>`<div style="color:${parameterColor(p)}"><span>${i+1} ${escape(p.replace('glitch','GLT').replace('probability','PRB').replace('feedback','FB').replace('filter','FLT').replace('cutoff','CUT').replace('mixer','MIX').replace('amount','AMT').replace('resonance','RES').replace('.',' '))}</span><b data-value="${p}">${hardwareValueLabel(p,patch.parameters[p])}</b></div>`).join('')}</div><small>BANCO ${encoderBank} · PATCH 01</small><span>${escape(patch.name)}</span><b id="device-state">${connected?'FPGA READY':'PATCH PREVIEW'}</b></div><button id="touch-page" class="touch"><span></span><small>TOUCH<br>BYPASS</small></button></section>`;}
function otherView(){
 if(tab==='PERFORM')return `<div class="page-content"><small>PERFORMANCE CONTROLS</small><h1>Shape the moment.</h1><p>Live controls update the FPGA while audio plays. Delay: 0.02–170.67 ms. Glitch, Delay and Filter run in parallel.</p><div class="perform-grid">${['glitch','delay','filter','mixer','lfo','chaos'].map(id=>`<section style="--accent:${colors[id]}"><h2>${names[id]}</h2>${sliders(id)}</section>`).join('')}</div></div>`;
 if(tab==='PRESETS')return `<div class="page-content"><small>PATCHES & SESSIONS</small><h1>Your parallel universes.</h1><p>A patch stores routing, parameters and control mappings. A session also references your sample and playback position.</p><div class="preset-bank">${presets.map((p,i)=>`<section><h2>${p.name}</h2><p>${p.description}</p><button data-preset="${i}">Cargar preset</button></section>`).join('')}</div><p>Stutter Memory y los modos HPF/BPF/Notch requieren el nuevo motor sónico. Breathing VCA y Chaotic Focus usan modulación FPGA. Usa tu WAV con FPGA → PCM5102. Cargar un preset detiene la reproducción; pulsa Play para escucharlo. Las funciones activas dependen del firmware conectado.</p><div class="preset-card"><span>01</span><h2>${escape(patch.name)}</h2><p>${patch.routes.length} audio routes · ${patch.modulation.length} modulation routes</p><label>Patch name<input id="patch-name" maxlength="120" value="${escape(patch.name)}"></label><button id="save-patch" class="primary">↓ Export patch</button><button id="save-session">↓ Export session</button><label class="button">↑ Import JSON<input id="import-file" type="file" accept=".json" hidden></label><button id="reset-patch">Load factory patch</button></div>${expectedSample?`<p>Session requires: ${escape(expectedSample.name)}. Select the original WAV to restore playback.</p>`:''}</div>`;
 if(tab==='HARDWARE')return `<div class="page-content"><small>PHYSICAL CONTROL</small><h1>16 asignaciones · 8 encoders</h1>${bankSelector()}<button id="encoder-profile">Aplicar reparto de 16 controles</button><p>Assignments belong to this patch. Connected encoders update the same FPGA registers as these controls; values are read back from the board.</p><div class="hardware-mappings">${Array.from({length:8},(_,i)=>`<label>Encoder ${i+1}<select data-map="encoder${i+1}">${Object.values(hardwareParameters).map(k=>`<option ${activeMapping()['encoder'+(i+1)]===k?'selected':''}>${k}</option>`).join('')}</select></label>`).join('')}</div><h2>Botón táctil</h2><p>Un toque alterna BYPASS: señal directa / efectos. GPIO 72, activo alto, antirrebote de 10 ms. Mantener pulsado no repite. Comparte estado con el botón BYPASS de la web; el volumen Master se conserva.</p><h2>Mute / Solo con encoders</h2><p>En firmware ampliado: toque corto silencia la rama del parametro asignado; mantener 700 ms activa Solo. Repetir desactiva. Encoder Master: Mute de todas las ramas; mantener limpia Solo. Dos bancos de ocho controles: banco 0, motores principales y modulacion; banco 1, nuevos efectos y Master. Freeze: derecha HOLD, izquierda CAPTURE. LFO, Chaos y Envelope son moduladores y no tienen Mute/Solo de audio.</p><h2>Recursos del firmware</h2>${(status?.capabilities!&32)?`<p>${expandedFX()?'FX independientes · Logica: 19 384 / 20 736 (94%) · DSP: 23 / 24 (96%)':sonicDSP()?'Motor sónico · DSP: 22 / 24 (92%)':dualDSP()?'Dos delays · DSP: 21 / 24 (88%)':auditedAudio()?'Audio auditado · Lógica: 13 115 / 20 736 (64%) · DSP: 22 / 24 (92%)':'Lógica: 12 844 / 20 736 (62%) · DSP: 20,5 / 24 (86%)'} · Memoria BSRAM: ${expandedFX()?'38 / 46 (83%)':(status?.capabilities!&2048)?('30 / 46 (66%) · Audio SDRAM '+((status?.capabilities!&4096)?'512':'128')+' KiB'):sonicDSP()?'46 / 46 (100%)':dualDSP()?'42 / 46 (92%)':'34 / 46 (74%)'}. Informe de compilación, no consumo dinámico. Los módulos ocupan estos recursos aunque no tengan cables.</p><p>Instancias disponibles: 1 Glitch, ${dualDSP()?'2 Delays (170,7 y 85,3 ms)':'1 Delay'}, 1 Filter, 1 Wavefolder, 1 VCA, 1 LFO y 1 Chaos. ${expandedFX()?'Ademas: Chorus, Flanger, Bitcrusher, Freeze, Tremolo, Auto-pan y Envelope. ':' '}Las instancias están reservadas en el firmware; otras duplicaciones requieren ampliar hardware.</p>`:'<p>Conecta el firmware del dashboard para consultar sus recursos.</p>'}<h2>Bring-up status</h2><p>PCM5102 pin reference: BCK 73 · DIN 74 · LRCK 75. Confirm the physical wiring before loading a board build.</p><p>HDMI and the 240×240 display show actual register values and encoder assignments. The touch button toggles global bypass.</p></div>`;
 return `<div class="page-content"><small>ENGINE & DIAGNOSTICS</small><h1>Know what is running.</h1><p>No synthesized telemetry. Values below come from a CELESTE protocol handshake.</p><div class="settings-grid"><section><h2>Transport</h2><label>UART baud rate<select id="baud">${[115200,2000000,3000000].map(v=>`<option value="${v}" ${v===baudRate?'selected':''}>${v.toLocaleString()} baud</option>`).join('')}</select></label><p>48 kHz stereo PCM16 needs 192,000 bytes/s. At 8N1 that is at least 1.92 Mbaud before framing. The stream board uses 3 Mbaud. Select USB Serial Port COM14 (interface B).</p><button id="connect-settings">${connected?'Disconnect':'Connect device'}</button></section><section><h2>Audio format</h2><p>48,000 frames/s · two signed 16-bit channels · little-endian. WAV decoding and resampling run in a Rust/WASM worker.</p><p>Max WAV size: 128 MiB. Playback streams in chunks; the FPGA never stores the whole file.</p></section></div><pre id="telemetry">${telemetry()}</pre><p>Serial access needs a supported Chromium browser and localhost or HTTPS.</p></div>`;
}
function telemetry(){return status?JSON.stringify({...status,...(transport.diagnostics?{usbHistory:transport.diagnostics}:{})},null,2):'TRANSPORT   disconnected\nFIFO        —\nUNDERRUNS   —\nOVERRUNS    —\nSAMPLES     —\nDSP MASK    —\nROUTES      —\nCRC ERRORS  —';}
function render(){
 app.innerHTML=`<header><a class="logo" href="#" aria-label="CELESTE home">CELESTE<small>F P G A &nbsp; S Y N T H &nbsp; L A B</small></a><nav>${['PATCH','PERFORM','PRESETS','HARDWARE','SETTINGS'].map(t=>`<button data-tab="${t}" class="${tab===t?'active':''}">${t}</button>`).join('')}</nav><button id="connect" class="connection"><i class="${connected?'online':''}"></i>${connecting?'CONNECTING…':connected?'CONNECTED':'CONNECT DEVICE'}<small>Tang Nano 20K</small></button></header>
 <div class="workspace"><aside class="library"><div class="library-tabs"><b>MODULES</b><span>V1</span></div>${[['AUDIO','sample','out','mixer'],['EFFECTS','glitch','delay','delay2','filter','wavefolder','vca',...expandedBranches],['MODULATION','lfo','chaos','envelope']].map(([label,...ids])=>`<h3>${label}</h3>${ids.map(id=>`<button data-select="${id}" class="library-item ${id===selected?'active':''}"><span style="color:${colors[id]}">${icons[id]}</span>${names[id]}<small>${(expandedBranches.includes(id)||id==='envelope')&&connected&&!expandedFX()?'NUEVO FW':id==='delay2'&&connected&&!dualDSP()?'NUEVO FW':!supportedNodes.has(id)&&!extendedDSP()?'OFFLINE':activeNodes()[id]?'EDITAR':'＋ AÑADIR'}</small></button>`).join('')}`).join('')}<h3>HARDWARE</h3><button data-tab="HARDWARE" class="library-item"><span>◉</span>8 Encoders</button><button data-tab="HARDWARE" class="library-item"><span>◎</span>Touch Button</button><div class="library-foot"><i></i> HOST PREPARATION<small id="wasm-status">${wasmReady?'Rust / WASM ready':'Loading WASM…'}</small><small>FPGA DSP: ${liveDSP()?(expandedFX()?'12 ramas FX + modulacion':extendedDSP()?'5 audio paths + LFO / Chaos':'3 parallel engines'):'not connected'}</small></div></aside>
 <main>${tab==='PATCH'?`<section class="fabric"><div id="bypass-banner" role="status"></div><div class="fabric-heading"><div><h1>PARALLEL FABRIC</h1><p>ONE SOURCE · PARALLEL / DUAL DELAY SERIES</p></div><div class="patch-actions"><button id="arrange-parallel">Ordenar en paralelo</button><button id="new-patch">＋ Nuevo patch</button>${previousPatch?'<button id="undo-new">Recuperar anterior</button>':''}</div></div><div id="fabric-telemetry" class="fabric-telemetry"></div>${graph()}<div class="scene-bar"><small>SCENE</small><span>01</span><input id="scene-name" aria-label="Patch name" maxlength="120" value="${escape(patch.name)}"><button id="export-top" title="Export patch">↓</button><span class="scene-hint" id="routing-hint">Salida → entrada · arrastra el título para mover</span><button class="danger" id="panic">PANIC</button></div></section>`:otherView()}${deck()}</main><aside class="inspector">${inspector()}</aside></div>${encoders()}<footer><span id="notice" role="status" class="${isError?'error':''}">${escape(notice)}</span><span id="run-state">OFFLINE / IDLE</span></footer>`;
 bind();drawWaveform();updateStatus();graphObserver?.disconnect();
 const viewport=document.querySelector<HTMLElement>('.graph-scroll'),stage=document.querySelector<HTMLElement>('.graph-stage');
 if(viewport&&stage){graphObserver=new ResizeObserver(()=>{stage.style.zoom=String(Math.max(window.innerWidth<760?.68:.5,Math.min(1,viewport.clientWidth/1090)));});graphObserver.observe(viewport);}
}
function drawWaveform(){const svg=document.querySelector('#waveform');if(!svg)return;svg.innerHTML=Array.from(waveform,(v,i)=>`<line x1="${i*1000/waveform.length}" x2="${i*1000/waveform.length}" y1="${32-v*29}" y2="${32+v*29}"/>`).join('');}
function updateStatus(){
 const hud=document.querySelector('#fabric-telemetry');if(hud)hud.textContent=connected?(deviceControls?.meters?`FPGA · ${deviceControls.meters.length} medidores reales · DSP ${expandedFX()?'23':sonicDSP()?'22':dualDSP()?'21':auditedAudio()?'22':'20.5'} / 24 · RAM ${expandedFX()?'38':(status?.capabilities!&2048)?'30':sonicDSP()?'46':dualDSP()?'42':'34'} / 46 · capacidad 20 736 celdas`:'FPGA conectada · firmware sin medidores de ramas'):'DISEÑO OFFLINE · conecta la FPGA para ver niveles reales';
 const banner=document.querySelector<HTMLElement>('#bypass-banner');if(banner){banner.hidden=!connected||!bypass;banner.textContent='BYPASS ACTIVO: escuchas la señal directa. Los cambios de efectos no se oyen hasta desactivarlo.';}
 document.querySelectorAll<HTMLElement>('[data-branch-state]').forEach(el=>{const id=el.dataset.branchState!,bit=id==='delay2'?0:1<<(branches.indexOf(id)+1),gain=patch.parameters['mixer.'+id]??0;let mask=0;try{mask=routeMask(patch,true,dualDSP()||!connected,expandedFX()||!connected);}catch{}const chain=delay2Config(patch)===3,series=id==='delay'&&chain,muted=patch.mute?.[id]||(id==='delay2'&&chain&&patch.mute?.delay),inSolo=patch.solo?.[id]||(id==='delay2'&&chain&&patch.solo?.delay),active=expandedBranches.includes(id)?!!(expansionMask(patch)&(1<<expandedBranches.indexOf(id))):id==='delay2'?!!delay2Config(patch):series||!!(mask&bit);el.textContent=muted?'MUTED':series&&patch.solo?.delay2?'SOLO · CADENA':Object.values(patch.solo??{}).some(Boolean)&&!inSolo?'OTRA RAMA EN SOLO':patch.bypass?.[id]?'BYPASS · PASO DIRECTO':bypass&&connected?'BYPASS':!active?'SIN RUTA COMPLETA':series?'SALIDA → DELAY 2':gain===0?'MIX 0% · SILENCIO':`MIX ${Math.round(gain*100)}%`;el.classList.toggle('silent',!active||(!series&&gain===0)||bypass);});
 document.querySelectorAll<HTMLElement>('[data-module-wave]').forEach(el=>{
  const id=el.dataset.moduleWave!;
  el.classList.toggle('wave-bypassed',!!patch.bypass?.[id]||(connected&&bypass));
 });
 const measured=connected&&status?.running?deviceControls?.meters:undefined;
 document.querySelectorAll<HTMLElement>('[data-meter]').forEach(el=>{
  const id=el.dataset.meterNode!,n=nodeMeter(id,(measured?.length??0)>=15),extraIndex=expandedBranches.includes(id)?expandedBranches.indexOf(id):['mixer','out'].includes(id)?6:id==='envelope'?7:-1;
  const value=expandedFX()&&measured&&extraIndex>=0?expansionLevels[extraIndex]/255:n===undefined?undefined:measured?.[n];
  el.classList.toggle('unavailable',value===undefined);el.classList.toggle('clipping',(value??0)>.999);
  el.title=value===undefined?'Sin telemetría para este motor':`Pico ${branches.includes(id)&&!expandedBranches.includes(id)&&(measured?.length??0)>=15?'antes de mezcla':'medido'}: ${value>0?(20*Math.log10(value)).toFixed(1):'-∞'} dBFS`;
  el.querySelector<HTMLElement>('i')!.style.width=`${meterPercent(value)}%`;
 });
 document.querySelectorAll<SVGElement>('[data-flow]').forEach(el=>{
  const from=el.dataset.flowFrom!,to=el.dataset.flowTo!,extraIndex=expandedBranches.indexOf(from);
  const level=expandedFX()&&measured&&(extraIndex>=0||from==='mixer')?(bypass&&to==='mixer'?undefined:expansionLevels[extraIndex>=0?extraIndex:6]/255):wireLevel(from,to,measured,bypass);
  el.classList.toggle('flowing',signalActive(level));el.classList.toggle('unavailable',level===undefined);
 });
 document.querySelector('.bypass-wire')?.classList.toggle('active',connected&&bypass);

 for(const id of ['bypass','touch-page']){const button=document.getElementById(id) as HTMLButtonElement|null;if(button){button.disabled=!hasBypass();button.setAttribute('aria-pressed',String(bypass));button.classList.toggle('bypassed',bypass);button.title=hasBypass()?'Alternar bypass general (mantiene Master)':'Conecta firmware con soporte de bypass';if(id==='bypass')button.textContent=bypassPending!==undefined?'BYPASS · enviando…':bypass?'BYPASS ON · DRY':'BYPASS OFF · FX';}}
 const message=document.querySelector('#notice');if(message){message.textContent=notice;message.classList.toggle('error',isError);}
 const run=document.querySelector('#run-state');if(run)run.textContent=lineIn()?(status?.running?'LINE IN / RUNNING':'LINE IN / STOPPED'):monitor.playing?'LOCAL DRY MONITOR':streamer.playing?'FPGA STREAMING':connected?'DEVICE LINK / IDLE':'OFFLINE / IDLE';
 const liveButton=document.querySelector<HTMLButtonElement>('#live-demo');if(liveButton){liveButton.disabled=!!liveRun||loading||connecting||!sonicDSP();liveButton.title=sonicDSP()?(lineIn()?'Salida del ordenador → PCM1808 Line-In → FPGA → PCM5102':'Parallel Tides: 4:34 de música y automatización FPGA'):'Conecta la FPGA con el motor sónico para iniciar DEMO LIVE';}
 const livePanel=document.querySelector<HTMLElement>('#live-demo-panel');if(livePanel)livePanel.hidden=!liveRun;
 const liveStage=document.querySelector('#live-demo-stage');if(liveStage&&liveRun)liveStage.textContent=liveRun.starting?'Preparando DEMO LIVE…':`${liveRun.clock.paused?'PAUSA · ':''}${liveDemoFrame(liveRun.clock.seconds,expandedFX()).label} · ${Math.floor((liveRun.clock.seconds%LIVE_SECONDS)/60)}:${String(Math.floor(liveRun.clock.seconds%LIVE_SECONDS)%60).padStart(2,'0')} / 4:34`;
 const livePath=document.querySelector('#live-demo-path');if(livePath&&liveRun)livePath.textContent=liveRun.lineInput?'Música del ordenador → PCM1808 → FX reales → PCM5102 · tu patch está guardado':'Música por USB → FX reales → PCM5102 · tu patch está guardado';
 const livePause=document.querySelector<HTMLButtonElement>('#live-demo-pause');if(livePause){livePause.disabled=!!liveRun?.starting;livePause.textContent=liveRun?.clock.paused?'Reanudar demo':'Pausar automatización';}
 const demo=document.querySelector<HTMLButtonElement>('#ambient-demo');if(demo){demo.disabled=loading||connecting||!wasmReady||lineIn();demo.textContent=loading?'Preparando audio…':'♫ Demo ambient';}
 const play=document.querySelector<HTMLButtonElement>('#play');if(play){play.disabled=lineIn()?connecting:connecting||!loaded||loading||!wasmReady||playing()||(mode==='fpga'&&!connected);play.textContent=lineIn()?(status?.running?'▶ LINE IN activo':'▶ Activar LINE IN'):playing()?'▶ Playing':'▶ Play';}
 const deckConnect=document.querySelector<HTMLButtonElement>('#connect-deck');if(deckConnect){deckConnect.hidden=mode!=='fpga'||connected;deckConnect.disabled=connecting;deckConnect.textContent=connecting?'Conectando…':'Conectar FPGA';}
 const help=document.querySelector('#playback-help');if(help){help.textContent=lineIn()?(status?.running?'LINE IN · PCM1808 → FPGA → PCM5102'+(bypass?' · BYPASS activo':' · FX activos'):'LINE IN detenido o sin reloj · pulsa Activar LINE IN'):connected&&bypass?'BYPASS ACTIVO · efectos fuera de la salida. Pulsa BYPASS para escucharlos.':connecting?notice:mode==='fpga'&&connectionError?connectionError:isError?notice:loading?notice:mode==='fpga'&&!connected?'Conecta COM14 con CONNECT DEVICE. Vinculado no significa conectado a CELESTE.':!loaded?'Carga un WAV para habilitar Play.':mode==='fpga'?'FPGA conectada · PCM5102 listo para reproducir.':'Monitor local listo.';help.classList.toggle('error',isError||(mode==='fpga'&&!!connectionError));}
 const info=document.querySelector('#sample-info');if(info){if(loaded&&audio.metadata){const m=audio.metadata;info.textContent=`${(m.source_rate/1000)} → 48 kHz · ${m.source_channels} ch · ${m.source_bits} bit · ${m.duration.toFixed(2)} s`;}else info.textContent='48 kHz target · Q1.15 stereo';}
 const elapsed=document.querySelector('#position');if(elapsed){const p=playing()?(monitor.playing?monitor.position:streamer.position):position;elapsed.textContent=`${String(Math.floor(p/48000/60)).padStart(2,'0')}:${String(Math.floor(p/48000)%60).padStart(2,'0')}`;}
 const deviceState=document.querySelector('#device-state');if(deviceState)deviceState.textContent=connected?(bypass?'BYPASS / DRY':status?.running?'FPGA RUNNING':deviceControls?.online?'8 ENCODERS ONLINE':'FPGA READY'):'PATCH PREVIEW';
 const debug=document.querySelector('#telemetry');if(debug)debug.textContent=telemetry()+(deviceControls?'\n\nCONTROLS\n'+JSON.stringify(deviceControls,null,2):'');
}
function applyPatch(candidate:Patch){if(!connected||controls.expandedEncoders)migrateEncoderBanks(candidate);candidate.parameters={...defaultPatch().parameters,...candidate.parameters};if(liveDSP()){routeMask(candidate,extendedDSP(),dualDSP(),expandedFX());if(requiresExpansion(candidate)&&!expandedFX())throw new Error('Requiere firmware ampliado.');for(const key of Object.values(candidate.hardware))if(!Object.values(hardwareParameters).includes(key))throw new Error('Unsupported physical mapping: '+key);}patch=JSON.parse(validate_patch(JSON.stringify(candidate)));persistPatch();queueControls();}
function edit(mutator:(p:Patch)=>void){pauseLive();try{const candidate=structuredClone(patch);mutator(candidate);applyPatch(candidate);render();notify(liveDSP()?'Patch queued for FPGA.':'Patch saved locally.');}catch(e){notify(String(e),true);}}
function exportJson(value:unknown,filename:string){const blob=new Blob([JSON.stringify(value,null,2)],{type:'application/json'}),url=URL.createObjectURL(blob),a=document.createElement('a');a.href=url;a.download=filename;a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);}
async function stop(haltInput=false){pauseLive();monitor.stop();await streamer.stop(connected&&(!lineIn()||haltInput)?transport:undefined).catch(e=>notify(String(e),true));position=0;monitor.position=0;updateStatus();}
async function loadFile(file:File){
 if(liveRun)await exitLive();
 if(loading)return;const restored=expectedSample?position:0;loading=true;await stop();notify('Preparing WAV in Rust / WASM…');updateStatus();
 try{
  if(file.size>128*1024*1024)throw new Error('WAV exceeds 128 MiB limit');
  const bytes=await file.arrayBuffer(),hash=Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',bytes)),v=>v.toString(16).padStart(2,'0')).join('');
  if(expectedSample&&(hash!==expectedSample.sha256||file.size!==expectedSample.size))throw new Error('This WAV does not match the saved session sample');
  const result=await audio.load(bytes);waveform=result.waveform;sample={name:file.name,size:file.size,sha256:hash};loaded=true;expectedSample=null;position=Math.min(restored,result.metadata.frames-1);
  notify(`Ready · ${file.name} · converted by Rust/WASM`);
 }catch(e){if(expectedSample)position=restored;notify(String(e),true);}finally{loading=false;render();}
}
async function loadAmbient(){
 if(liveRun)await exitLive();
 if(loading||!wasmReady)return;
 loading=true;await stop();notify('Generando ambient: acordes, campanas y ecos…');updateStatus();
 try{
  const seed=crypto.getRandomValues(new Uint32Array(1))[0],result=await audio.demo(seed);
  waveform=result.waveform;sample=result.sample;loaded=true;expectedSample=null;position=0;looping=true;
  notify('Demo ambient lista · 48 s estéreo. Pulsa Play; tu patch sigue aplicado.');
 }catch(e){notify(String(e),true);}finally{loading=false;render();}
}
async function startLive(){
 if(liveRun||loading||!sonicDSP())return;
 const run:LiveRun={lineInput:lineIn(),saved:{patch:structuredClone(patch),audio,sample,expected:expectedSample,waveform,loaded,position:playing()?(monitor.playing?monitor.position:streamer.position):position,looping,mode,bypass:bypassPending??bypass},store:new AudioStore(),clock:new LiveDemoClock(),scene:0,starting:true};
 liveRun=run;loading=true;render();
 try{
  if(run.lineInput)await monitor.unlock();
  await stop();run.store.onProgress=percent=>{if(liveRun===run)notify(`Componiendo Parallel Tides · ${percent}% · breaks, bajo y atmósferas…`);};
  const result=await run.store.demo(crypto.getRandomValues(new Uint32Array(1))[0],'live');
  if(liveRun!==run)return;
  audio=run.store;sample=result.sample;waveform=result.waveform;loaded=true;expectedSample=null;position=0;looping=true;mode='fpga';
  controls.pending.clear();controls.pending.set(20,0);bypassPending=false;
  applyPatch(liveDemoFrame(0,expandedFX()).patch);await controls.service(transport,true);
  if(liveRun!==run)return;
  const actual=parseStatus((await transport.request(2)).payload);status=actual;run.clock.start(run.lineInput?0:actual.sampleCounter);
  if(run.lineInput){await transport.request(5);await monitor.play(audio,()=>looping,0);}
  else void streamer.play(transport,audio,()=>looping,0);
  run.starting=false;loading=false;tab='PATCH';render();
  notify(run.lineInput?'DEMO LIVE · salida del ordenador al PCM1808; escucha por PCM5102.':'DEMO LIVE · Parallel Tides · rutas y controles reales en FPGA.');
 }catch(e){if(liveRun===run){await exitLive();notify(`Demo detenida: ${e}`,true);}}
 finally{if(liveRun===run){loading=false;render();}}
}
async function exitLive(){
 const run=liveRun;if(!run)return;liveRun=undefined;loading=false;
 await stop();controls.pending.clear();run.store.dispose();
 audio=run.saved.audio;sample=run.saved.sample;expectedSample=run.saved.expected;waveform=run.saved.waveform;loaded=run.saved.loaded;position=run.saved.position;looping=run.saved.looping;mode=run.saved.mode;
 patch=structuredClone(run.saved.patch);persistPatch();
 if(connected){controls.pending.set(20,run.saved.bypass?65535:0);bypassPending=run.saved.bypass;queueControls();await controls.service(transport,true).catch(e=>notify(String(e),true));}
 render();notify('Demo finalizada. Patch y fuente originales restaurados; reproducción detenida.');
}
async function toggleLivePause(){
 const run=liveRun;if(!run||run.starting)return;
 run.clock.advance(run.lineInput?monitor.consumedFrames:status?.sampleCounter??0);run.clock.paused=!run.clock.paused;if(run.clock.paused)controls.pending.clear();
 if(!run.clock.paused&&!playing()){if(run.lineInput){run.clock.rebase(0);await monitor.play(audio,()=>looping,position);}else{const actual=parseStatus((await transport.request(2)).payload);status=actual;run.clock.rebase(actual.sampleCounter);void streamer.play(transport,audio,()=>looping,position);}}
 updateStatus();
}
setInterval(()=>{
 const run=liveRun;if(!run||run.starting||!connected||!status)return;
 run.clock.advance(run.lineInput?monitor.consumedFrames:status.sampleCounter);
 if(run.clock.paused||!playing()||controls.pending.size>6)return;
 const frame=liveDemoFrame(run.clock.seconds,expandedFX()),changed=frame.scene!==run.scene;
 patch=controls.expandedEncoders?migrateEncoderBanks(frame.patch):frame.patch;queueControls();run.scene=frame.scene;
 if(changed)render();else updateStatus();
},250);
async function connect(){
 if(connecting)return;
 if(connected){if(liveRun)await exitLive();await stop();await transport.close();connected=false;status=undefined;render();return;}
 if(!wasmReady){notify('Espera a que Rust / WASM esté listo.',true);return;}
 connecting=true;connectionError='';isError=false;render();
 try{status=await transport.connect(baudRate);connected=true;bypassPending=undefined;controls.expanded=expandedFX();controls.expandedEncoders=expandedFX()&&!!(status!.capabilities&32768);controls.extended=extendedDSP();controls.dual=dualDSP();controls.sonic=sonicDSP();controls.banked=!!(status?.capabilities!&64);controls.reset();if(deviceControlLink()){if(liveDSP()&&!lineIn())controls.queue(patch);await controls.service(transport,true);}if(lineIn()){mode='fpga';await transport.request(5);}notify(lineIn()?'LINE IN conectado · entrada física PCM1808. No necesita WAV.':'CELESTE connected. Load WAV, select FPGA → PCM5102, then Play.');}catch(e){connectionError=String(e);status=undefined;connected=false;await transport.close();notify(connectionError,true);}finally{connecting=false;render();}
}
async function importFile(file:File){
 if(liveRun)await exitLive();
 try{if(file.size>1024*1024)throw new Error('JSON too large');const text=await file.text(),raw=JSON.parse(text);await stop();
  if(raw.format==='celeste-session'){
   const session:Session=JSON.parse(validate_session(text));applyPatch(session.patch);looping=session.looping;position=session.position;
   if(!session.sample||sample?.sha256!==session.sample.sha256||!loaded){expectedSample=session.sample;sample=session.sample;loaded=false;waveform=new Float32Array();}
   else {expectedSample=null;position=Math.min(position,audio.metadata!.frames-1);}
   notify(expectedSample?'Session restored. Select its original WAV to continue.':'Session restored.');
  }else{applyPatch(JSON.parse(validate_patch(text)));notify('Patch imported.');}render();
 }catch(e){notify(String(e),true);}
}
function bind(){
 const on=(id:string,fn:()=>void)=>document.getElementById(id)?.addEventListener('click',fn);
 document.querySelectorAll<HTMLButtonElement>('[data-bypass]').forEach(el=>el.onclick=e=>{e.stopPropagation();edit(p=>{const id=el.dataset.bypass!;p.bypass??={};p.bypass[id]=!p.bypass[id];});});

 on('toggle-tester',()=>{testerOpen=!testerOpen;render();});
 on('run-component-test',()=>void(async()=>{try{if(!liveDSP())throw new Error('Conecta FPGA para probar componentes.');if(liveRun)await exitLive();const id=(document.getElementById('tester-component') as HTMLSelectElement).value;if(isExpandedTest(id)&&!expandedFX())throw new Error('Actualiza el firmware.');testerSaved??={patch:structuredClone(patch),bypass};controls.pending.clear();applyPatch(componentTestPatch(id,patch));controls.pending.set(20,0);bypassPending=false;await controls.service(transport,true);if(lineIn())await transport.request(5);selected=id==='envelope'?'filter':['hpf','bpf','notch'].includes(id)?'filter':id;render();notify('Prueba aislada activa. Tu patch esta guardado.');}catch(e){notify(String(e),true);}})());
 on('restore-component-test',()=>void(async()=>{if(!testerSaved)return;try{const saved=testerSaved;controls.pending.clear();applyPatch(saved.patch);controls.pending.set(20,saved.bypass?65535:0);bypassPending=saved.bypass;await controls.service(transport,true);testerSaved=undefined;persistPatch();render();notify('Patch y bypass restaurados.');}catch(e){notify(String(e),true);}})());
 document.querySelectorAll<HTMLButtonElement>('[data-mute],[data-solo]').forEach(el=>el.onclick=e=>{e.stopPropagation();if(!expandedFX()&&connected){notify('Mute/Solo requiere firmware ampliado.',true);return;}const id=el.dataset.mute??el.dataset.solo!;edit(p=>{if(el.dataset.mute){p.mute??={};p.mute[id]=!p.mute[id];}else{const was=!!p.solo?.[id];p.solo=was?{}:{[id]:true};if(!was){p.mute??={};p.mute[id]=false;}}});});
 document.querySelectorAll<HTMLButtonElement>('[data-preset]').forEach(el=>el.onclick=()=>void (async()=>{try{if(liveRun)await exitLive();if(connected&&!sonicDSP()&&Number(el.dataset.preset)>=8)throw new Error('Este preset requiere el nuevo motor sónico de FPGA.');await stop();previousPatch=structuredClone(patch);applyPatch(presetPatch(Number(el.dataset.preset)));selected='mixer';tab='PATCH';render();notify(bypass?'Preset cargado, pero BYPASS sigue activo. Desactívalo para escuchar los efectos.':'Preset cargado. Pulsa Play con FPGA → PCM5102 para escucharlo.');}catch(e){notify(String(e),true);}})());
 document.querySelectorAll<HTMLElement>('[data-tab]').forEach(el=>el.onclick=()=>{tab=el.dataset.tab!;render();});
 document.querySelector('.logo')?.addEventListener('click',e=>{e.preventDefault();tab='PATCH';render();});
 document.querySelectorAll<HTMLElement>('[data-select],[data-node]').forEach(el=>{const select=()=>{selected=el.dataset.select??el.dataset.node!;if((expandedBranches.includes(selected)||selected==='envelope')&&connected&&!expandedFX()){notify('Este modulo requiere firmware ampliado.',true);return;}if(selected==='delay2'&&connected&&!dualDSP()){notify('Delay 2 necesita el nuevo firmware.',true);return;}if(!activeNodes()[selected]){if(liveDSP()&&!supportedNodes.has(selected)&&!extendedDSP()){notify('Este módulo solo está disponible en diseño offline.',true);return;}edit(p=>{p.nodes={...activeNodes(),[selected]:[...coords[selected]]};if(expandedBranches.includes(selected))p.parameters['mixer.'+selected]=.35;});}else render();};el.onclick=e=>{if(!(e.target as HTMLElement).closest('.port,.node-heading,.component-bypass,.component-switches'))select();};el.onkeydown=e=>{if(e.target===el&&(e.key==='Enter'||e.key===' ')){e.preventDefault();select();}};});
 document.querySelectorAll<HTMLButtonElement>('[data-out]').forEach(el=>el.onclick=e=>{e.stopPropagation();pendingPort=el.dataset.out!;render();notify(`Route from ${names[pendingPort]}: select an input port.`);});
 document.querySelectorAll<HTMLButtonElement>('[data-in]').forEach(el=>el.onclick=e=>{e.stopPropagation();if(!pendingPort){notify('Select an output port first.');return;}const a=pendingPort,b=el.dataset.in!;pendingPort=null;
  if(a==='lfo'||a==='chaos'||a==='envelope'){const target=modulationTargets(b)[0];if(target)edit(p=>p.modulation.push([a,target]));else notify('This module has no modulation target.',true);}
  else edit(p=>{if(p.routes.some(r=>r[0]===a&&r[1]===b))return;if(b!=='mixer')p.routes=p.routes.filter(r=>r[1]!==b);p.routes.push([a,b]);});});
 document.querySelectorAll<HTMLElement>('[data-remove-route]').forEach(el=>el.onclick=()=>edit(p=>{p.routes=p.routes.filter(r=>r.join(',')!==el.dataset.removeRoute);}));
 document.querySelectorAll<HTMLElement>('[data-remove-mod]').forEach(el=>el.onclick=()=>edit(p=>{p.modulation=p.modulation.filter(r=>r.join(',')!==el.dataset.removeMod);}));
 document.querySelectorAll<HTMLInputElement>('[data-param]').forEach(el=>el.oninput=()=>{pauseLive();const key=el.dataset.param!;patch.parameters[key]=normalize(Number(el.value));document.querySelectorAll<HTMLElement>('[data-value]').forEach(v=>{if(v.dataset.value===key)v.textContent=(v.closest('.hardware-strip')?hardwareValueLabel:componentValueLabel)(key,patch.parameters[key]);});persistPatch();queueControls();});
 document.querySelectorAll<HTMLButtonElement>('[data-bank]').forEach(el=>el.onclick=()=>{if(connected)return;encoderBank=Number(el.dataset.bank);render();});
 const profileButton=document.querySelector<HTMLButtonElement>('#encoder-profile');if(profileButton)profileButton.onclick=()=>{if(connected&&!controls.expandedEncoders){notify('Actualiza el firmware para asignar los nuevos motores a los encoders.',true);return;}recommendEncoderBanks(patch);localStorage.setItem('celeste-encoder-profile-v2','1');persistPatch();queueControls();render();};
 document.querySelectorAll<HTMLSelectElement>('[data-map]').forEach(el=>el.onchange=()=>edit(p=>{bankMapping(p,encoderBank)[el.dataset.map!]=el.value;}));
 document.querySelectorAll<HTMLSelectElement>('[data-touch]').forEach(el=>el.onchange=()=>edit(p=>{p.touch[el.dataset.touch!]=el.value;}));
 document.querySelectorAll<HTMLElement>('[data-encoder]').forEach(el=>{
 const set=(v:number)=>{pauseLive();const key=activeMapping()[el.dataset.encoder!];patch.parameters[key]=key==='freeze.hold'?(v>=.5?1:0):normalize(v);el.querySelector<HTMLElement>('.knob')?.style.setProperty('--turn',`${-135+patch.parameters[key]*270}deg`);el.setAttribute('aria-valuenow',String(hardwarePercent(patch.parameters[key])));document.querySelectorAll<HTMLElement>('[data-value]').forEach(n=>{if(n.dataset.value===key)n.textContent=(n.closest('.hardware-strip')?hardwareValueLabel:componentValueLabel)(key,patch.parameters[key]);});document.querySelectorAll<HTMLInputElement>('[data-param]').forEach(n=>{if(n.dataset.param===key)n.value=String(patch.parameters[key]);});persistPatch();queueControls();};
 el.ondblclick=()=>{tab='HARDWARE';render();};
 el.onkeydown=e=>{if(['ArrowUp','ArrowRight','ArrowDown','ArrowLeft','Home','End'].includes(e.key)){e.preventDefault();if(activeMapping()[el.dataset.encoder!]==='freeze.hold'){set(['ArrowUp','ArrowRight','End'].includes(e.key)?1:0);return;}const v=patch.parameters[activeMapping()[el.dataset.encoder!]];set(e.key==='Home'?0:e.key==='End'?1:v+(['ArrowUp','ArrowRight'].includes(e.key)?1:-1)*(e.shiftKey?.001:.01));}};
 el.onpointerdown=e=>{if(e.button!==0)return;e.preventDefault();el.focus();el.setPointerCapture(e.pointerId);const startY=e.clientY,startValue=patch.parameters[activeMapping()[el.dataset.encoder!]];el.onpointermove=move=>set(startValue+(startY-move.clientY)/240);el.onpointerup=()=>{el.onpointermove=null;el.releasePointerCapture(e.pointerId);};el.onpointercancel=()=>{el.onpointermove=null;};};
 });
 document.querySelectorAll<HTMLElement>('.node-heading').forEach(heading=>heading.onpointerdown=e=>{
 if(e.button!==0)return;e.preventDefault();e.stopPropagation();const node=heading.closest<HTMLElement>('[data-node]')!,id=node.dataset.node!,stage=document.querySelector<HTMLElement>('.graph-stage')!;
 const scale=stage.getBoundingClientRect().width/1090,start=activeNodes()[id],sx=e.clientX,sy=e.clientY;let moved=false;
 heading.setPointerCapture(e.pointerId);
 heading.onpointermove=m=>{if(Math.abs(m.clientX-sx)+Math.abs(m.clientY-sy)<4&&!moved)return;moved=true;patch.nodes={...activeNodes(),[id]:[Math.max(0,Math.min(1090-width(id),(start[0]+(m.clientX-sx)/scale))),Math.max(0,Math.min(575-height(id),start[1]+(m.clientY-sy)/scale))]};node.style.left=patch.nodes[id][0]+'px';node.style.top=patch.nodes[id][1]+'px';document.querySelector('.wires')!.innerHTML=graphWires();};
 const finish=()=>{heading.onpointermove=null;heading.onpointerup=null;heading.onpointercancel=null;persistPatch();selected=id;render();};heading.onpointerup=finish;heading.onpointercancel=finish;
 });

 on('touch-page',toggleBypass);on('bypass',toggleBypass);on('connect',()=>void connect());on('connect-settings',()=>void connect());on('connect-deck',()=>void connect());
 on('play',()=>{if(lineIn()){void transport.request(5).then(()=>{notify('LINE IN activado');updateStatus();}).catch(e=>notify(String(e),true));return;}if(!loaded||playing())return;if(mode==='fpga'){if(!connected)return;void streamer.play(transport,audio,()=>looping,position);notify('Streaming to FPGA parallel fabric. Live values come from the device.');}else{void monitor.play(audio,()=>looping,position).then(updateStatus).catch(e=>notify(String(e),true));notify('Local dry monitor · prepared PCM only · no FPGA effects');}updateStatus();});
 on('live-demo',()=>void startLive());on('live-demo-exit',()=>void exitLive());on('live-demo-pause',()=>void toggleLivePause());
 on('ambient-demo',()=>void loadAmbient());
 on('stop',()=>void stop(true));on('panic',()=>{void stop(true);notify('Playback stopped.');});
 on('export-top',()=>exportJson(patch,'celeste-patch.json'));on('save-patch',()=>exportJson(patch,'celeste-patch.json'));
 on('save-session',()=>{const session:Session={format:'celeste-session',version:1,patch,sample,position:playing()?(monitor.playing?monitor.position:streamer.position):position,looping,tempo:null};exportJson(JSON.parse(validate_session(JSON.stringify(session))),'celeste-session.json');});
 on('duplicate-delay',()=>{if(connected&&!dualDSP()){notify('Necesitas el firmware con dos delays.',true);return;}if(activeNodes().delay2){selected='delay2';render();notify('Ya están ocupadas las dos instancias de Delay.');return;}edit(p=>{p.nodes={...activeNodes(),delay2:[...coords.delay2]};p.parameters['delay2.time']=.5;p.parameters['delay2.feedback']=.25;p.parameters['mixer.delay2']=.5;});selected='delay2';render();notify('Delay 2 añadido. Elige serie o paralelo en el inspector.');});
 for(const serial of [false,true])on(serial?'delays-series':'delays-parallel',()=>edit(p=>{p.nodes={...activeNodes(),sample:coords.sample,delay:coords.delay,delay2:coords.delay2,mixer:coords.mixer,out:coords.out};p.routes=p.routes.filter(([a,b])=>!['delay','delay2'].includes(a)&&!['delay','delay2'].includes(b));p.routes.push(['sample','delay'],...(serial?[['delay','delay2']]:[['delay','mixer'],['sample','delay2']]) as [string,string][],['delay2','mixer']);if(!p.routes.some(r=>r[0]==='mixer'&&r[1]==='out'))p.routes.push(['mixer','out']);p.parameters['mixer.dry']=0;p.parameters['mixer.delay']=.5;p.parameters['mixer.delay2']=.5;}));
 on('solo-branch' ,()=>{mixBeforeSolo??=Object.fromEntries(['dry',...branches].map(id=>['mixer.'+id,patch.parameters['mixer.'+id]]));edit(p=>{p.bypass??={};p.bypass[selected]=false;p.mute={};p.solo={};for(const id of ['dry',...branches])p.parameters['mixer.'+id]=id===selected?.65:0;p.nodes={...activeNodes(),sample:activeNodes().sample??coords.sample,mixer:activeNodes().mixer??coords.mixer,out:activeNodes().out??coords.out};const edges:[string,string][]=[[selected,'mixer'],['mixer','out']];if(!p.routes.some(r=>r[1]===selected))edges.unshift(['sample',selected]);for(const edge of edges)if(!p.routes.some(r=>r[0]===edge[0]&&r[1]===edge[1]))p.routes.push(edge);});if(hasBypass()){bypassPending=false;controls.pending.set(20,0);}notify('Rama aislada al 65%. Restaura la mezcla para volver a compararla.');});
 on('restore-mix',()=>{if(mixBeforeSolo){const restore=mixBeforeSolo;mixBeforeSolo=undefined;edit(p=>Object.assign(p.parameters,restore));}});
 on('arrange-parallel',()=>edit(p=>{p.nodes=Object.fromEntries(Object.keys(activeNodes()).map(id=>[id,[...coords[id]] as [number,number]]));}));
 on('new-patch',()=>void (async()=>{if(liveRun)await exitLive();await stop();previousPatch=structuredClone(patch);const blank=defaultPatch();blank.name='Nuevo patch';blank.nodes={};blank.routes=[];blank.modulation=[];blank.parameters['mixer.dry']=1;applyPatch(blank);pendingPort=null;render();notify('Lienzo vacío. Añade Sample In, Mixer y Audio Out desde la biblioteca.');})());
 on('undo-new',()=>{if(previousPatch){const restore=previousPatch;previousPatch=undefined;applyPatch(restore);render();}});
 on('remove-node',()=>edit(p=>{p.nodes={...activeNodes()};delete p.nodes[selected];p.routes=p.routes.filter(r=>!r.includes(selected));if(p.bypass)delete p.bypass[selected];p.modulation=p.modulation.filter(([a,b])=>a!==selected&&!b.startsWith(selected+'.'));}));
 on('reset-patch',()=>{applyPatch(defaultPatch());render();});
 on('add-mod',()=>{const a=(document.querySelector('#mod-source') as HTMLSelectElement).value,b=(document.querySelector('#mod-target') as HTMLSelectElement).value;edit(p=>{p.nodes={...activeNodes(),[a]:activeNodes()[a]??coords[a]};p.modulation.push([a,b]);});});
 for(const id of ['scene-name','patch-name']){const el=document.getElementById(id) as HTMLInputElement|null;if(el)el.onchange=()=>edit(p=>{p.name=el.value;});}
 const file=document.querySelector<HTMLInputElement>('#sample-file');if(file)file.onchange=()=>{if(file.files?.[0])void loadFile(file.files[0]);};
 const imp=document.querySelector<HTMLInputElement>('#import-file');if(imp)imp.onchange=()=>{if(imp.files?.[0])void importFile(imp.files[0]);};
 const loop=document.querySelector<HTMLInputElement>('#loop');if(loop)loop.onchange=()=>{looping=loop.checked;transport.setLoop(looping);};
 const output=document.querySelector<HTMLSelectElement>('#output-mode');if(output)output.onchange=()=>void(async()=>{const nextMode=output.value;if(liveRun)await exitLive();mode=nextMode;await stop();render();})();
 const baud=document.querySelector<HTMLSelectElement>('#baud');if(baud)baud.onchange=()=>{baudRate=Number(baud.value);};
 const drop=document.querySelector<HTMLElement>('.sample-deck');if(drop){drop.ondragover=e=>{e.preventDefault();drop.classList.add('dragging');};drop.ondragleave=()=>drop.classList.remove('dragging');drop.ondrop=e=>{e.preventDefault();drop.classList.remove('dragging');const file=e.dataTransfer?.files[0];if(file)void loadFile(file);};}
}
monitor.onend=()=>{position=0;updateStatus();};monitor.onerror=e=>{pauseLive();notify(String(e),true);};
// Keep DOM work out of the serial refill loop; the 200 ms UI timer displays it.
streamer.onStatus=s=>{status=s;};
transport.onProgress=message=>notify(message);
transport.batchControls=()=>deviceControlLink()?controls.batch():[];streamer.onEnd=()=>{pauseLive();position=0;notify('FPGA playback complete.');};streamer.onError=e=>{pauseLive();notify(String(e),true);};
transport.onDisconnect=()=>{connected=false;status=undefined;if(liveRun)void exitLive();void streamer.stop();if(!connecting){notify('Device disconnected.',true);render();}};
render();
init().then(()=>{wasmReady=true;const saved=localStorage.getItem('celeste-patch');if(saved){try{patch=JSON.parse(validate_patch(saved));if(!localStorage.getItem('celeste-encoder-profile-v2')){recommendEncoderBanks(patch);localStorage.setItem('celeste-encoder-profile-v2','1');}patch.parameters={...defaultPatch().parameters,...patch.parameters};}catch{notify('Saved patch was invalid; factory patch loaded.',true);}}persistPatch();render();}).catch(e=>notify(`WASM initialization failed: ${e}`,true));
setInterval(updateStatus,200);
setInterval(()=>{if(connecting)return;if(deviceControlLink()&&!streamer.playing)void controls.service(transport);if(connected&&!streamer.playing)void transport.request(2).then(p=>{status=parseStatus(p.payload);updateStatus();}).catch(e=>notify(String(e),true));},220);

controls.onError=e=>{pauseLive();bypassPending=undefined;notify(String(e),true);};
function refreshControlWidgets(){
 document.querySelectorAll<HTMLInputElement>('[data-param]').forEach(el=>{if(document.activeElement!==el){const key=el.dataset.param!,v=patch.parameters[key];el.value=String(el.tagName==='SELECT'?((key==='glitch.mode'||key==='freeze.hold')?(v>=.5?1:0):Math.min(3,Math.round(v*65535)>>>14)/3):v);}});
 document.querySelectorAll<HTMLElement>('[data-value]').forEach(el=>el.textContent=(el.closest('.hardware-strip')?hardwareValueLabel:componentValueLabel)(el.dataset.value!,patch.parameters[el.dataset.value!]));
 document.querySelectorAll<HTMLElement>('[data-encoder]').forEach(el=>{const key=activeMapping()[el.dataset.encoder!],v=patch.parameters[key];el.querySelector<HTMLElement>('.knob')?.style.setProperty('--turn',`${-135+v*270}deg`);el.setAttribute('aria-valuenow',String(hardwarePercent(v)));el.classList.toggle('physical-active',deviceControls?.online&&Number(el.dataset.encoder!.replace('encoder',''))===deviceControls?.selected+1);});
}
controls.onSnapshot=s=>{
 if(dualDSP()&&!controls.pending.has(22)){patch.bypass??={};bypassNodes.forEach((id,i)=>{patch.bypass![id]=!!(Math.round(s.values[22]*65535)&(1<<i));});}
 const previousMapping=JSON.stringify(activeMapping());
 const bankChanged=encoderBank!==s.bank;encoderBank=s.bank;deviceControls=s;
 document.querySelectorAll<HTMLButtonElement>('[data-bypass]').forEach(el=>{const value=!!patch.bypass?.[el.dataset.bypass!];el.textContent=value?'BYPASS':'FX ON';el.setAttribute('aria-pressed',String(value));el.classList.toggle('active',value);});
 if(hasBypass()){bypass=s.values[20]>.5;if(!controls.pending.has(20))bypassPending=undefined;}
 for(let i=0;i<Math.min(parameterIds.length,s.values.length);i++)if(!controls.pending.has(i))patch.parameters[parameterIds[i]]=s.values[i];
 if(sonicDSP()){for(const [id,key] of Object.entries(sonicParameters))if(!controls.pending.has(Number(id)))patch.parameters[key]=s.values[Number(id)];}
 if(dualDSP()){for(const [id,key] of Object.entries(extraParameters))if(!controls.pending.has(Number(id)))patch.parameters[key]=s.values[Number(id)];}
 for(let i=0;i<8;i++)if(!controls.pending.has(40+s.bank*8+i))bankMapping(patch,s.bank)[`encoder${i+1}`]=hardwareParameters[s.mappings[i]]??'mixer.master';
 refreshControlWidgets();
 persistPatch();if(bankChanged||previousMapping!==JSON.stringify(activeMapping()))render();else updateStatus();
};


controls.onExpansion=(values,levels)=>{
 expansionLevels=levels??[];
 if(!controls.pending.has(65)){patch.bypass??={};[...expandedBranches,'envelope'].forEach((id,i)=>{patch.bypass![id]=!!(values[1]&(1<<i));});}
 for(const [id,key]of Object.entries(expandedParameters))if(!controls.pending.has(Number(id)))patch.parameters[key]=values[Number(id)-64]/65535;
 let changed=false;
 for(const [offset,field]of [[24,'mute'],[25,'solo']] as const)if(!controls.pending.has(64+offset)){
 const next=Object.fromEntries([...audibleBranches,'dry'].map((id,i)=>[id,!!(values[offset]&(1<<i))]));if(JSON.stringify(next)!==JSON.stringify(patch[field]??{})){patch[field]=next;changed=true;}
 }
 if(changed)render();else refreshControlWidgets();persistPatch();
};
