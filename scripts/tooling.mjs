import {spawnSync} from 'node:child_process';
import {existsSync,mkdirSync} from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
process.chdir(root);
const win=process.platform==='win32',env={...process.env};
const inheritedPath=Object.entries(env).find(([k])=>k.toUpperCase()==='PATH')?.[1]??'';
for(const k of Object.keys(env))if(k.toUpperCase()==='PATH')delete env[k];
env.PATH=inheritedPath;
if(win&&existsSync('C:/msys64/mingw64/bin/gcc.exe')){
 env.PATH='C:/msys64/mingw64/bin;'+env.PATH;
 env.RUSTUP_TOOLCHAIN='stable-x86_64-pc-windows-gnu';
}
function run(command,args){const r=spawnSync(command,args,{stdio:'inherit',env,shell:false});if(r.error)throw r.error;if(r.status!==0)process.exit(r.status??1);}
const task=process.argv[2];
if(task==='rust')run('cargo',['test','--manifest-path','rust/Cargo.toml','-p','celeste-core']);
else if(task==='wasm'){
 // Release mode keeps packet CRC/encoding out of the real-time USB budget.
 // Isolate the host proc-macro cache from other MSVC/GNU workspace builds.
 const wasmTarget='build/rust-wasm';
 run('cargo',['build','--release','--target-dir',wasmTarget,'--manifest-path','rust/Cargo.toml','-p','celeste-wasm','--target','wasm32-unknown-unknown']);
 const bundled='build/tools/wasm-bindgen-0.2.100-x86_64-pc-windows-msvc/wasm-bindgen.exe';
 run(win&&existsSync(bundled)?path.resolve(bundled):'wasm-bindgen',[`${wasmTarget}/wasm32-unknown-unknown/release/celeste_wasm.wasm`,'--target','web','--out-dir','web/src/wasm','--out-name','celeste_wasm']);
}else if(task==='rtl'){
 const local=win&&existsSync('C:/msys64/ucrt64/bin/iverilog.exe');
 if(local)env.PATH='C:/msys64/ucrt64/bin;'+env.PATH;
 const compiler=local?'C:/msys64/ucrt64/bin/iverilog.exe':'iverilog';
 const runner=local?'C:/msys64/ucrt64/bin/vvp.exe':'vvp';
 mkdirSync('build/sim',{recursive:true});
 const sources=['fpga/rtl/dsp/expansion_fabric.sv','fpga/rtl/dsp/feedback_matrix4.sv','fpga/rtl/dsp/cellular256.sv','fpga/rtl/dsp/cellular_buffer4.sv','fpga/rtl/dsp/chaos_buffer4.sv','fpga/rtl/audio/i2s_rx_master.sv','fpga/rtl/top/line_in_master_audio.sv','fpga/rtl/audio/audio_mailbox.sv','fpga/rtl/audio/i2s_slave.sv','fpga/rtl/top/line_in_audio.sv','fpga/rtl/audio/sample_fifo.sv','fpga/rtl/audio/sdram_fifo.sv','fpga/rtl/audio/i2s_tx.v','fpga/rtl/top/stream_audio.sv','fpga/rtl/control/protocol_rx.sv','fpga/rtl/control/stream_endpoint.sv','fpga/rtl/control/uart_8n1.sv','fpga/rtl/top/uart_probe.sv'];
 sources.push('fpga/rtl/video/fabric_screen.sv','fpga/reference/video/ui_font.v','fpga/reference/video/st7789_panel.v','fpga/rtl/audio/async_fifo.sv','fpga/rtl/dsp/parallel_fabric.sv','fpga/rtl/control/fabric_registers.sv','fpga/rtl/control/encoder_palette.sv','fpga/rtl/control/touch_input.v');
 for(const name of ['encoder_reset','line_in_master','line_in','palette','fifo','sdram_fifo','display_pipeline','i2s','stream','protocol','protocol_usb_gap','endpoint','wide_status','uart','async','fabric','controls','touch','dsp_i2s','mix_math','audio_transitions','dual_delay','signal_meters','sonic_controls']){
  run(compiler,['-g2012','-s',`tb_${name}`,'-o',`build/sim/${name}.vvp`,...sources,`fpga/sim/tb_${name}.sv`]);
  run(runner,[`build/sim/${name}.vvp`]);
 }
}else throw new Error('Expected rust, wasm, or rtl');
