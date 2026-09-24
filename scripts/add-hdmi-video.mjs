import {spawnSync} from 'node:child_process';
const dir='deliverables/celeste-demo';
const filter="[1:v]scale=360:270,setsar=1[photo];[0:v]drawbox=x=1478:y=123:w=384:h=318:color=0x081923:t=fill,drawbox=x=1478:y=123:w=384:h=318:color=0x427486:t=2[base];[base][photo]overlay=x=1490:y=135:shortest=1,drawtext=fontfile='C\\:/Windows/Fonts/segoeui.ttf':text='HDMI · foto del hardware':x=1500:y=412:fontsize=19:fontcolor=0xb9d3df[out]";
const args=['-hide_banner','-loglevel','warning','-y','-i',`${dir}/CELESTE-demo-visual-1080p.mp4`,'-loop','1','-i',`${dir}/hdmi-hardware.png`,'-filter_complex',filter,'-map','[out]','-map','0:a:0','-c:v','libx264','-preset','medium','-crf','19','-pix_fmt','yuv420p','-c:a','copy','-t','48','-movflags','+faststart',`${dir}/CELESTE-demo-con-HDMI-1080p.mp4`];
const r=spawnSync('ffmpeg',args,{stdio:'inherit'});if(r.error)throw r.error;process.exit(r.status??1);
