import {build} from 'esbuild';
import {chromium} from '@playwright/test';
import {readFile,writeFile,mkdir} from 'node:fs/promises';
import {spawn} from 'node:child_process';
import {once} from 'node:events';
const dir='deliverables/celeste-demo';await mkdir(dir,{recursive:true});
const bundled=await build({stdin:{contents:"export {liveDemoFrame} from './web/src/live-demo.ts'",resolveDir:process.cwd()},bundle:true,write:false,format:'esm',platform:'node'});
const {liveDemoFrame}=await import('data:text/javascript;base64,'+Buffer.from(bundled.outputFiles[0].text).toString('base64'));
const browser=await chromium.launch({headless:true});
const page=await browser.newPage({viewport:{width:1536,height:1080},deviceScaleFactor:1});
const errors=[];page.on('pageerror',e=>errors.push(String(e)));
const photo=(await readFile(`${dir}/hdmi-hardware.png`)).toString('base64');
const rail=await browser.newPage({viewport:{width:384,height:1080},deviceScaleFactor:1});
await rail.setContent(`<html lang="es"><meta charset="utf-8"><style>*{box-sizing:border-box}body{margin:0;background:#07151e;color:#b9d3df;font:20px 'Segoe UI',sans-serif;padding:42px 24px;height:1080px;border-left:1px solid #284450}h1{color:#80eaff;font-size:33px;letter-spacing:7px;margin:0 0 8px}small{font-size:15px;color:#719dad}.photo{margin-top:45px;padding:8px;border:1px solid #31596a;background:#10232e}.photo img{width:100%;display:block}.photo p{font-size:16px;margin:10px 3px 3px}.steps{margin-top:35px;font-size:21px;line-height:2.05}.steps b{color:#6bdde9;margin-right:12px;font-weight:400}.note{position:absolute;bottom:85px;width:336px;font-size:18px;line-height:1.55;color:#b0c5d0}.foot{position:absolute;bottom:28px;font-size:15px;color:#709baa}</style><h1>CELESTE</h1><small>FPGA SYNTH LAB · DEMO WEB</small><div class="photo"><img src="data:image/png;base64,${photo}"><p>HDMI · foto del hardware</p></div><div class="steps"><b>01</b> Fuente ambient<br><b>02</b> Filter + Wavefolder<br><b>03</b> Delays en paralelo<br><b>04</b> Delays en serie<br><b>05</b> LFO + Chaos<br><b>06</b> Glitch stutter</div><div class="note">Interfaz real de CELESTE.<br>Vista previa sin conexión.<br><br>Música ambient original.<br>No es una captura del audio procesado por FPGA.</div><div class="foot">PROYECTO EN DESARROLLO</div></html>`);
await rail.screenshot({path:`${dir}/web-video-sidebar.png`});await rail.close();
async function scene(n){
 const {patch,label}=liveDemoFrame(n*8+4);patch.name=`DEMO ${n+1}/6 · ${label}`;
 if(n===0)await page.addInitScript(p=>localStorage.setItem('celeste-patch',JSON.stringify(p)),patch);
 // Replace the init script by using a fresh page for subsequent scenes.
 else await page.evaluate(p=>localStorage.setItem('celeste-patch',JSON.stringify(p)),patch);
 if(n===0)await page.goto('http://127.0.0.1:5173');
 else {
  // Import through the application's UI, preserving its actual rendering/validation.
  await page.getByRole('button',{name:'PRESETS',exact:true}).press('Enter');
  await page.locator('#import-file').setInputFiles({name:'demo.json',mimeType:'application/json',buffer:Buffer.from(JSON.stringify(patch))});
  await page.getByText('Patch imported.',{exact:true}).waitFor();
  await page.getByRole('button',{name:'PATCH',exact:true}).press('Enter');
 }
 await page.getByText('Rust / WASM ready',{exact:true}).waitFor();
 if(n===0){await page.locator('#sample-file').setInputFiles(`${dir}/ambient-original.wav`);await page.getByText('Ready · ambient-original.wav · converted by Rust/WASM',{exact:true}).waitFor({timeout:30000});}
 const ids=['sample','filter','delay','delay2','lfo','glitch'];
 await page.locator(`[data-node="${ids[n]}"]`).press('Enter');
 await page.evaluate(()=>document.fonts.ready);
}
try{
 await scene(0);await page.screenshot({path:`${dir}/web-video-preview.png`});
 if(!process.argv.includes('--preview')){
  const ff=spawn('ffmpeg',['-hide_banner','-loglevel','warning','-y','-f','image2pipe','-framerate','24','-vcodec','mjpeg','-i','pipe:0','-loop','1','-i',`${dir}/web-video-sidebar.png`,'-i',`${dir}/ambient-original.wav`,'-filter_complex','[0:v]pad=1920:1080:0:0:color=0x07151e[base];[base][1:v]overlay=1536:0:shortest=1[out]','-map','[out]','-map','2:a:0','-c:v','libx264','-preset','medium','-crf','19','-pix_fmt','yuv420p','-c:a','aac','-b:a','192k','-af','afade=t=in:d=1.5,afade=t=out:st=45:d=3','-t','48','-movflags','+faststart',`${dir}/CELESTE-demo-WEB-HDMI-1080p.mp4`],{stdio:['pipe','inherit','inherit']});
  const done=once(ff,'close');
  for(let n=0;n<6;n++){
   if(n)await scene(n);
   for(let i=0;i<192;i++){
    await page.evaluate(t=>{for(const a of document.getAnimations()){a.pause();a.currentTime=t;}},(n*8+i/24)*1000);
    const frame=await page.screenshot({type:'jpeg',quality:92});
    if(!ff.stdin.write(frame))await once(ff.stdin,'drain');
   }
   console.log(`Captured real web scene ${n+1}/6`);
  }
  ff.stdin.end();const [code]=await done;if(code!==0)throw new Error('FFmpeg failed '+code);
  if(errors.length)throw new Error(errors.join('\n'));
  console.log('PASS: six real web scenes, 48 seconds, original ambient music, no page errors');
 }
}finally{await browser.close();}
