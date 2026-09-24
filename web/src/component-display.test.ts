import {it,expect} from 'vitest';
import {componentValueLabel} from './model';
it('shows the same hardware percentage and effective delay together',()=>{
 expect(componentValueLabel('delay.time',57592/65535)).toBe('87% · 150.0 ms');
 expect(componentValueLabel('delay.feedback',45875/65535)).toBe('69% · 35%');
 expect(componentValueLabel('glitch.mode',1)).toBe('Stutter');
});
