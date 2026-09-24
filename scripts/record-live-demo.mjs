import {chromium} from '@playwright/test';
import {build} from 'esbuild';
import {writeFile,mkdir} from 'node:fs/promises';
const dir='deliverables/celeste-demo';await mkdir(`${dir}/live-raw`,{recursive:true});
const browser=await chromium.launch({channel:'chrome',headless:false});
const context=await browser.newContext({viewport:{width:1536,height:1080},recordVideo:{dir:`${dir}/live-raw`,size:{width:1536,height:1080}}});
const page=await context.newPage(),video=page.video();
const errors=[];page.on('pageerror',e=>errors.push(String(e)));
try{
 await page.goto('http://127.0.0.1:5173');await page.getByText('Rust / WASM ready',{exact:true}).waitFor();
 await page.addStyleTag({content:'body{zoom:.82}'});
 await page.locator('#connect').press('Enter');
 console.log('SELECT COM14 in Chrome to record real DEMO LIVE.');
 await page.waitForFunction(()=>document.querySelector('#connect').textContent.includes('CONNECTED'),null,{timeout:900000});
 await page.locator('#live-demo').press('Enter');
 await page.getByText('DEMO LIVE · rutas y controles enviados a la FPGA.',{exact:true}).waitFor({timeout:60000});
 const filename=await page.locator('#filename').innerText();const seed=parseInt(filename.match(/([a-f0-9]{8})\.wav/i)[1],16);
 const start=Date.now();console.log('RECORDING',filename);
 await page.screenshot({path:`${dir}/live-web-start.png`});
 const scenes=[];
 for(let n=0;n<12;n++){
  const remaining=start+(n+1)*4000-Date.now();if(remaining>0)await page.waitForTimeout(remaining);
  scenes.push(await page.locator('#live-demo-stage').innerText());
  console.log('CAPTURE',n*4+4,scenes.at(-1));
 }
 const end=Date.now();await page.screenshot({path:`${dir}/live-web-end.png`});
 await page.getByRole('button',{name:'SETTINGS',exact:true}).press('Enter');
 const telemetry=await page.locator('#telemetry').innerText();
 await page.getByRole('button',{name:'PATCH',exact:true}).press('Enter');
 await page.locator('#live-demo-exit').press('Enter');await page.locator('#live-demo-panel').waitFor({state:'hidden'});
 await page.locator('#connect').press('Enter');
 await context.close();const closed=Date.now();const raw=await video.path();
 const bundled=await build({stdin:{contents:"export {ambientWav} from './web/src/ambient.ts'",resolveDir:process.cwd()},bundle:true,write:false,format:'esm',platform:'node'});
 const {ambientWav}=await import('data:text/javascript;base64,'+Buffer.from(bundled.outputFiles[0].text).toString('base64'));
 await writeFile(`${dir}/live-ambient-original.wav`,Buffer.from(ambientWav(seed)));
 await writeFile(`${dir}/live-capture.json`,JSON.stringify({raw,start,end,tailSeconds:(closed-end)/1000,duration:(end-start)/1000,seed,filename,scenes,telemetry,errors},null,2));
 console.log('RECORDED',raw);
}finally{await browser.close();}
