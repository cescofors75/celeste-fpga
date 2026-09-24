"""Verify exact FIFO sums and an intentional USB delivery gap, with DAC muted."""
import argparse, json, struct, time
from hardware_stream import Device

p=argparse.ArgumentParser();p.add_argument('--port',default='COM14');p.add_argument('--pause-ms',type=int,default=350);p.add_argument('--inside-packet',action='store_true')
args=p.parse_args();d=Device(args.port);master=None
try:
    assert d.request(1)==b'CELESTE/1'
    d.request(6);initial=d.status();assert initial['capacity']>=32768 and initial['capabilities']&2048
    master=struct.unpack_from('<H',d.request(9),20)[0]
    d.request(3,struct.pack('<HH',10,0))
    before=d.diagnostics();total=max(100000,initial['capacity']*3+123)
    # Exercise every bit, both channels, row boundaries and multiple queue wraps.
    # A 32-bit PRNG avoids identical 65536-frame blocks masking a high-row alias.
    pattern=0x6d2b79f5;pcm=bytearray(total*4)
    for i in range(total):
        pattern^=(pattern<<13)&0xffffffff;pattern^=pattern>>17;pattern^=(pattern<<5)&0xffffffff
        struct.pack_into('<I',pcm,i*4,pattern)
    expected=[sum(struct.unpack_from('<H',pcm,i)[0] for i in range(c*2,len(pcm),4))&0xffffffff for c in range(2)]
    cursor=0;status=initial
    def send(count):
        global cursor
        chunks=[pcm[i*4:min(i+256,cursor+count)*4] for i in range(cursor,cursor+count,256)]
        cursor+=count
        return d.batch(chunks)
    while cursor<initial['capacity']:status=send(min(4096,initial['capacity']-cursor))
    assert status['fill']==initial['capacity']
    d.request(5)
    if args.inside_packet:
        seq,packet=d.packet(4,pcm[cursor*4:(cursor+256)*4])
        d.serial.write(packet[:500]);time.sleep(args.pause_ms/1000);d.serial.write(packet[500:]);d.response(4,seq);cursor+=256
    else:time.sleep(args.pause_ms/1000)
    after_gap=d.status();print('AFTER_GAP',json.dumps(after_gap),flush=True)
    drained=False;deadline=time.monotonic()+15
    while True:
        assert all(status[k]==initial[k] for k in ['underruns','overruns','errors']),status
        if drained and not status['running'] and status['fill']==0:break
        free=status['capacity']-status['fill']
        if cursor<total and free>=4096:status=send(min(4096,total-cursor))
        elif cursor==total and not drained:d.request(7);drained=True
        else:status=d.status()
        assert time.monotonic()<deadline,'Stream did not finish'
    after=d.diagnostics()
    assert status['samples']-initial['samples']==total
    assert [(after[k]-before[k])&0xffffffff for k in ['sum_l','sum_r']]==expected,(before,after,expected)
    print('PASS',json.dumps({'frames':total,'pause_ms':args.pause_ms,'inside_packet':args.inside_packet,'expected_sums':expected,'status':status,'diagnostics':after}),flush=True)
finally:
    try:
        d.request(6)
        if master is not None:d.request(3,struct.pack('<HH',10,master))
    finally:d.close()
