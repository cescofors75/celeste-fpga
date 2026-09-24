import {describe,it,expect} from 'vitest';
import {hardwarePercent,hardwareValueLabel,valueLabel} from './model';
describe('FPGA display parity',()=>{
 it('matches HDL truncation and full scale',()=>{
  for(const [raw,percent] of [[0,0],[32768,50],[48889,74],[65273,99],[65534,99],[65535,100]])expect(hardwarePercent(raw/65535)).toBe(percent);
 });
 it('distinguishes register feedback from physical gain',()=>{
  expect(hardwareValueLabel('delay.feedback',1)).toBe('100%');
  expect(valueLabel('delay.feedback',1)).toBe('50%');
 });
 it('keeps discrete modes readable like hardware',()=>{
  expect(hardwareValueLabel('glitch.mode',1)).toBe('Stutter');
  expect(hardwareValueLabel('glitch.size',0)).toBe('5.3 ms');
 });
});
