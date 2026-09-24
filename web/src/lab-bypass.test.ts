import {it,expect} from 'vitest';
import {ControlLink,supportsControlSnapshots} from './control';
it('services bypass and acknowledges both states on Chaos Lab without legacy DSP capability',async()=>{
 const capabilities=24592;
 expect(capabilities&2).toBe(0);expect(supportsControlSnapshots(capabilities)).toBe(true);
 expect(supportsControlSnapshots(1)).toBe(false);
 const c=new ControlLink(),seen:number[]=[];let bypass=0;
 const transport={close:async()=>{},request:async(kind:number,payload?:Uint8Array)=>{
  if(kind===3){const v=new DataView(payload!.buffer,payload!.byteOffset,payload!.byteLength);expect(v.getUint16(0,true)).toBe(20);bypass=v.getUint16(2,true);seen.push(bypass);return {kind:131,sequence:0,payload:new Uint8Array()};}
  expect(kind).toBe(9);const b=new Uint8Array(110);new DataView(b.buffer).setUint16(40,bypass,true);return {kind:137,sequence:0,payload:b};
 }};
 let confirmed=-1;c.onSnapshot=s=>{confirmed=s.values[20];};
 for(const value of [65535,0]){c.pending.set(20,value);if(supportsControlSnapshots(capabilities))await c.service(transport,true);expect(c.pending.size).toBe(0);expect(confirmed).toBe(value/65535);}
 expect(seen).toEqual([65535,0]);
});
