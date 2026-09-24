import {chromium} from '@playwright/test';
import assert from 'node:assert/strict';
const browser=await chromium.launch({headless:true});
const page=await browser.newPage({viewport:{width:1536,height:1200}});
const errors=[];page.on('pageerror',e=>errors.push(String(e)));
async function verify(expected){
 const actual=await page.locator('[data-encoder]').evaluateAll(els=>els.map(e=>e.style.getPropertyValue('--accent')));
 assert.deepEqual(actual,expected);
 const mini=await page.locator('.mini-values b').evaluateAll(els=>els.map(e=>getComputedStyle(e).color));
 const encoder=await page.locator('[data-encoder]').evaluateAll(els=>els.map(e=>getComputedStyle(e).getPropertyValue('--accent')));
 for(let i=0;i<8;i++){
  const hex=encoder[i].slice(1);const rgb=[0,2,4].map(n=>parseInt(hex.slice(n,n+2),16));
  assert.equal(mini[i],`rgb(${rgb.join(', ')})`);
 }
}
try{
 await page.goto('http://127.0.0.1:5173');await page.getByText('Rust / WASM ready',{exact:true}).waitFor();
 await verify(['#ff527c','#ff527c','#ffa53d','#ffa53d','#35a8ff','#35a8ff','#00dfa2','#b9d3df']);
 await page.locator('[data-bank="1"]').press('Enter');
 await verify(['#fa66bf','#fa66bf','#ac78ff','#ac78ff','#00dfa2','#00dfa2','#aa71ff','#b9d3df']);
 await page.locator('.hardware-strip').screenshot({path:'build/palette-bank1-strip.png'});
 await page.getByRole('button',{name:'HARDWARE',exact:true}).press('Enter');
 await page.locator('[data-map="encoder1"]').selectOption('mixer.delay2');
 await verify(['#5bcfff','#fa66bf','#ac78ff','#ac78ff','#00dfa2','#00dfa2','#aa71ff','#b9d3df']);
 await page.locator('[data-map="encoder2"]').selectOption('mixer.glitch');
 await verify(['#5bcfff','#ff527c','#ac78ff','#ac78ff','#00dfa2','#00dfa2','#aa71ff','#b9d3df']);
 await page.locator('[data-bank="0"]').first().press('Enter');
 await verify(['#ff527c','#ff527c','#ffa53d','#ffa53d','#35a8ff','#35a8ff','#00dfa2','#b9d3df']);
 assert.deepEqual(errors,[]);
 console.log('PASS browser: bank 0/1, effect mix remapping, mini display colors, no page errors');
}finally{await browser.close();}
