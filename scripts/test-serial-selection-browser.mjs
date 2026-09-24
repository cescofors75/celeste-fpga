// Real browser workers + transferable streams; fake devices with identical USB IDs.
import {chromium} from '@playwright/test';
import assert from 'node:assert/strict';
const browser=await chromium.launch({headless:true});
try{
 const page=await browser.newPage();await page.goto('http://127.0.0.1:5173');
 const result=await page.evaluate(async()=>{
  const {SerialTransport}=await import('/src/worker-transport.ts');
  let wrongOpened=0,opened=0,closed=0,selected=0,cancelled=0;
  let badIdentity=false;let output;const info={usbVendorId:0x1234,usbProductId:0x5678};
  function packet(kind,sequence,payload){
   const out=new Uint8Array(payload.length+12),v=new DataView(out.buffer);
   out.set([67,69,1,kind|128]);v.setUint32(4,sequence,true);v.setUint16(8,payload.length,true);out.set(payload,10);
   let crc=65535;for(const byte of out.subarray(2,-2)){crc^=byte<<8;for(let j=0;j<8;j++)crc=((crc<<1)^((crc&32768)?0x1021:0))&65535;}
   v.setUint16(out.length-2,crc,true);return out;
  }
  const wrong={getInfo:()=>info,open:async()=>{wrongOpened++;throw Error('Wrong device opened');}};
  const chosen={getInfo:()=>info,readable:null,writable:null,open:async()=>{
   opened++;chosen.readable=new ReadableStream({start(c){output=c;},cancel(){cancelled++;}});
   chosen.writable=new WritableStream({write(bytes){
    const v=new DataView(bytes.buffer,bytes.byteOffset,bytes.byteLength),kind=bytes[3];
    let payload=new Uint8Array();
    if(kind===1)payload=new TextEncoder().encode(badIdentity?'OTHER/1':'CELESTE/1');
    if(kind===2){payload=new Uint8Array(32);const s=new DataView(payload.buffer);s.setUint32(0,48000,true);s.setUint16(4,8192,true);}
    output.enqueue(packet(kind,v.getUint32(4,true),payload));
   }});
  },close:async()=>{if(chosen.readable.locked||chosen.writable.locked)throw Error('Port streams still locked');closed++;}};
  Object.defineProperty(navigator,'serial',{configurable:true,value:{getPorts:async()=>[wrong,chosen],requestPort:async()=>{selected++;return chosen;}}});
  const t=new SerialTransport();
  const first=await t.connect(3000000);await t.close();
  const second=await t.connect(3000000);await t.close();
  badIdentity=true;let identity='';try{await t.connect(3000000);}catch(e){identity=String(e);}
  chosen.open=async()=>{throw Error('Selected port is busy');};
  let busy='';try{await t.connect(3000000);}catch(e){busy=String(e);}
  return {wrongOpened,opened,closed,selected,cancelled,rates:[first.sampleRate,second.sampleRate],busy,identity};
 });
 assert.equal(result.wrongOpened,0);assert.equal(result.opened,3);assert.equal(result.closed,3);
 assert.equal(result.cancelled,3);assert.equal(result.selected,4);assert.deepEqual(result.rates,[48000,48000]);assert.match(result.busy,/busy/);assert.match(result.identity,/not CELESTE/);
 console.log('PASS duplicate USB IDs: exact selected device, worker handshake, stream cleanup, reconnect, busy selected port never falls back to another device',result);
}finally{await browser.close();}
