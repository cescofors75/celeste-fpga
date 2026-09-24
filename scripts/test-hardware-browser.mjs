// Real Web Serial and real FPGA. No transport mocks. Board must be prepared.
import {chromium} from '@playwright/test';
import assert from 'node:assert/strict';
import {writeFile} from 'node:fs/promises';
const frames=480000,wav=Buffer.alloc(44+frames*4);
wav.write('RIFF');wav.writeUInt32LE(wav.length-8,4);wav.write('WAVEfmt ',8);wav.writeUInt32LE(16,16);wav.writeUInt16LE(1,20);wav.writeUInt16LE(2,22);wav.writeUInt32LE(48000,24);wav.writeUInt32LE(192000,28);wav.writeUInt16LE(4,32);wav.writeUInt16LE(16,34);wav.write('data',36);wav.writeUInt32LE(frames*4,40);
// Silence allows repeated transport tests without repeated audible tones.
await writeFile('build/test-hardware-10s.wav',wav);
const browser=await chromium.launch({channel:'chrome',headless:false});
const page=await browser.newPage({viewport:{width:1536,height:1024}});
const errors=[];page.on('pageerror',e=>errors.push(String(e)));
try{
 await page.goto('http://127.0.0.1:5173');await page.getByText('Rust / WASM ready',{exact:true}).waitFor();
 console.log('Choose COM14 in the Chrome serial-port dialog. You have two minutes.');
 await page.locator('#connect').click();await page.waitForFunction(()=>document.querySelector('#connect').textContent.includes('CONNECTED'),undefined,{timeout:120000});
 async function status(){await page.getByRole('button',{name:'SETTINGS',exact:true}).click();return JSON.parse((await page.locator('#telemetry').innerText()).split('\n\nCONTROLS')[0]);}
 const before=await status();assert.equal(before.sampleRate,48000);
 await page.getByRole('button',{name:'PATCH',exact:true}).click();
 if(process.argv.includes('--dual')){
  assert(before.capabilities&256,'Dual-delay firmware required');
  await page.locator('[data-select="delay"]').click();await page.locator('#duplicate-delay').click();
  await page.locator('#delays-parallel').click();
  async function checkRegisters(topology,bypass){
   await page.getByRole('button',{name:'SETTINGS',exact:true}).click();
   await page.waitForFunction(({topology,bypass})=>{
    const raw=document.querySelector('#telemetry').textContent.split('\n\nCONTROLS\n')[1];if(!raw)return false;
    const s=JSON.parse(raw);return Math.round(s.values[27]*65535)===topology&&Math.round(s.values[22]*65535)===bypass;
   },{topology,bypass},{timeout:15000});
   await page.getByRole('button',{name:'PATCH',exact:true}).click();
  }
  await checkRegisters(1,0);
  await page.locator('[data-bypass="delay"]').click();await checkRegisters(1,2);
  await page.locator('[data-select="delay2"]').click();await page.locator('#delays-series').click();await checkRegisters(3,2);
  await page.locator('[data-bypass="delay"]').click();await checkRegisters(3,0);
  console.log('PASS real browser controls: parallel, series, component bypass and FPGA register readback');
 }
 await page.locator('#sample-file').setInputFiles('build/test-hardware-10s.wav');await page.getByText('Ready · test-hardware-10s.wav · converted by Rust/WASM',{exact:true}).waitFor();
 await page.locator('#output-mode').selectOption('fpga');await page.locator('#loop').uncheck();await page.locator('#play').click();
 await page.getByText('FPGA playback complete.',{exact:true}).waitFor({timeout:20000});
 const after=await status();assert.equal(after.sampleCounter-before.sampleCounter,frames);
 for(const key of ['underruns','overruns','protocolErrors'])assert.equal(after[key],before[key],key);
 await page.screenshot({path:'build/browser-hardware.png',fullPage:true});
 assert.deepEqual(errors,[]);
 console.log('PASS real browser WAV -> Rust/WASM -> Web Serial -> FPGA, 480000 frames',JSON.stringify(after));
 await page.locator('#connect').click();
}catch(e){console.error('UI',await page.locator('#notice').innerText(),await page.locator('#connect').innerText());await page.screenshot({path:'build/hardware-browser-failure.png'});throw e;}finally{await browser.close();}
