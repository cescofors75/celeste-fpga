import {expect,it} from 'vitest';
import {nodeMeter,wireLevel,signalActive,meterPercent} from './signal';
it('shows all parallel inputs even when branch mixer gains are zero',()=>{
 const m=Array(15).fill(0);m[0]=.1;m[8]=.09;m[10]=.001;
 for(const id of ['glitch','delay','filter','wavefolder','vca','delay2'])expect(signalActive(wireLevel('sample',id,m,false))).toBe(true);
 expect(signalActive(wireLevel('filter','mixer',m,false))).toBe(false);
 expect(m[nodeMeter('filter',true)!]).toBe(.001);
});
it('shows a real cascade with no direct Delay 1 mix contribution',()=>{
 const m=Array(15).fill(0);m[9]=.02;m[13]=.01;m[14]=.005;
 expect(wireLevel('delay','delay2',m,false)).toBe(.02);
 expect(wireLevel('delay','mixer',m,false)).toBe(0);
 expect(wireLevel('delay2','mixer',m,false)).toBe(.005);
 expect(nodeMeter('delay2',true)).toBe(13);
});
it('never substitutes another branch for missing telemetry',()=>{
 expect(wireLevel('delay','delay2',Array(8).fill(.5),false)).toBeUndefined();
 expect(wireLevel('delay2','mixer',Array(8).fill(.5),false)).toBeUndefined();
 expect(wireLevel('filter','mixer',Array(15).fill(.5),true)).toBeUndefined();
 expect(signalActive(undefined)).toBe(false);expect(signalActive(0)).toBe(false);
 expect(signalActive(8/32768)).toBe(true);expect(meterPercent(8/32768)).toBeGreaterThan(0);
});
