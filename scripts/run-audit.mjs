// Aggregate every exit status. A later success cannot hide an earlier failure.
import {spawnSync} from 'node:child_process';
import {mkdirSync,writeFileSync} from 'node:fs';
mkdirSync('build/audio-audit',{recursive:true});
const tasks=[['build'],['test'],['run','test:rust'],['run','test:rtl'],['run','test:audio']];
// Browser checks need the dev server; physical UART testing is explicitly separate.
if(process.argv.includes('--browser'))tasks.push(['run','test:browser']);
const results=[];
for(const args of tasks){
 const command=args[0]==='build'?['run','build']:args;
 const name=command.join('-');console.log(`\nAUDIT ${command.join(' ')}`);
 const began=Date.now();
 const r=process.platform==='win32'?spawnSync('cmd.exe',['/d','/s','/c',`npm.cmd ${command.join(' ')}`],{encoding:'utf8',maxBuffer:16*1024*1024}):spawnSync('npm',command,{encoding:'utf8',maxBuffer:16*1024*1024});
 const output=(r.stdout??'')+(r.stderr??'')+(r.error?String(r.error):'');
 writeFileSync(`build/audio-audit/${name}.log`,output);console.log(output);
 results.push({task:command.join(' '),passed:r.status===0,exitCode:r.status,seconds:(Date.now()-began)/1000});
}
writeFileSync('build/audio-audit/suite.json',JSON.stringify({timestamp:new Date().toISOString(),results,analog:'NOT MEASURED',physical:'Run hardware scripts separately; see docs/AUDIO_AUDIT.md'},null,2));
console.table(results);process.exit(results.every(r=>r.passed)?0:1);
