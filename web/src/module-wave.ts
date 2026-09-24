// Decorative module signatures, never a reconstruction of FPGA samples.
export function moduleWave(id:string):string {
 const points=Array.from({length:161},(_,i)=>{
  const x=i*1.5,p=x/120*Math.PI*2;
  let y=Math.sin(p)*10;
  if(id==='glitch')y=Math.round(Math.sin(p*4)*3)*3;
  else if(id==='wavefolder')y=Math.asin(Math.sin(p*3))*7;
  else if(id==='chaos')y=(Math.sin(p*7)*Math.cos(p*3)+Math.sin(p*13)*.25)*9;
  else if(id==='delay'||id==='delay2')y=Math.sin(p*4)*(1+Math.cos(p))*5;
  else if(id==='filter')y=Math.sin(p)*8+Math.sin(p*2)*2;
  else if(id==='mixer'||id==='out')y=Math.sin(p)*7+Math.sin(p*3)*2;
  return `${i?'L':'M'}${x.toFixed(1)},${(18-y).toFixed(1)}`;
 }).join(' ');
 return `<div class="module-wave" data-module-wave="${id}" role="img" aria-label="Onda ilustrativa de ${id}; no es una medición de audio" title="Onda ilustrativa · los medidores inferiores muestran los picos reales"><svg viewBox="0 0 240 36" preserveAspectRatio="none" aria-hidden="true"><path d="${points}"/></svg></div>`;
}
