import {describe,it,expect} from 'vitest';
import {componentTests,componentTestPatch} from './component-tester';
import {ControlLink,routeMask} from './control';
import {defaultPatch} from './model';
import {audibleBranches,expandedBranches,expansionMask,performanceMasks} from './expansion';
import {presets,presetPatch} from './presets';
describe('independent expansion and tester',()=>{
 it('creates an isolated audible test without mutating the saved patch',()=>{
  const source=defaultPatch();source.bypass={glitch:true,filter:true};source.mute={filter:true};source.solo={delay:true};const original=structuredClone(source);
  for(const [id]of componentTests){const p=componentTestPatch(id,source);expect(p.mute).toEqual({});expect(p.solo).toEqual({});expect(Object.values(p.bypass??{}).some(Boolean)).toBe(false);expect(p.parameters['mixer.dry']).toBe(0);expect(audibleBranches.filter(b=>p.parameters['mixer.'+b]>0)).toHaveLength(1);expect(()=>routeMask(p,true,true,true)).not.toThrow();}
  expect(source).toEqual(original);
 });
 it('routes all six new components independently and preserves the original delay',()=>{
  const p=defaultPatch();p.routes=[['mixer','out'],['sample','delay'],['delay','mixer'],...expandedBranches.flatMap(b=>[['sample',b],[b,'mixer']] as [string,string][])];
  expect(routeMask(p,true,true,true)).toBe(4);expect(expansionMask(p)).toBe(63);
  const c=new ControlLink();c.expanded=c.extended=c.dual=c.sonic=true;c.queue(p);expect(c.pending.get(64)).toBe(63);expect(c.pending.get(32)).toBe(4);
  p.modulation=[['envelope','vca.level']];expect(()=>routeMask(p,true,true,true)).toThrow(/Envelope/);
 });
 it('keeps mute/solo separate from bypass and gates firmware capabilities',()=>{
  const p=componentTestPatch('glitch',defaultPatch());p.mute={glitch:true};p.solo={chorus:true};expect(performanceMasks(p)).toEqual({mute:1,solo:64});
  const c=new ControlLink();c.extended=c.dual=c.sonic=true;expect(()=>c.queue(p)).toThrow(/firmware/);c.expanded=true;c.queue(p);expect(c.pending.get(88)).toBe(1);expect(c.pending.get(89)).toBe(64);expect(c.pending.get(22)).toBe(0);
 });
 it('builds every expanded preset with valid independent routes and canvas coordinates',()=>{
  for(let i=presets.findIndex(p=>p.name==='Aurora Stereo');i<presets.length;i++){const p=presetPatch(i);const c=new ControlLink();c.expanded=c.extended=c.dual=c.sonic=true;expect(()=>c.queue(p)).not.toThrow();expect(expansionMask(p)).toBeGreaterThan(0);for(const xy of Object.values(p.nodes??{}))expect(xy.every(v=>v>=0&&v<=1090)).toBe(true);}
 });
});
