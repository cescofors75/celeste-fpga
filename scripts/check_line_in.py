"""Read real LINE IN counters; optionally start/stop and select dry bypass.
Never sends WAV data, changes clocks, or flashes the board.
"""
import argparse
import json
import struct
import time
from hardware_stream import Device

def main():
    p=argparse.ArgumentParser()
    p.add_argument('--port',default='COM14')
    p.add_argument('--seconds',type=float,default=3)
    p.add_argument('--start',action='store_true')
    p.add_argument('--stop',action='store_true')
    p.add_argument('--bypass',action='store_true')
    a=p.parse_args()
    if a.seconds<=0 or (a.start and a.stop):p.error('Use positive seconds and only one of start/stop')
    d=Device(a.port)
    try:
        status=d.status()
        if not status['capabilities']&8192:raise RuntimeError('This is not the LINE IN firmware; no controls changed')
        if a.bypass:d.request(3,struct.pack('<HH',20,65535))
        if a.stop:d.request(6)
        if a.start:d.request(5)
        before=d.diagnostics();t=time.monotonic();time.sleep(a.seconds)
        after=d.diagnostics();elapsed=time.monotonic()-t
        status=d.status()
        delta={k:(after[k]-before[k])&0xffffffff for k in ('samples','nonzero','bck_edges','lrck_edges')}
        print(json.dumps({'status':status,'delta':delta,'receiver_frames_per_second_approx':round(delta['samples']/elapsed), 'clock_master':'PCM1808', 'adc_presence_confirmed':False,
                          'input_peak_l':after['peaks_packed']&65535,'input_peak_r':after['peaks_packed']>>16},indent=2))
        if not a.stop and not status['running']:
            raise RuntimeError('Receiver not locked: use --start and check ADC master clocks, I2S 24-bit / 64 BCK per frame at 48 kHz.')
        if not a.stop and delta['samples']==0:raise RuntimeError('No input frames received')
        if not a.stop and delta['nonzero']==0:print('Zero DOUT: may be silence OR an absent/unconfigured ADC. Frame counts alone cannot detect ADC presence.')
    finally:d.close()

if __name__=='__main__':main()
