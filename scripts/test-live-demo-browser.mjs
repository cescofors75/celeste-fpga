// UI lifecycle test with a simulated transport. Physical checks are separate.
import {chromium} from '@playwright/test';
import assert from 'node:assert/strict';
const browser=await chromium.launch({headless:true}),page=await browser.newPage();
await page.route(/\/src\/(?:worker-)?transport\.ts/,r=>r.fulfill({contentType:'text/javascript',body:`
export const parseStatus=x=>x;
export class SerialTransport{
 p=new Uint16Array(32);maps=[0,1,4,5,2,3,11,10,13,16,14,17,11,12,15,10];
 s={sampleRate:48000,capacity:8192,fill:0,underruns:0,overruns:0,sampleCounter:0,protocolErrors:0,engineMask:63,routeMask:1,capabilities:2047,running:false};
 async connect(){return {...this.s};}async close(){this.s.running=false;}
 async request(k,b){let payload=new Uint8Array();if(k===2)payload={...this.s};
 if(k===3){const v=new DataView(b.buffer,b.byteOffset,b.byteLength),id=v.getUint16(0,true),value=v.getUint16(2,true);if(id<32)this.p[id]=value;else if(id===32)this.s.routeMask=value;else this.maps[id-40]=value;}
 if(k===5){this.s.running=true;this.s.fill=0;}if(k===6)this.s.running=false;
 if(k===9){payload=new Uint8Array(110);const v=new DataView(payload.buffer);this.p.forEach((x,i)=>v.setUint16(i*2,x,true));payload.set(this.maps.slice(0,8),64);payload[72]=this.s.routeMask;payload[78]=6;}
 return {payload};}
 async audioBatch(chunks){await new Promise(r=>setTimeout(r,20));for(const c of this.batchControls?.()??[])c.receive(await this.request(c.kind,c.payload));if(this.s.running)this.s.sampleCounter+=chunks.reduce((s,c)=>s+c.length/4,0);else this.s.fill+=chunks.reduce((s,c)=>s+c.length/4,0);return {...this.s};}
}` }));
const errors=[];page.on('pageerror',e=>errors.push(String(e)));
try{
 await page.goto('http://127.0.0.1:5173');await page.getByText('Rust / WASM ready',{exact:true}).waitFor();
 await page.locator('#ambient-demo').click();await page.getByText('Demo ambient lista · 48 s estéreo. Pulsa Play; tu patch sigue aplicado.',{exact:true}).waitFor({timeout:30000});
 const file=await page.locator('#filename').innerText();
 await page.locator('#connect').click();await page.getByText('CELESTE connected. Load WAV, select FPGA → PCM5102, then Play.',{exact:true}).waitFor();
 const original=await page.evaluate(()=>localStorage.getItem('celeste-patch'));
 await page.locator('#live-demo').click();await page.getByText('DEMO LIVE · rutas y controles enviados a la FPGA.',{exact:true}).waitFor({timeout:30000});
 await page.locator('#live-demo-stage').filter({hasText:'serie'}).waitFor({timeout:30000});
 assert.equal(await page.locator('[data-flow-from="delay"][data-flow-to="delay2"]').count(),1);
 await page.locator('#live-demo-pause').click();const stage=await page.locator('#live-demo-stage').innerText();
 await page.waitForTimeout(700);assert.equal(await page.locator('#live-demo-stage').innerText(),stage);assert.match(await page.locator('#play').innerText(),/Playing/);
 assert.equal(await page.evaluate(()=>localStorage.getItem('celeste-patch')),original,'Demo must not overwrite saved patch');
 await page.locator('#live-demo-exit').click();await page.getByText('Demo finalizada. Patch y fuente originales restaurados; reproducción detenida.',{exact:true}).waitFor();
 assert.equal(await page.locator('#filename').innerText(),file);assert.equal(await page.evaluate(()=>localStorage.getItem('celeste-patch')),original);
 assert(await page.locator('#live-demo-panel').isHidden());assert.equal(await page.locator('#play').innerText(),'▶ Play');
 // Second start followed by STOP must pause the score as well as audio.
 await page.locator('#live-demo').click();await page.getByText('DEMO LIVE · rutas y controles enviados a la FPGA.',{exact:true}).waitFor({timeout:30000});
 await page.locator('#stop').click();assert.match(await page.locator('#live-demo-stage').innerText(),/PAUSA/);
 await page.locator('#live-demo-exit').click();assert.deepEqual(errors,[]);
 console.log('PASS simulated transport: live topology progression, pause with audio, STOP, original audio/patch restore, repeat start, no persistence overwrite');
}catch(e){console.error(await page.locator('#notice').innerText(),errors);throw e;}finally{await browser.close();}
