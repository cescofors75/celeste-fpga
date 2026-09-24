import {it,expect} from 'vitest';
import {liveMusicWav} from './live-music';
import {LIVE_FRAMES,LIVE_RATE,LIVE_SECONDS,LIVE_SECTION_SECONDS} from './live-score';
it('renders the complete arrangement with headroom, stereo, development and a silent seam',()=>{
 const progress:number[]=[],bytes=liveMusicWav(12345,p=>progress.push(p)),v=new DataView(bytes);
 expect(bytes.byteLength).toBe(44+LIVE_FRAMES*4);expect(LIVE_SECONDS).toBeGreaterThan(270);
 expect(v.getUint16(22,true)).toBe(2);expect(v.getUint32(24,true)).toBe(LIVE_RATE);
 let peak=0,dcL=0,dcR=0,difference=0;
 const energies=Array(12).fill(0),counts=Array(12).fill(0);
 for(let i=0;i<LIVE_FRAMES;i++){
  const l=v.getInt16(44+i*4,true),r=v.getInt16(46+i*4,true);
  peak=Math.max(peak,Math.abs(l),Math.abs(r));dcL+=l;dcR+=r;difference+=(l-r)**2;
  const section=Math.min(11,Math.floor(i/LIVE_RATE/LIVE_SECTION_SECONDS));energies[section]+=l*l+r*r;counts[section]+=2;
 }
 expect(peak).toBeLessThanOrEqual(22282);expect(peak).toBeGreaterThan(22270);
 expect(Math.abs(dcL/LIVE_FRAMES)).toBeLessThan(5);expect(Math.abs(dcR/LIVE_FRAMES)).toBeLessThan(5);
 expect(Math.sqrt(difference/LIVE_FRAMES)/32768).toBeGreaterThan(.015);
 const rms=energies.map((e,i)=>Math.sqrt(e/counts[i])/32768);
 expect(rms[7]).toBeGreaterThan(rms[0]*1.1);expect(Math.min(...rms)).toBeGreaterThan(.01);
 for(const offset of [44,46,44+(LIVE_FRAMES-1)*4,46+(LIVE_FRAMES-1)*4])expect(v.getInt16(offset,true)).toBe(0);
 expect(progress.at(-1)).toBe(100);
},120000);
