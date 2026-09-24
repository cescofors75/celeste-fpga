"""Real CELESTE serial smoke test and finite clean streaming, no fake telemetry."""
import argparse, binascii, json, math, struct, time
import serial

class Device:
    def __init__(self, port):
        self.serial=serial.Serial(port,3000000,timeout=2,write_timeout=3)
        self.sequence=0;self.meter_peaks=[0]*8
        self.serial.reset_input_buffer()
    def packet(self,kind,payload=b''):
        seq=self.sequence; self.sequence+=1
        body=struct.pack('<BBIH',1,kind,seq,len(payload))+payload
        return seq,b'CE'+body+struct.pack('<H',binascii.crc_hqx(body,0xffff))
    def read_exact(self,n):
        b=self.serial.read(n)
        if len(b)!=n: raise RuntimeError(f'Timeout: expected {n} bytes, got {len(b)}: {b.hex()}')
        return b
    def response(self,kind,seq):
        h=self.read_exact(10)
        if h[:3]!=b'CE\x01':raise RuntimeError(f'Bad response header {h.hex()}')
        length=struct.unpack_from('<H',h,8)[0]
        if length>1024:raise RuntimeError('Invalid response length')
        rest=self.read_exact(length+2)
        if binascii.crc_hqx(h[2:]+rest[:-2],0xffff)!=struct.unpack('<H',rest[-2:])[0]:raise RuntimeError('Response CRC')
        if h[3]!=(kind|128) or struct.unpack_from('<I',h,4)[0]!=seq:raise RuntimeError(f'Command rejected/mismatched: expected kind={kind|128} seq={seq}; got {h.hex()} {rest.hex()}')
        return rest[:-2]
    def request(self,kind,payload=b''):
        seq,b=self.packet(kind,payload);self.serial.write(b);return self.response(kind,seq)
    def batch(self,chunks,control=None,bypass=None):
        commands=([(3,struct.pack('<HH',4,control))] if control is not None else [])+([(3,struct.pack('<HH',20,65535 if bypass else 0))] if bypass is not None else [])+[(4,c) for c in chunks]+([(9,b'')] if control is not None else [])+[(2,b'')]
        packets=[(kind,*self.packet(kind,payload)) for kind,payload in commands]
        self.serial.write(b''.join(packet for _,_,packet in packets))
        status=None
        for kind,seq,_ in packets:
            payload=self.response(kind,seq)
            if kind==9:
                assert struct.unpack_from('<H',payload,8)[0]==control
                if bypass is not None:assert struct.unpack_from('<H',payload,40)[0]==(65535 if bypass else 0)
                if len(payload) in (80,96,110):self.meter_peaks=[max(a,b) for a,b in zip(self.meter_peaks,struct.unpack_from('<8H',payload,80 if len(payload)>=96 else 64))]
            if kind==2:status=self.parse_status(payload)
        return status
    def status(self):
        return self.parse_status(self.request(2))
    def parse_status(self,payload):
        values=struct.unpack('<IHHIIIIHHHH',payload[:32])
        status=dict(zip(['rate','capacity','fill','underruns','overruns','samples','errors','engines','routes','capabilities','running'],values))
        if status['capabilities']&4096:status['capacity'],status['fill']=struct.unpack_from('<II',payload,32)
        return status
    def close(self):self.serial.close()
    def diagnostics(self):
        v=struct.unpack('<8I',self.request(8))
        return dict(zip(['samples','nonzero','sum_l','sum_r','peaks_packed','din_ones','bck_edges','lrck_edges'],v))

