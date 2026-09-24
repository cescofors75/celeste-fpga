import {chromium} from '@playwright/test';
import {readFile,writeFile} from 'node:fs/promises';
import {spawnSync} from 'node:child_process';
const dir='deliverables/celeste-demo';
const meta=JSON.parse(await readFile(`${dir}/live-capture.json`,'utf8'));
const probe=spawnSync('ffprobe',['-v','error','-show_entries','format=duration','-of','json',meta.raw],{encoding:'utf8'});
if(probe.status!==0)throw new Error(probe.stderr);
const duration=Number(JSON.parse(probe.stdout).format.duration),start=Math.max(0,duration-meta.tailSeconds-meta.duration);
const photo=(await readFile(`${dir}/hdmi-hardware.png`)).toString('base64');
const browser=await chromium.launch({headless:true});
try{
 const page=await browser.newPage({viewport:{width:384,height:1080}});
 await page.setContent(`<html lang="es"><meta charset="utf-8"><style>*{box-sizing:border-box}body{margin:0;background:#07151e;color:#b9d3df;font:20px 'Segoe UI',sans-serif;padding:42px 24px;height:1080px;border-left:1px solid #284450}h1{color:#80eaff;font-size:33px;letter-spacing:7px;margin:0 0 8px}small{font-size:16px;color:#67e8b0}.photo{margin-top:40px;padding:8px;border:1px solid #31596a;background:#10232e}.photo img{width:100%;display:block}.photo p{font-size:16px;margin:10px 3px 3px}.steps{margin-top:28px;font-size:20px;line-height:2}.steps b{color:#6bdde9;margin-right:12px;font-weight:400}.note{position:absolute;bottom:76px;width:336px;font-size:17px;line-height:1.55;color:#b0c5d0}.foot{position:absolute;bottom:28px;font-size:14px;color:#709baa}</style><h1>CELESTE</h1><small>● DEMO LIVE · FPGA CONECTADA</small><div class="photo"><img src="data:image/png;base64,${photo}"><p>HDMI · foto del hardware</p></div><div class="steps"><b>01</b> Fuente ambient<br><b>02</b> Filter + Wavefolder<br><b>03</b> Delays en paralelo<br><b>04</b> Delays en serie<br><b>05</b> LFO + Chaos<br><b>06</b> Glitch stutter</div><div class="note">Grabación de la web real.<br>Medidores de la FPGA.<br>Ondas de módulos ilustrativas.<br><br>Audio: fuente ambient original.<br>No es una captura de la salida procesada por FPGA.</div><div class="foot">FPGA SYNTH LAB · EN DESARROLLO</div></html>`);
 await page.screenshot({path:`${dir}/live-sidebar.png`});
}finally{await browser.close();}
const args=['-hide_banner','-loglevel','warning','-y','-ss',String(start),'-i',meta.raw,'-loop','1','-i',`${dir}/live-sidebar.png`,'-i',`${dir}/live-ambient-original.wav`,'-filter_complex','[0:v]pad=1920:1080:0:0:color=0x07151e[base];[base][1:v]overlay=1536:0:shortest=1[out]','-map','[out]','-map','2:a:0','-c:v','libx264','-preset','medium','-crf','18','-pix_fmt','yuv420p','-c:a','aac','-b:a','192k','-af','afade=t=in:d=1.5,afade=t=out:st=45:d=3','-t','48','-movflags','+faststart',`${dir}/CELESTE-DEMO-LIVE-web-HDMI.mp4`];
const result=spawnSync('ffmpeg',args,{stdio:'inherit'});if(result.status!==0)throw new Error('Encoding failed');
await writeFile(`${dir}/live-edit.json`,JSON.stringify({rawDuration:duration,trimStart:start,outputDuration:48},null,2));
console.log('Created CELESTE-DEMO-LIVE-web-HDMI.mp4');
