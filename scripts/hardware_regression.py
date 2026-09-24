"""Silent physical-board checks: prefill, STOP, restart, EOF and CRC rejection."""
import time
from hardware_stream import Device

d=Device('COM14')
try:
    assert d.request(1)==b'CELESTE/1'
    d.request(6)
    baseline=d.status()
    for iteration in range(10):
        # Filled but stopped: no samples can be consumed.
        before=d.status()['samples']
        d.batch([bytes(1024)]*32)
        status=d.status()
        assert status['fill']==8192 and not status['running']
        assert status['samples']==before
        d.request(6)
        assert d.status()['fill']==0
        # Running STOP must flush and leave the consumed counter stable.
        d.batch([bytes(1024)]*32)
        d.request(5)
        time.sleep(.02)
        d.request(6)
        stopped=d.status()
        time.sleep(.02)
        later=d.status()
        assert not later['running'] and later['fill']==0
        assert stopped['samples']==later['samples']
        # Short finite stream: DRAIN before START, exact EOF without underrun.
        before=later['samples']
        d.batch([bytes(1024)]*4)
        d.request(7);d.request(5)
        time.sleep(.04)
        ended=d.status()
        assert ended['samples']-before==1024
        assert ended['fill']==0 and not ended['running']
    for key in ['underruns','overruns','errors']:
        assert ended[key]==baseline[key],(key,ended)
    # Corrupted audio must be rejected without reaching the FIFO.
    _,packet=d.packet(4,bytes(1024))
    corrupt=bytearray(packet);corrupt[-1]^=1
    d.serial.write(corrupt)
    time.sleep(.02)
    rejected=d.status()
    assert rejected['errors']==baseline['errors']+1
    assert rejected['fill']==0 and rejected['samples']==ended['samples']
    assert d.request(1)==b'CELESTE/1'
    print('PASS: 10 prefill/STOP/restart/exact-EOF cycles; corrupt CRC rejected; parser recovered.')
    print('Final counters (one deliberate protocol error):',rejected)
finally:
    try:d.request(6)
    finally:d.close()