def main():
    p=argparse.ArgumentParser();p.add_argument('--port',default='COM14');p.add_argument('--seconds',type=float,default=0);p.add_argument('--tone',action='store_true');p.add_argument('--diagnostics',action='store_true');p.add_argument('--dsp-sweep',action='store_true');p.add_argument('--window-packets',type=int,choices=range(1,33),default=32);args=p.parse_args()
    d=Device(args.port)
    try:
        print('PING',d.request(1).decode(),flush=True)
        d.request(6);initial=d.status();print('INITIAL',initial,flush=True)
        if args.dsp_sweep:
            for key,value in [(6,32768),(7,16384),(8,16384),(9,16384),(32,15)]:d.request(3,struct.pack('<HH',key,value))
            assert d.status()['engines']&7==7
            if initial['capabilities']&8:
                for key,value in [(13,40000),(14,50000),(15,30000),(16,8192),(17,8192),(18,3),(19,3),(32,63)]:d.request(3,struct.pack('<HH',key,value))
        last_control=0;control_updates=0
        diagnostic_before=d.diagnostics() if args.diagnostics else None
        total=int(args.seconds*48000)
        if total==0:return
        pcm=b''.join(struct.pack('<hh',int(2048*math.sin(2*math.pi*440*i/48000)) if args.tone else 0,int(2048*math.sin(2*math.pi*660*i/48000)) if args.tone else 0) for i in range(total))
        cursor=0;started=False;drained=False;status=initial;minimum=initial['capacity'];began=time.monotonic()
        while True:
            if any(status[k]!=initial[k] for k in ['underruns','overruns','errors']):raise RuntimeError(f'Stream fault: {status}')
            if started and not status['running'] and status['fill']==0:break
            free=status['capacity']-status['fill']
            if not drained and (not started or free>=status['capacity']//2 or total-cursor<status['capacity']//2):
                chunks=[]
                while free and cursor<total and len(chunks)<args.window_packets:
                    count=min(256,free,total-cursor);chunks.append(pcm[cursor*4:(cursor+count)*4]);cursor+=count;free-=count
                if chunks:
                    control=None
                    if args.dsp_sweep and time.monotonic()-last_control>.15:
                        control=(control_updates*3001)%65536;control_updates+=1;last_control=time.monotonic()
                    status=d.batch(chunks,control,(control_updates%2==1) if control is not None and initial['capabilities']&16 else None)
                if cursor==total:d.request(7);drained=True
                if not started:
                    if status['fill']<min(total,initial['capacity']):continue
                    d.request(5);started=True
                if started and not drained:
                    minimum=min(minimum,status['fill']);continue
            else:time.sleep(max(.005,(status['fill']-status['capacity']/2)/48000-.012))
            status=d.status()
            if started and not drained:minimum=min(minimum,status['fill'])
            if time.monotonic()-began>args.seconds+10:raise RuntimeError('Playback did not finish')
        result={'status':status,'sent_frames':total,'consumed_delta':status['samples']-initial['samples'],'min_polled_fill':minimum,'elapsed':time.monotonic()-began}
        print(json.dumps(result,indent=2),'CONTROL_UPDATES',control_updates,'MEASURED_METERS',d.meter_peaks,flush=True)
        if args.tone and args.dsp_sweep and initial['capabilities']&32:assert all(v>0 for v in d.meter_peaks),'A parallel branch has no measured signal'
        if result['consumed_delta']!=total:raise RuntimeError('Sample count mismatch')
        if args.diagnostics:
            diagnostic_after=d.diagnostics()
            sums=[sum(struct.unpack_from('<H',pcm,i)[0] for i in range(channel*2,len(pcm),4))&0xffffffff for channel in range(2)]
            print('I2S_DIAGNOSTICS',diagnostic_after,'EXPECTED_SUMS',sums,flush=True)
            for key,expected in zip(['sum_l','sum_r'],sums):
                actual=(diagnostic_after[key]-diagnostic_before[key])&0xffffffff
                if actual!=expected:raise RuntimeError(f'FIFO content mismatch: {key} {actual} != {expected}')
            if args.tone and diagnostic_after['din_ones']==diagnostic_before['din_ones']:raise RuntimeError('I2S DIN remained zero')
    finally:
        try:d.request(6)
        finally:d.close()
if __name__=='__main__':main()
