import {describe,it,expect} from 'vitest';
import {ControlLink} from './control';
import {defaultPatch,valueLabel} from './model';
import {presets,presetPatch} from './presets';
describe('sonic engine controls',()=>{
 it('sends new registers only with advertised capability',()=>{
  const p=defaultPatch(),c=new ControlLink();c.extended=c.dual=true;c.queue(p);
  for(const id of [23,28,29,30,31])expect(c.pending.has(id)).toBe(false);
  c.sonic=true;p.parameters['filter.mode']=2/3;p.parameters['glitch.repeats']=7/15;c.queue(p);
  expect(c.pending.get(23)).toBe(65535);expect(c.pending.get(28)).toBe(43690);
  expect(c.pending.get(29)).toBe(65535);expect(c.pending.get(30)).toBe(30583);
 });
 it('exposes the exact hardware buckets and units',()=>{
  expect(valueLabel('glitch.size',1)).toBe('42.7 ms');
  expect(valueLabel('glitch.size',0)).toBe('5.3 ms');
  expect(valueLabel('glitch.repeats',7/15)).toBe('8 rep.');
  expect(valueLabel('filter.mode',2/3)).toMatch(/BPF/);
  expect(valueLabel('filter.mode',1)).toBe('Notch');
  expect(valueLabel('chaos.rate',1)).toBe(valueLabel('lfo.rate',1));
 });
 it('maps new controls to physical encoder IDs and rejects unsupported firmware',()=>{
  const p=defaultPatch(),c=new ControlLink();c.extended=c.dual=true;
  p.hardware.encoder1='filter.mode';expect(()=>c.queue(p)).toThrow();
  c.sonic=true;c.queue(p);expect(c.pending.get(40)).toBe(28);
 });
 it('provides isolated audible presets with explicit active effects',()=>{
  for(const name of ['Stutter Memory','High Pass Air','Band Focus','Notch Sweep','Breathing VCA']){
   const p=presetPatch(presets.findIndex(p=>p.name===name)),c=new ControlLink();c.extended=c.dual=c.sonic=true;
   expect(p.parameters['mixer.dry']).toBe(0);expect(Object.values(p.bypass??{}).every(v=>!v)).toBe(true);
   c.queue(p);expect(c.pending.get(22)).toBe(0);expect(c.pending.get(32)).toBeGreaterThan(1);
  }
 });
});
