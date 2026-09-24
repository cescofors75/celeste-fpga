import {it,expect} from 'vitest';
import {ambientWav,AMBIENT_RATE,AMBIENT_SECONDS} from './ambient';
it('renders a stereo ambient source with headroom, no DC and a continuous loop seam',()=>{
 const bytes=ambientWav(12345),v=new DataView(bytes),frames=AMBIENT_RATE*AMBIENT_SECONDS;
 expect(new TextDecoder().decode(bytes.slice(0,4))).toBe('RIFF');
 expect(v.getUint16(22,true)).toBe(2);expect(v.getUint32(24,true)).toBe(48000);
 expect(v.getUint32(40,true)).toBe(frames*4);expect(bytes.byteLength).toBe(44+frames*4);
 let peak=0,sumL=0,sumR=0,energy=0,difference=0;
 for(let i=0;i<frames;i++){
  const l=v.getInt16(44+i*4,true),r=v.getInt16(46+i*4,true);
  peak=Math.max(peak,Math.abs(l),Math.abs(r));sumL+=l;sumR+=r;energy+=l*l+r*r;difference+=(l-r)**2;
 }
 expect(peak).toBeLessThanOrEqual(18023);expect(peak).toBeGreaterThan(18000);
 expect(Math.abs(sumL/frames)).toBeLessThan(1);expect(Math.abs(sumR/frames)).toBeLessThan(1);
 expect(Math.sqrt(energy/(2*frames))/32768).toBeGreaterThan(.04);
 expect(Math.sqrt(difference/frames)/32768).toBeGreaterThan(.01);
 for(let channel=0;channel<2;channel++)expect(Math.abs(v.getInt16(44+channel*2,true)-v.getInt16(44+(frames-1)*4+channel*2,true))).toBeLessThan(1000);
},30000);
