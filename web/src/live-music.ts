import {LIVE_BPM,LIVE_FRAMES,LIVE_RATE,LIVE_SECTION_SECONDS} from './live-score';
// Original procedural composition. Synthesized in the worker, then passed to
// the real FPGA as audio. No sampled recordings or emulated FPGA effects.
export function liveMusicWav(seed:number,progress:(percent:number)=>void=()=>{}):ArrayBuffer{
 const sr=LIVE_RATE,frames=LIVE_FRAMES,beat=60/LIVE_BPM,bar=beat*4;
 const l=new Float32Array(frames),r=new Float32Array(frames);
 let state=seed>>>0;
 const random=()=>{state=(Math.imul(state,1664525)+1013904223)>>>0;return state/4294967296;};
 const hz=(m:number)=>440*2**((m-69)/12);
 const smooth=(x:number)=>{x=Math.max(0,Math.min(1,x));return x*x*(3-2*x);};
 function note(start:number,duration:number,midi:number,amp:number,pan:number,kind:'pad'|'bell'|'bass'){
  const offset=Math.round(start*sr),count=Math.min(Math.ceil(duration*sr),frames-offset);
  const f=hz(midi),lg=Math.sqrt((1-pan)/2)*amp,rg=Math.sqrt((1+pan)/2)*amp;
  const phase=random()*Math.PI*2,step=2*Math.PI*f/sr;
  for(let i=0;i<count;i++){
   const t=i/sr,attack=kind==='pad'?2.2:kind==='bell'?.008:.006,release=kind==='pad'?3.5:kind==='bell'?.8:.055;
   const env=smooth(t/attack)*smooth((duration-t)/release);
   const a=i*step;
   const sound=kind==='pad'?(Math.sin(a+phase)*.62+Math.sin(a*1.0013+phase+.4)*.23+Math.sin(a*2)*.10+Math.sin(a*3)*.05)
    :kind==='bell'?(Math.sin(a)*.78+Math.sin(a*2.003)*.17*Math.exp(-t*3)+Math.sin(a*4.01)*.05*Math.exp(-t*5))*Math.exp(-t/1.4)
    :(Math.sin(a)*.88+Math.sin(2*a)*.09+Math.sin(3*a)*.03);
   l[offset+i]+=sound*env*lg;r[offset+i]+=sound*env*rg;
  }
 }
 function drum(start:number,kind:'kick'|'snare'|'hat'|'ride',amp:number,pan:number){
  const duration=kind==='kick'?.28:kind==='snare'?.19:kind==='ride'?.3:.065;
  const offset=Math.round(start*sr),count=Math.min(Math.ceil(duration*sr),frames-offset);
  const lg=Math.sqrt((1-pan)/2)*amp,rg=Math.sqrt((1+pan)/2)*amp;
  let phase=0,low=0,previous=0;
  for(let i=0;i<count;i++){
   const t=i/sr,noise=random()*2-1;
   low+=.16*(noise-low);const high=noise-previous;previous=noise;
   phase+=2*Math.PI*(kind==='kick'?48+108*Math.exp(-t*55):kind==='snare'?178:5400)/sr;
   const attack=smooth(t/.0008),release=smooth((duration-t)/.012);
   const value=kind==='kick'?Math.sin(phase)*Math.exp(-t*18)+high*.045*Math.exp(-t*250)
    :kind==='snare'?(noise-low)*.56*Math.exp(-t*27)+Math.sin(phase)*.3*Math.exp(-t*35)
    :kind==='ride'?high*.22*Math.exp(-t*15)+Math.sin(phase)*.055*Math.exp(-t*20)
    :high*.25*Math.exp(-t*80);
   l[offset+i]+=value*attack*release*lg;r[offset+i]+=value*attack*release*rg;
  }
 }
 const harmonies=[[50,57,60,64,69],[43,53,57,62,65],[46,53,57,60,65],[41,53,57,60,67],[52,58,62,65,69],[45,55,59,62,64],[50,57,60,64,67],[48,55,59,62,67]];
 const intensity=[0,.45,.76,.65,.9,.84,.08,1,.92,.78,.63,0];
 for(let section=0;section<12;section++){
  const start=section*LIVE_SECTION_SECONDS,energy=intensity[section];
  for(let phrase=0;phrase<2;phrase++){
   const notes=harmonies[(section*2+phrase)%harmonies.length],at=start+phrase*8*bar;
   notes.forEach((m,i)=>note(at+i*.045,8*bar+2,m,.065+(section===6?.02:0),(i-2)*.32,'pad'));
   for(let b=0;b<8;b++){
    const atBar=at+b*bar,globalBar=section*16+phrase*8+b;
    if(energy>.1){
     const root=notes[0]-12;
     note(atBar,beat*.78,root,.23*energy,0,'bass');
     note(atBar+beat*1.75,beat*.60,root,.19*energy,0,'bass');
     note(atBar+beat*2.75,beat*.85,root+(b%4===3?7:0),.20*energy,0,'bass');
     const kicks=b%4===3?[0,5.5,10,14.5]:b%2?[0,7,10.5]:[0,6.5,10];
     for(const step of kicks)drum(atBar+step*beat/4,'kick',.4*energy,0);
     for(const step of [4,12])drum(atBar+step*beat/4+.003,'snare',.27*energy*(.94+random()*.12),.03);
     for(const step of [3,10.5,15])if(random()<.65)drum(atBar+step*beat/4,'snare',.062*energy,random()*.3-.15);
     for(let step=0;step<16;step++){
      if(step%2&&random()>.55)continue;
      drum(atBar+step*beat/4+(step%2?.008:0),'hat',energy*(step%2?.09:.145),step%4<2?-.35:.4);
     }
     if(globalBar%4===0)drum(atBar,'ride',.1*energy,.6);
     if(b===7&&section!==1)for(const step of [13.5,14.5,15.5])drum(atBar+step*beat/4,'snare',.09*energy,.1);
    }
    if(b%2===0||random()<.35){
     const melody=notes[(b+section)%notes.length]+12,pan=random()*1.3-.65;
     note(atBar+beat*(b%3===0?.5:2.5),3.5,melody,.058,pan,'bell');
     // Quiet composed answer, independent of the hardware delay branches.
     if(b%4===0)note(atBar+beat*3.25,3,melody+7,.029,-pan,'bell');
    }
   }
  }
  progress(Math.round((section+1)/12*85));
 }
 // Gentle whole-piece fades yield a silent loop seam; preserve drum transients.
 let dcL=0,dcR=0;for(let i=0;i<frames;i++){dcL+=l[i];dcR+=r[i];}
 dcL/=frames;dcR/=frames;
 let peak=0;
 for(let i=0;i<frames;i++){
  const fade=smooth(i/(sr*3))*smooth((frames-1-i)/(sr*6));
  l[i]=(l[i]-dcL)*fade;r[i]=(r[i]-dcR)*fade;
  peak=Math.max(peak,Math.abs(l[i]),Math.abs(r[i]));
 }
 const gain=peak?.68/peak:0,wav=new ArrayBuffer(44+frames*4),v=new DataView(wav);
 const text=(at:number,s:string)=>{for(let i=0;i<s.length;i++)v.setUint8(at+i,s.charCodeAt(i));};
 text(0,'RIFF');v.setUint32(4,wav.byteLength-8,true);text(8,'WAVEfmt ');v.setUint32(16,16,true);
 v.setUint16(20,1,true);v.setUint16(22,2,true);v.setUint32(24,sr,true);v.setUint32(28,sr*4,true);
 v.setUint16(32,4,true);v.setUint16(34,16,true);text(36,'data');v.setUint32(40,frames*4,true);
 for(let i=0;i<frames;i++){v.setInt16(44+i*4,Math.round(l[i]*gain*32767),true);v.setInt16(46+i*4,Math.round(r[i]*gain*32767),true);}
 progress(100);return wav;
}
