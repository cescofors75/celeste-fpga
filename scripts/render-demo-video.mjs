import {build} from 'esbuild';
import {chromium} from '@playwright/test';
import {mkdir,writeFile} from 'node:fs/promises';
import {spawn} from 'node:child_process';
import {once} from 'node:events';
const dir='deliverables/celeste-demo';await mkdir(dir,{recursive:true});
const audio=await build({stdin:{contents:"export {ambientWav} from './web/src/ambient.ts'",resolveDir:process.cwd()},bundle:true,write:false,format:'esm',platform:'node'});
const {ambientWav}=await import('data:text/javascript;base64,'+Buffer.from(audio.outputFiles[0].text).toString('base64'));
await writeFile(`${dir}/ambient-original.wav`,Buffer.from(ambientWav(20260921)));
const js=await build({entryPoints:['scripts/demo-video-renderer.ts'],bundle:true,write:false,format:'iife',platform:'browser'});
const html=`<!doctype html><html lang="es"><meta charset="utf-8"><title>CELESTE · Demo visual</title><style>body{margin:0;background:#050e16}canvas{display:block;width:100vw;height:auto}</style><canvas width="1920" height="1080" aria-label="Demo visual de Parallel Fabric"></canvas><script>${js.outputFiles[0].text}</script></html>`;
await writeFile(`${dir}/preview.html`,html);
const browser=await chromium.launch({headless:true});const page=await browser.newPage({viewport:{width:1920,height:1080}});
try{
 await page.setContent(html);await page.evaluate(()=>document.fonts.ready);
 for(const t of [4,12,20,28,36,44]){await page.evaluate(t=>window.renderDemo(t),t);await page.screenshot({path:`${dir}/scene-${t}.png`});}
 if(!process.argv.includes('--preview')){
  const ff=spawn('ffmpeg',['-hide_banner','-loglevel','warning','-y','-f','image2pipe','-framerate','24','-vcodec','mjpeg','-i','pipe:0','-i',`${dir}/ambient-original.wav`,'-map','0:v:0','-map','1:a:0','-c:v','libx264','-preset','medium','-crf','19','-pix_fmt','yuv420p','-c:a','aac','-b:a','192k','-af','afade=t=in:d=1.5,afade=t=out:st=45:d=3','-t','48','-movflags','+faststart',`${dir}/CELESTE-demo-visual-1080p.mp4`],{stdio:['pipe','inherit','inherit']});
  const completion=once(ff,'close');
  for(let frame=0;frame<48*24;frame++){
   const data=await page.evaluate(t=>{window.renderDemo(t);return document.querySelector('canvas').toDataURL('image/jpeg',.94).split(',')[1];},frame/24);
   if(!ff.stdin.write(Buffer.from(data,'base64')))await once(ff.stdin,'drain');
   if(frame%192===0)console.log(`Rendered ${frame/24}/48 seconds`);
  }
  ff.stdin.end();const [code]=await completion;if(code!==0)throw new Error('FFmpeg failed: '+code);
  console.log('Created '+dir+'/CELESTE-demo-visual-1080p.mp4');
 }
}finally{await browser.close();}
