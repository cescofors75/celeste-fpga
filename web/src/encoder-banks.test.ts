import {describe,it,expect} from 'vitest';
import {ControlLink,decodeControls,hardwareParameters} from './control';
import {defaultPatch,recommendEncoderBanks,migrateEncoderBanks,hardwareValueLabel,parameterColor} from './model';
describe('expanded physical encoder banks',()=>{
 it('allocates all sixteen slots without duplicate controls',()=>{const p=recommendEncoderBanks(defaultPatch());const keys=[...Object.values(p.hardware),...Object.values(p.hardwareBank1!)];expect(new Set(keys).size).toBe(16);expect(keys).toContain('freeze.hold');expect(keys.at(-1)).toBe('mixer.master');for(const k of keys){expect(Object.values(hardwareParameters)).toContain(k);expect(parameterColor(k)).toMatch(/^#[0-9a-f]{6}$/);}});
 it('writes real expanded parameter IDs, preserving both banks',()=>{const p=recommendEncoderBanks(defaultPatch()),c=new ControlLink();Object.assign(c,{extended:true,dual:true,sonic:true,banked:true,expanded:true,expandedEncoders:true});c.queue(p);expect(Array.from({length:16},(_,i)=>c.pending.get(40+i))).toEqual([0,2,24,4,13,14,12,15,67,70,72,75,79,82,84,10]);});
 it('rejects new physical mappings on the earlier expansion firmware',()=>{const c=new ControlLink();Object.assign(c,{extended:true,dual:true,sonic:true,banked:true,expanded:true});expect(()=>c.queue(recommendEncoderBanks(defaultPatch()))).toThrow(/not supported/);});
 it('decodes 7-bit IDs without moving bank or meter fields',()=>{const b=new Uint8Array(110);b.set([67,70,72,75,79,82,84,10],64);b[73]=17;const c=decodeControls(b);expect(c.bank).toBe(1);expect(c.mappings).toEqual([67,70,72,75,79,82,84,10]);});
 it('migrates factory mappings and preserves explicitly customized presets',()=>{const p=defaultPatch();migrateEncoderBanks(p);expect(p.hardware.encoder3).toBe('delay2.time');const custom=defaultPatch();custom.hardware.encoder1='filter.resonance';migrateEncoderBanks(custom);expect(custom.hardware.encoder1).toBe('filter.resonance');});
 it('uses the same Freeze labels as HDMI',()=>{expect(hardwareValueLabel('freeze.hold',0)).toBe('CAPTURE');expect(hardwareValueLabel('freeze.hold',1)).toBe('HOLD');});
});
