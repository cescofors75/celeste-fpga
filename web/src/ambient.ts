// Offline source synthesis. Runs in the audio worker, not in the FPGA DSP path.
export const AMBIENT_RATE=48000;
export const AMBIENT_SECONDS=48;
export function ambientWav(seed:number):ArrayBuffer{
 const rate=AMBIENT_RATE,frames=rate*AMBIENT_SECONDS;
 const left=new Float32Array(frames),right=new Float32Array(frames);
 let state=seed>>>0;
 const random=()=>{state=(Math.imul(state,1664525)+1013904223)>>>0;return state/4294967296;};
 const hz=(midi:number)=>440*2**((midi-69)/12);
 // Dm9 → Bbmaj9 → Fmaj9 → Csuspended. Twelve seconds per harmony.
 const chords=[[50,57,60,64,69],[46,53,57,60,65],[41,53,57,60,67],[48,55,62,65,67]];
 function voice(start:number,duration:number,midi:number,amplitude:number,pan:number,bell=false){
  const count=Math.round(duration*rate),offset=Math.round(start*rate);
  const frequency=hz(midi),phase=random()*Math.PI*2,detune=1+(random()-.5)*.004;
  const step=2*Math.PI*frequency/rate,lg=Math.sqrt((1-pan)/2)*amplitude,rg=Math.sqrt((1+pan)/2)*amplitude;
  for(let i=0;i<count;i++){
   const t=i/rate,remaining=duration-t;
   const attack=Math.min(1,t/(bell?.012:2.8)),release=Math.min(1,remaining/(bell?1.5:4));
   const envelope=attack*attack*(3-2*attack)*release*release*(3-2*release)*(bell?Math.exp(-t/1.5):1);
   const angle=i*step;
   const value=bell
    ? (Math.sin(angle)*.7+Math.sin(angle*2.003)*.2*Math.exp(-t*1.4)+Math.sin(angle*3.997)*.1*Math.exp(-t*2))
    : (Math.sin(angle+phase)*.6+Math.sin(angle*detune+phase)*.25+Math.sin(angle*2+phase)*.1+Math.sin(angle*3+phase)*.05);
   const n=(offset+i)%frames;
   left[n]+=value*envelope*lg;right[n]+=value*envelope*rg;
  }
 }
 for(let chord=0;chord<4;chord++){
  const notes=chords[chord],start=chord*12;
  notes.forEach((note,i)=>voice(start+i*.07,16,note,.12,(i-2)*.32));
  voice(start,15,notes[0]-12,.12,0);
  for(let beat=0;beat<8;beat++){
   if(beat!==0&&random()<.2)continue;
   voice(start+beat*1.5,5,notes[(beat+chord)%notes.length]+12,.055+random()*.025,(random()-.5)*1.5,true);
  }
 }
 // Circular, cross-channel early reflections: tails wrap into the start of
 // the loop. Read immutable dry buffers, so the result is stable and bounded.
 const dryL=left.slice(),dryR=right.slice();
 const taps=[[.313,.23],[.619,.17],[1.127,.12],[1.739,.08]];
 for(const [seconds,gain] of taps){
  const delay=Math.round(seconds*rate);
  for(let i=0;i<frames;i++){const j=(i-delay+frames)%frames;left[i]+=dryR[j]*gain;right[i]+=dryL[j]*gain;}
 }
 let dcL=0,dcR=0;
 for(let i=0;i<frames;i++){dcL+=left[i];dcR+=right[i];}
 dcL/=frames;dcR/=frames;
 let peak=0;
 for(let i=0;i<frames;i++)peak=Math.max(peak,Math.abs(left[i]-dcL),Math.abs(right[i]-dcR));
 const gain=peak?0.55/peak:0;
 const wav=new ArrayBuffer(44+frames*4),v=new DataView(wav);
 const text=(at:number,s:string)=>{for(let i=0;i<s.length;i++)v.setUint8(at+i,s.charCodeAt(i));};
 text(0,'RIFF');v.setUint32(4,wav.byteLength-8,true);text(8,'WAVEfmt ');v.setUint32(16,16,true);
 v.setUint16(20,1,true);v.setUint16(22,2,true);v.setUint32(24,rate,true);v.setUint32(28,rate*4,true);
 v.setUint16(32,4,true);v.setUint16(34,16,true);text(36,'data');v.setUint32(40,frames*4,true);
 for(let i=0;i<frames;i++){
  v.setInt16(44+i*4,Math.round((left[i]-dcL)*gain*32767),true);
  v.setInt16(46+i*4,Math.round((right[i]-dcR)*gain*32767),true);
 }
 return wav;
}
