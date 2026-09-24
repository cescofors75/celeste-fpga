import {liveDemoFrame} from '../web/src/live-demo';
import {colors} from '../web/src/model';

const canvas=document.querySelector('canvas')!;
const c=canvas.getContext('2d')!;
const positions:Record<string,[number,number]>={sample:[100,450],glitch:[520,215],delay:[520,365],delay2:[850,365],filter:[520,515],wavefolder:[520,665],vca:[850,665],mixer:[1250,450],out:[1580,450],lfo:[850,215],chaos:[850,515]};
const labels:Record<string,string>={sample:'SAMPLE IN',glitch:'GLITCH',delay:'DELAY 1',delay2:'DELAY 2',filter:'FILTER',wavefolder:'WAVEFOLDER',vca:'VCA',mixer:'MIXER',out:'AUDIO OUT',lfo:'LFO',chaos:'CHAOS'};
const titles=['Todo empieza con una idea.','Una fuente. Dos texturas.','Dos delays. Dos caminos.','Conecta un delay con otro.','Dale movimiento al sonido.','Pequeños fragmentos. Nuevas texturas.'];
const descriptions=['Música ambient original · generada en CELESTE','Filter y Wavefolder en ramas paralelas','Delay 1 y Delay 2 alimentan el Mixer por separado','Una ruta en serie dentro del patch','LFO → VCA · Chaos → Filter','Glitch stutter sobre una base ambient'];
function text(s:string,x:number,y:number,size=24,color='#b9d3df',weight=400){c.fillStyle=color;c.font=`${weight} ${size}px "Segoe UI", Arial, sans-serif`;c.fillText(s,x,y);}
function box(x:number,y:number,w:number,h:number,color:string,fill='#0a1b26',radius=14){c.beginPath();c.roundRect(x,y,w,h,radius);c.fillStyle=fill;c.fill();c.strokeStyle=color;c.lineWidth=2;c.stroke();}
function wire(a:string,b:string,t:number,mod=false){
 const [ax,ay]=positions[a],[bx,by]=positions[b];
 const x1=ax+220,y1=ay+56,x2=bx,y2=by+56;
 const color=colors[a];c.strokeStyle=color;c.lineWidth=mod?2:3;c.globalAlpha=mod?.65:.8;
 c.setLineDash(mod?[7,7]:[]);c.beginPath();c.moveTo(x1,y1);c.bezierCurveTo(x1+75,y1,x2-75,y2,x2,y2);c.stroke();c.setLineDash([]);
 if(!mod)for(let i=0;i<3;i++){const u=(t*.3+i/3)%1,v=1-u;const x=v*v*v*x1+3*v*v*u*(x1+75)+3*v*u*u*(x2-75)+u*u*u*x2;const y=v*v*v*y1+3*v*v*u*y1+3*v*u*u*y2+u*u*u*y2;c.beginPath();c.arc(x,y,4,0,Math.PI*2);c.fillStyle=color;c.fill();}
 c.globalAlpha=1;
}
function wave(id:string,x:number,y:number,t:number,active:boolean){
 c.strokeStyle=colors[id];c.lineWidth=2;c.globalAlpha=active?.85:.22;c.beginPath();
 for(let i=0;i<178;i++){let v=Math.sin(i*.065-t*1.4)*10;
 if(id==='glitch')v=Math.round(Math.sin(i*.2-t)*3)*3;
 if(id==='wavefolder')v=Math.asin(Math.sin(i*.13-t))*8;
 if(id==='chaos')v=(Math.sin(i*.33+t)*Math.cos(i*.137-t))*12;
 if(id==='delay'||id==='delay2')v=Math.sin(i*.18-t*2)*Math.exp(-(i%55)/22)*14;
 if(id==='mixer'||id==='vca')v=Math.sin(i*.09-t)*7;
 i?c.lineTo(x+i,y+v):c.moveTo(x+i,y+v);}
 c.stroke();c.globalAlpha=1;
}
(window as any).renderDemo=(t:number)=>{
 const {patch,scene}=liveDemoFrame(Math.min(t,47.999));
 c.fillStyle='#050e16';c.fillRect(0,0,1920,1080);
 const glow=c.createRadialGradient(1350,430,20,1350,430,1000);glow.addColorStop(0,'#0b2535');glow.addColorStop(1,'#050e16');c.fillStyle=glow;c.fillRect(0,0,1920,1080);
 c.strokeStyle='#112633';c.lineWidth=1;for(let x=40;x<1900;x+=30){c.beginPath();c.moveTo(x,180);c.lineTo(x,810);c.stroke();}for(let y=180;y<810;y+=30){c.beginPath();c.moveTo(40,y);c.lineTo(1880,y);c.stroke();}
 text('C E L E S T E',70,78,42,'#80eaff',600);text('FPGA SYNTH LAB',73,111,16,'#709caf',500);
 text('PARALLEL FABRIC',650,78,32,'#edf9ff',500);
 box(1515,40,335,53,'#244959','#0a1b26',26);text('DEMO VISUAL  /  48 s',1540,74,20,'#9fdcea',600);
 text(titles[scene],70,173,34,'#f1f8fc',600);text(descriptions[scene],70,204,20,'#84adbf');
 const active=new Set(patch.routes.flat());patch.modulation.forEach(([a,b])=>{active.add(a);active.add(b.split('.')[0]);});
 for(const [a,b]of patch.routes)wire(a,b,t);
 for(const [a,b]of patch.modulation)wire(a,b.split('.')[0],t,true);
 for(const [id,[x,y]] of Object.entries(positions)){
  const on=active.has(id),color=colors[id];box(x,y,220,112,on?color:'#24343f',on?'#0a1c28':'#08141d');
  c.beginPath();c.arc(x+19,y+23,4,0,Math.PI*2);c.fillStyle=on?color:'#36505e';c.fill();text(labels[id],x+32,y+29,19,on?color:'#547080',600);
  wave(id,x+20,y+59,t,on);
  let value=id==='sample'?'AMBIENT · ESTÉREO':id==='out'?'DESTINO DEL PATCH':id==='mixer'?'SUMA DE RAMAS':!on?'EN ESPERA':id==='delay'||id==='delay2'?`${(patch.parameters[id+'.time']*(id==='delay'?170.67:85.33)).toFixed(1)} ms`:id==='lfo'?'MODULA VCA':id==='chaos'?'MODULA FILTER':id==='filter'?'LPF · CUTOFF AUTOMATIZADO':id==='wavefolder'?'DRIVE 15 %':id==='vca'?'NIVEL MODULADO':'STUTTER · MEZCLA SUAVE';
  text(value,x+20,y+96,14,on?'#b9d3df':'#49606d');
 }
 // Illustrative paths, not fabricated readings or a recording of hardware telemetry.
 text('Animación ilustrativa del patch · sin telemetría de hardware',70,828,17,'#7496a7');
 const steps=['ORIGEN','TEXTURAS','PARALELO','SERIE','MODULACIÓN','FRAGMENTOS'];
 for(let i=0;i<6;i++){const x=70+i*298;box(x,866,280,66,i===scene?'#68e5eb':'#203641',i===scene?'#12303e':'#091721',8);text(`0${i+1}  ${steps[i]}`,x+18,907,19,i===scene?'#c1fcff':'#617f90',500);c.fillStyle='#63e4ed';c.fillRect(x,929,280*Math.max(0,Math.min(1,(t-i*8)/8)),3);}
 text('Audio: música ambient original · no es una captura del audio procesado por FPGA.',70,990,21,'#bdd2dc');
 text('Diseña rutas. Explora el sonido.',70,1037,24,'#7de6f2',500);text('CELESTE  /  EN DESARROLLO',1470,1037,18,'#779aaa',500);
};
(window as any).renderDemo(0);
