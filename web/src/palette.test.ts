import {describe,it,expect} from 'vitest';
import {colors,parameterColor,defaultPatch,bankMapping} from './model';

describe('shared encoder colors',()=>{
 it('uses the effect color for mix controls and new parameters',()=>{
  for(const module of ['glitch','delay','delay2','filter','wavefolder','vca']){
   expect(parameterColor(`mixer.${module}`)).toBe(colors[module]);
   expect(parameterColor(`${module}.amount`)).toBe(colors[module]);
  }
  expect(parameterColor('mixer.master')).toBe(colors.mixer);
  expect(parameterColor('mixer.dry')).toBe(colors.mixer);
  expect(parameterColor('chaos.speed')).toBe('#aa71ff');
 });
 it('resolves both default encoder banks',()=>{
  const patch=defaultPatch();
  for(const bank of [0,1] as const)
   for(const parameter of Object.values(bankMapping(patch,bank)))
    expect(parameterColor(parameter)).toMatch(/^#[0-9a-f]{6}$/);
 });
});
