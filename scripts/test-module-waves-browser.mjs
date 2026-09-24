import {chromium} from '@playwright/test';
import assert from 'node:assert/strict';
const browser=await chromium.launch({headless:true});
const page=await browser.newPage({viewport:{width:1600,height:1200}});
const errors=[];page.on('pageerror',e=>errors.push(String(e)));
try{
 await page.goto('http://127.0.0.1:5173');await page.getByText('Rust / WASM ready',{exact:true}).waitFor();
 assert.equal(await page.locator('[data-module-wave]').count(),await page.locator('[data-node]').count());
 const wave=page.locator('[data-module-wave="glitch"] svg');
 const transform=()=>wave.evaluate(el=>getComputedStyle(el).transform);
 const before=await transform();await page.waitForTimeout(200);assert.notEqual(await transform(),before);
 await page.locator('[data-bypass="glitch"]').press('Enter');
 assert.equal(await wave.evaluate(el=>getComputedStyle(el).animationPlayState),'paused');
 const stopped=await transform();await page.waitForTimeout(200);assert.equal(await transform(),stopped);
 await page.locator('[data-bypass="glitch"]').press('Enter');
 assert.equal(await wave.evaluate(el=>getComputedStyle(el).animationPlayState),'running');
 const overflow=await page.locator('[data-node]').evaluateAll(nodes=>nodes.flatMap(node=>{
  const outer=node.getBoundingClientRect();
  return [...node.querySelectorAll('.module-wave,.node-value,.branch-state')].filter(el=>el.getBoundingClientRect().bottom>outer.bottom).map(el=>node.dataset.node+':'+el.className);
 }));assert.deepEqual(overflow,[],'Waveforms and values must fit inside their nodes');
 await page.locator('.graph-stage').screenshot({path:'build/module-waves-graph.png'});
 await page.emulateMedia({reducedMotion:'reduce'});
 assert.equal(await wave.evaluate(el=>getComputedStyle(el).animationName),'none');
 assert.deepEqual(errors,[]);
 console.log('PASS: animated signatures, bypass freeze/resume, reduced motion, node bounds, no page errors');
}finally{await browser.close();}
