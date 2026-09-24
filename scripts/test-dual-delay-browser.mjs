import {chromium} from '@playwright/test';
import assert from 'node:assert/strict';
const browser=await chromium.launch({headless:true});
const page=await browser.newPage({viewport:{width:1536,height:1024}});
const errors=[];page.on('pageerror',e=>errors.push(String(e)));
try{
 await page.goto('http://127.0.0.1:5173');await page.getByText('Rust / WASM ready',{exact:true}).waitFor();
 await page.locator('[data-select="delay"]').click();await page.locator('#duplicate-delay').click();
 assert.equal(await page.locator('[data-node="delay2"]').count(),1);
 await page.locator('#delays-parallel').click();
 let p=JSON.parse(await page.evaluate(()=>localStorage.getItem('celeste-patch')));
 assert(p.routes.some(r=>r.join(',')==='sample,delay2'));assert(p.routes.some(r=>r.join(',')==='delay,mixer'));
 await page.locator('[data-bypass="delay"]').click();assert.equal(await page.locator('[data-bypass="delay"]').getAttribute('aria-pressed'),'true');
 await page.locator('[data-select="delay2"]').click();await page.locator('#delays-series').click();
 p=JSON.parse(await page.evaluate(()=>localStorage.getItem('celeste-patch')));
 assert(p.routes.some(r=>r.join(',')==='delay,delay2'));assert(!p.routes.some(r=>r.join(',')==='sample,delay2'));assert(!p.routes.some(r=>r.join(',')==='delay,mixer'));
 await page.locator('#solo-branch').click();p=JSON.parse(await page.evaluate(()=>localStorage.getItem('celeste-patch')));assert.equal(p.parameters['mixer.delay2'],.65);assert(p.routes.some(r=>r.join(',')==='delay,delay2'));assert(!p.routes.some(r=>r.join(',')==='sample,delay2'));await page.locator('#restore-mix').click();
 await page.getByRole('slider',{name:'delay2.time',exact:true}).fill('0.7');
 await page.reload();await page.getByText('Rust / WASM ready',{exact:true}).waitFor();
 await page.locator('[data-select="delay2"]').click();assert.equal(await page.getByRole('slider',{name:'delay2.time',exact:true}).inputValue(),'0.7');
 assert.equal(await page.locator('[data-bypass="delay"]').getAttribute('aria-pressed'),'true');
 await page.screenshot({path:'build/dual-delay-browser.png',fullPage:true});
 await page.locator('#remove-node').click();p=JSON.parse(await page.evaluate(()=>localStorage.getItem('celeste-patch')));assert(!p.routes.some(r=>r.includes('delay2')));
 assert.deepEqual(errors,[]);console.log('PASS duplicate Delay, parallel/series, component bypass, independent controls, persistence and removal using real WASM');
}finally{await browser.close();}
