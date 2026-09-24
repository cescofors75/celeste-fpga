import {describe,it,expect} from 'vitest';
import {liveDemoFrame,LiveDemoClock} from './live-demo';
import {LIVE_SECONDS,LIVE_SECTION_SECONDS,liveScenes} from './live-score';
import {ControlLink,delay2Config} from './control';
import {expandedBranches,audibleBranches,expansionMask} from './expansion';
import {recommendedEncoderKeys} from './model';
describe('long live FPGA arrangement',()=>{
 it.each([false,true])('supports every scene with expanded=%s and bounds mixer gain',expanded=>{
  const c=new ControlLink();c.extended=c.dual=c.sonic=c.banked=true;c.expanded=c.expandedEncoders=expanded;
  for(let t=0;t<LIVE_SECONDS;t+=.25){const {patch:p}=liveDemoFrame(t,expanded);expect(()=>c.queue(p)).not.toThrow();
   const gains=Object.entries(p.parameters).filter(([k])=>k.startsWith('mixer.')&&k!=='mixer.master').reduce((sum,[,v])=>sum+v,0);
   expect(gains*p.parameters['mixer.master']).toBeLessThanOrEqual(.65);
   for(const v of Object.values(p.parameters)){expect(Number.isFinite(v)).toBe(true);expect(v).toBeGreaterThanOrEqual(0);expect(v).toBeLessThanOrEqual(1);}
  }
 });
 it('uses every new effect and both parallel and serial delays',()=>{
  const used=new Set<string>();
  for(let scene=0;scene<12;scene++)liveDemoFrame(scene*LIVE_SECTION_SECONDS+8).patch.routes.flat().forEach(x=>used.add(x));
  for(const id of expandedBranches)expect(used.has(id)).toBe(true);
  expect(delay2Config(liveDemoFrame(5*LIVE_SECTION_SECONDS+8).patch)).toBe(1);
  expect(delay2Config(liveDemoFrame(10*LIVE_SECTION_SECONDS+8).patch)).toBe(3);
  expect(liveDemoFrame(9*LIVE_SECTION_SECONDS+8).patch.modulation).toContainEqual(['envelope','filter.cutoff']);
  expect(expansionMask(liveDemoFrame(0).patch)).toBeGreaterThan(0);
 });
 it('keeps all wet contributions zero at scene boundaries and releases freeze',()=>{
  for(let scene=0;scene<12;scene++){const p=liveDemoFrame(scene*LIVE_SECTION_SECONDS).patch;for(const id of audibleBranches)expect(p.parameters['mixer.'+id]).toBeCloseTo(0,8);}
  expect(liveDemoFrame(6*LIVE_SECTION_SECONDS+8).patch.parameters['freeze.hold']).toBe(1);
  expect(liveDemoFrame(6*LIVE_SECTION_SECONDS+18).patch.parameters['freeze.hold']).toBe(0);
  expect(liveDemoFrame(LIVE_SECONDS)).toEqual(liveDemoFrame(0));expect(liveScenes).toHaveLength(12);
 });
 it('uses the complete two-bank mapping and readable on-screen nodes',()=>{
  for(let scene=0;scene<12;scene++){
   const p=liveDemoFrame(scene*LIVE_SECTION_SECONDS+8).patch;
   expect(Object.values(p.hardware)).toEqual(recommendedEncoderKeys[0]);expect(Object.values(p.hardwareBank1!)).toEqual(recommendedEncoderKeys[1]);
   for(const [a,b] of p.routes){expect(p.nodes![a]).toBeDefined();expect(p.nodes![b]).toBeDefined();}
   for(const [x,y] of Object.values(p.nodes!)){expect(x).toBeGreaterThanOrEqual(0);expect(y).toBeLessThanOrEqual(445);}
  }
 });
 it('pauses, rebases and wraps the sample clock without losing the score',()=>{
  const c=new LiveDemoClock();c.start(0xffff0000);c.advance((0xffff0000+48000)>>>0);expect(c.seconds).toBe(1);
  c.paused=true;c.advance((0xffff0000+96000)>>>0);expect(c.seconds).toBe(1);
  c.paused=false;c.rebase(0);c.advance(48000);expect(c.seconds).toBe(2);
 });
});
