import {describe,it,expect} from 'vitest';
import {ControlLink,decodeControls,routeMask,delay2Config} from './control';
import {defaultPatch} from './model';
describe('FPGA control bridge',()=>{
 it('decodes all 15 v6 meters without shifting original controls',()=>{const b=new Uint8Array(110),v=new DataView(b.buffer);b[78]=6;v.setUint16(98,8000,true);v.setUint16(106,12000,true);v.setUint16(108,6000,true);const s=decodeControls(b);expect(s.values).toHaveLength(32);expect(s.meters).toHaveLength(15);expect(s.meters?.[9]).toBe(8000/32768);expect(s.meters?.[13]).toBe(12000/32768);expect(s.meters?.[14]).toBe(6000/32768);});
 it('maps real dual delay topology, independent controls and per-node bypass',()=>{
  const p=defaultPatch(),c=new ControlLink();c.extended=true;c.dual=true;
  p.routes=[['sample','delay'],['delay','delay2'],['delay2','mixer'],['mixer','out']];p.bypass={delay:true,chaos:true};
  p.parameters['delay2.time']=.75;c.queue(p);
  expect(c.pending.get(27)).toBe(3);expect(c.pending.get(32)).toBe(0);expect(c.pending.get(22)).toBe(130);expect(c.pending.get(24)).toBe(Math.round(.75*65535));
  p.routes=[['sample','delay'],['delay','mixer'],['sample','delay2'],['delay2','mixer'],['mixer','out']];c.queue(p);
  expect(c.pending.get(27)).toBe(1);expect(c.pending.get(32)).toBe(4);
  p.routes.push(['delay','delay2']);expect(()=>delay2Config(p)).toThrow();
 });
 it('rejects new operations on old firmware and impossible chains on new firmware',()=>{
  const p=defaultPatch(),c=new ControlLink();c.extended=true;p.bypass={filter:true};expect(()=>c.queue(p)).toThrow(/nuevo firmware/);
  p.routes.push(['filter','delay2']);expect(()=>routeMask(p,true,true)).toThrow();
 });
 it('decodes snapshot v5 while preserving bank and meter offsets',()=>{
  const b=new Uint8Array(96),v=new DataView(b.buffer);v.setUint16(48,43210,true);b[64]=14;b[72]=4;b[73]=31;v.setUint32(74,4321,true);b[78]=5;v.setUint16(94,16384,true);
  const s=decodeControls(b);expect(s.values).toHaveLength(32);expect(s.values[24]).toBeCloseTo(43210/65535);expect(s.mappings[0]).toBe(14);expect(s.bank).toBe(1);expect(s.routes).toBe(4);expect(s.revision).toBe(4321);expect(s.meters?.[7]).toBe(.5);
 });
 it('keeps bank selection separate from encoder index',()=>{const b=new Uint8Array(80);b[57]=31;const s=decodeControls(b);expect(s.bank).toBe(1);expect(s.selected).toBe(7);expect(s.online).toBe(true);});
 it('queues independent mappings for both banks only on capable firmware',()=>{const p=defaultPatch(),c=new ControlLink();c.extended=true;c.queue(p);expect(c.pending.has(48)).toBe(false);c.banked=true;c.queue(p);expect(c.pending.get(40)).toBe(0);expect(c.pending.get(48)).toBe(13);expect(c.pending.get(54)).toBe(15);p.hardwareBank1!.encoder1='vca.level';c.queue(p);expect(c.pending.get(48)).toBe(14);expect(c.pending.get(40)).toBe(0);});
 it('decodes measured input, branch and output levels',()=>{const b=new Uint8Array(80),v=new DataView(b.buffer);v.setUint16(64,16384,true);v.setUint16(78,32768,true);const s=decodeControls(b);expect(s.values).toHaveLength(24);expect(s.meters?.[0]).toBe(.5);expect(s.meters?.[7]).toBe(1);});
 it('routes expanded effects and independent modulation targets',()=>{const c=new ControlLink(),p=defaultPatch();c.extended=true;p.routes=[['sample','wavefolder'],['wavefolder','mixer'],['sample','vca'],['vca','mixer'],['mixer','out']];p.modulation=[['lfo','vca.level'],['chaos','filter.cutoff']];c.queue(p);expect(c.pending.get(32)).toBe(48);expect(c.pending.get(18)).toBe(2);expect(c.pending.get(19)).toBe(1);expect(()=>new ControlLink().queue(p)).toThrow();});
 it('decodes expanded snapshot without truncating new mappings or route bits',()=>{const b=new Uint8Array(64),v=new DataView(b.buffer);v.setUint16(34,50000,true);b[48]=17;b[56]=63;b[57]=15;v.setUint32(58,1234,true);const s=decodeControls(b);expect(s.values).toHaveLength(24);expect(s.values[17]).toBeCloseTo(50000/65535);expect(s.mappings[0]).toBe(17);expect(s.routes).toBe(63);expect(s.selected).toBe(7);expect(s.revision).toBe(1234);});
 it('maps only realizable parallel routes',()=>{const p=defaultPatch();expect(routeMask(p)).toBe(15);p.routes=p.routes.filter(r=>r.join(',')!=='delay,mixer');expect(routeMask(p)).toBe(11);p.routes.push(['glitch','filter']);expect(()=>routeMask(p)).toThrow();});
 it('coalesces rapid edits and bounds controls in an audio window',()=>{const c=new ControlLink(),p=defaultPatch();c.queue(p);p.parameters['filter.cutoff']=.9;c.queue(p);expect(c.pending.get(4)).toBe(Math.round(.9*65535));const batch=c.batch();expect(batch.filter(p=>p.kind===3)).toHaveLength(2);});
 it('decodes actual encoder values, mapping, online flag and revision',()=>{const b=new Uint8Array(48),v=new DataView(b.buffer);v.setUint16(8,32768,true);b[32]=4;b[40]=7;b[41]=11;v.setUint32(42,1234,true);const s=decodeControls(b);expect(s.values[4]).toBeCloseTo(.5,4);expect(s.mappings[0]).toBe(4);expect(s.online).toBe(true);expect(s.selected).toBe(5);expect(s.revision).toBe(1234);});
});
