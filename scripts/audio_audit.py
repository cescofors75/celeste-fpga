"""Deterministic audio measurements against the actual synthesizable RTL.

Requires numpy and Icarus Verilog. No analog claims are inferred from simulation.
Run --baseline to retain known failures without a nonzero exit (report still FAIL).
"""
from pathlib import Path
import argparse, hashlib, json, os, subprocess, sys, time
import numpy as np

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / 'build/audio-audit'
RATE = 48000

def main():
    ap = argparse.ArgumentParser(); ap.add_argument('--baseline', action='store_true'); args = ap.parse_args()
    OUT.mkdir(parents=True, exist_ok=True); os.chdir(ROOT)
    cases = []
    def add(name, x, params=None, routes=1, **meta):
        p = [0]*32; p[6] = p[10] = 65535
        for k,v in (params or {}).items(): p[k] = v
        x = np.asarray(x, dtype=np.int64)
        if x.ndim == 1: x = np.column_stack((x, -x))
        x = np.clip(x, -32768, 32767)
        cases.append(dict(name=name, x=x, p=p, routes=routes, **meta))
    ramp = np.linspace(-32768, 32767, 1024).astype(np.int64)
    sine = lambda f,n=2048,a=6000: np.rint(a*np.sin(2*np.pi*f*np.arange(n)/RATE)).astype(np.int64)
    for label,route,gain in [('dry',1,6),('glitch',2,7),('delay',4,8),('filter',8,9),('wavefolder',16,16),('vca',32,17)]:
        add('silence_'+label,np.zeros(256),{6:0,gain:65535,14:65535,13:65535,0:65535,1:65535,4:65535,5:65535},route,kind='silence')
    add('dry_ramp',ramp,kind='dry')
    add('bypass_ramp',ramp,{20:65535},63,kind='bypass')
    for gain in [0,16384,32768,65535]:
        add('vca_'+str(gain),ramp,{6:0,14:gain,17:65535},32,kind='vca',gain=gain)
    for drive in [0,16384,32768,65535]:
        add('wavefolder_'+str(drive),ramp,{6:0,13:drive,16:65535},16,kind='fold',drive=drive)
    edges = np.tile(np.array([30000,-30000,32767,-32768,16000,-16000,0,1234]),128)
    add('glitch_probability_zero',edges,{6:0,7:65535,0:65535,1:0},2,kind='glitch_zero')
    add('glitch_full_hold',edges,{6:0,7:65535,0:65535,1:65535},2,kind='glitch_hold')
    for length in [1,257,8192]:
        impulse = np.zeros(length+16,dtype=np.int64);impulse[0]=12000
        add('delay_'+str(length),impulse,{6:0,8:65535,2:(length-1)*8},4,kind='delay',length=length)
    impulse=np.zeros(1050,dtype=np.int64);impulse[0]=12000
    add('delay_feedback',impulse,{6:0,8:65535,2:255*8,3:65535},4,kind='echo',length=256)
    for cutoff in [0,16384,65535]:
        for resonance in [0,65535]:
            for freq in [93.75,1500,9000]:
                add(f'filter_{cutoff}_{resonance}_{freq}',sine(freq,4096),{6:0,9:65535,4:cutoff,5:resonance},8,kind='filter',freq=freq,cutoff=cutoff,resonance=resonance)
    for source,depth,target in [('lfo',0,2),('lfo',65535,2),('chaos',0,2),('chaos',65535,2),('chaos',65535,1)]:
        add(f'{source}_{depth}_{target}',np.full(16384,12000),{6:0,14:32768,17:65535,31:65535,11:65535,12:depth if source=='lfo' else 0,15:depth if source=='chaos' else 0,18:target if source=='lfo' else 0,19:target if source=='chaos' else 0},32,kind='mod',source=source,depth=depth,target=target)
    # Same source/timebase in every branch: independent renders must add sample-wise.
    x=sine(750,2048,a=4000)
    gains={6:4096,7:4096,8:4096,9:4096,16:4096,17:4096,14:50000,13:30000,4:18000,5:20000,2:200,0:30000,1:40000}
    for bit in range(6):add('parallel_'+str(bit),x,gains,1<<bit,kind='parallel')
    add('parallel_all',x,gains,63,kind='parallel_sum')
    add('parallel_headroom',np.full(256,12000),{6:65535,7:65535,16:65535,17:65535,14:65535,10:16384},51,kind='headroom')
    add('stereo_isolation',np.column_stack((sine(1500,2048),np.zeros(2048))),{6:0,9:65535,4:18000,5:50000},8,kind='stereo')
    # Long silence after excitation exposes unstable/limit-cycle filter tails.
    for cutoff in [0,32768,65535]:
        x=np.zeros(8192,dtype=np.int64);x[0]=30000
        add('filter_tail_'+str(cutoff),x,{6:0,9:65535,4:cutoff,5:65535},8,kind='tail')
    # New engine regression: spectral separation, exact grain replay and full-depth gain.
    for mode in range(4):
        for freq in [93.75,1078.125,9000]:
            add(f'multimode_{mode}_{freq}',sine(freq,4096),{6:0,9:65535,4:18000,5:20000,28:mode*16384},8,kind='filter',freq=freq,mode=mode)
    for mode in range(4):
        add(f'mode_silence_{mode}',np.zeros(1024),{6:0,9:65535,28:mode*16384,4:65535,5:65535},8,kind='silence')
    for size in range(4):
        length=256<<size
        source=np.column_stack((np.arange(length*4)%15000-7500,3000-np.arange(length*4)%6000))
        add(f'grain_{length}',source,{6:0,7:65535,0:65535,1:65535,23:65535,29:size*16384,30:8192},2,kind='grain',length=length)
    add('grain_probability_zero',edges,{6:0,7:65535,0:65535,23:65535,1:0},2,kind='glitch_zero')
    add('full_depth_vca',np.full(16384,12000),{6:0,14:65535,17:65535,11:65535,12:65535,18:2},32,kind='full_vca')
    add('grain_silence',np.zeros(8192),{6:0,7:65535,0:65535,1:65535,23:65535,29:65535,30:65535},2,kind='silence')
    offset=0
    with (OUT/'input.hex').open('w') as f, (OUT/'cases.txt').open('w') as c:
        for i,case in enumerate(cases):
            p=sum(v<<(16*k) for k,v in enumerate(case['p']))
            c.write(f'{i} {offset} {len(case["x"])} {p:0128x} {case["routes"]:02x}\n')
            for l,r in case['x']:f.write(f'{((int(r)&65535)<<16)|(int(l)&65535):08x}\n')
            offset+=len(case['x'])
    assert offset < 524288
    env=dict(os.environ)
    path_key=next((k for k in env if k.upper()=='PATH'),'PATH')
    bindir=Path('C:/msys64/ucrt64/bin')
    if bindir.exists():env[path_key]=str(bindir)+os.pathsep+env.get(path_key,'')
    compiler=str(bindir/'iverilog.exe') if bindir.exists() else 'iverilog'
    runner=str(bindir/'vvp.exe') if bindir.exists() else 'vvp'
    subprocess.run([compiler,'-g2012','-s','tb_audio_audit','-o',str(OUT/'audit.vvp'),'fpga/sim/tb_audio_audit.sv','fpga/rtl/dsp/parallel_fabric.sv'],env=env,check=True)
    began=time.monotonic()
    with (OUT/'simulation.log').open('w') as log:
        subprocess.run([runner,str(OUT/'audit.vvp')],env=env,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=900)
    outputs=np.loadtxt(OUT/'output.txt',dtype=np.int64);assert len(outputs)==offset
    checks=[]; metrics={}; offset=0; rendered={}
    def check(name,ok,detail):checks.append(dict(name=name,passed=bool(ok),detail=detail))
    def scale(x,g):return x if g==65535 else (x*g)>>16
    def finish(x):return scale(scale(x,65535),65535)
    for case in cases:
        n=len(case['x']); out=outputs[offset:offset+n];offset+=n;y=out[:,:2];x=case['x'];name=case['name'];kind=case['kind'];rendered[name]=y
        metrics[name]={'peak':int(np.max(np.abs(y))),'dc_l':float(y[:,0].mean()),'rms_l':float(np.sqrt(np.mean(y[:,0].astype(float)**2)))}
        if kind=='silence':check(name,np.max(np.abs(y))==0,'Silence must stay exactly silent')
        elif kind in ['dry','bypass','vca','fold']:
            if kind=='dry':expected=finish(scale(x,65535))
            elif kind=='bypass':expected=scale(x,65535)
            elif kind=='vca':expected=finish(scale(scale(x,case['gain']),65535))
            else:
                # Independent mathematical triangle reflection; no DUT function call.
                t=scale(x,65536+4*case['drive'])
                z=(t+32768)%131072
                folded=np.where(z>=65536,98303-z,z-32768)
                expected=finish(scale(folded,65535))
            err=int(np.max(np.abs(y-expected)));check(name,err==0,f'Fixed-point reference max error {err} LSB')
        elif kind=='glitch_zero':
            err=int(np.max(np.abs(y-finish(scale(x,65535)))));check(name,err<=3,f'Probability zero must pass current source; max error {err} LSB')
        elif kind=='glitch_hold':
            expected=finish(scale(np.tile(x[0],(200,1)),65535));err=int(np.max(np.abs(y[1:201]-expected)))
            check(name,err<=3,f'Full hold must retain first sample across polarity changes; error {err} LSB')
        elif kind=='delay':
            locations=np.flatnonzero(y[:,0]);check(name,len(locations)==1 and locations[0]==case['length'],f'Impulse locations {locations.tolist()}, expected {case["length"]}')
        elif kind=='echo':
            locations=np.flatnonzero(y[:,0]);amps=y[locations,0].tolist();check(name,locations.tolist()==[256,512,768,1024] and all(abs(amps[i+1]-amps[i]/2)<5 for i in range(len(amps)-1)),f'Echo locations {locations.tolist()}, amplitudes {amps}')
        elif kind=='filter':
            # Ignore start transient, compare amplitude via coherent sine projection.
            a=y[2048:,0].astype(float);t=np.arange(2048,n);w=2*np.pi*case['freq']*t/RATE
            amp=2*abs(np.sum(a*np.exp(-1j*w)))/len(a)
            metrics[name]['gain_db']=float(20*np.log10(max(amp/6000,1e-9)))
            check(name,np.max(np.abs(y))<32767,'No saturation for a -14.7 dBFS sine')
        elif kind=='mod':
            span=int(np.ptp(y[1024:,0]));metrics[name]['span_l']=span
            check(name,span>2500 if case['depth'] and case['target']==2 else span==0,f'VCA output span {span} LSB, modulation target {case["target"]}')
        elif kind=='stereo':check(name,np.max(np.abs(y[:,1]))==0,'Left-only input must not leak to right')
        elif kind=='tail':
            peak=int(np.max(np.abs(y[-2048:])));metrics[name]['tail_peak']=peak
            check(name,peak<128,f'Final 2048-frame residual peak {peak} LSB (< -48 dBFS)')
        elif kind=='grain':
            length=case['length'];error=0
            for repeat in range(1,4):
                error=max(error,int(np.max(np.abs(y[repeat*length+32:(repeat+1)*length-32]-x[32:length-32]))))
            check(name,error==0,f'Three stereo replays match captured fragment exactly away from fades; error {error} LSB')
            check(name+'_capture',np.array_equal(y[:length],x[:length]),'Capture passes live audio, never uninitialized RAM')
        elif kind=='full_vca':
            lo=int(y[:,0].min());hi=int(y[:,0].max())
            check(name,lo<=8 and hi>=11995,f'Full-depth LFO reaches near silence and unity: {lo}..{hi}')
        elif kind=='headroom':
            check(name,int(y[-1,0])>11980,f'Four 12000 inputs summed with Master 25%: {int(y[-1,0])}; expected about 12000')
    sum_independent=sum(rendered['parallel_'+str(i)].astype(np.int64) for i in range(6))
    error=int(np.max(np.abs(sum_independent-rendered['parallel_all'])))
    check('parallel_superposition',error<=12,f'All six simultaneous paths versus independent renders: max quantization difference {error} LSB')
    for c in [0,16384,65535]:
        lo=metrics[f'filter_{c}_0_93.75']['gain_db'];hi=metrics[f'filter_{c}_0_9000']['gain_db']
        check(f'filter_lowpass_{c}',lo>hi+10,f'93.75 Hz {lo:.2f} dB; 9 kHz {hi:.2f} dB')
    for mode in range(4):
        gains=[metrics[f'multimode_{mode}_{f}']['gain_db'] for f in [93.75,1078.125,9000]]
        ok=(gains[0]>gains[2]+10) if mode==0 else (gains[2]>gains[0]+15) if mode==1 else (gains[1]>max(gains[0],gains[2])+10) if mode==2 else (gains[1]<min(gains[0],gains[2])-10)
        check(f'multimode_response_{mode}',ok,f'93.75 / 1078.125 / 9000 Hz gains: {gains}')
    result={'passed':all(c['passed'] for c in checks),'case_count':len(cases),'frames':len(outputs),'elapsed_seconds':round(time.monotonic()-began,2),'rtl_sha256':hashlib.sha256((ROOT/'fpga/rtl/dsp/parallel_fabric.sv').read_bytes()).hexdigest(),'checks':checks,'metrics':metrics}
    target=OUT/('baseline.json' if args.baseline else 'results.json');target.write_text(json.dumps(result,indent=2),encoding='utf-8')
    for c in checks:print(('PASS' if c['passed'] else 'FAIL')+' '+c['name']+': '+c['detail'])
    print(f'{sum(c["passed"] for c in checks)}/{len(checks)} checks; {len(outputs)} frames; report {target}')
    if not result['passed'] and not args.baseline:sys.exit(1)

if __name__=='__main__':main()
