"""Exercise pauses inside a real USB/UART packet; the DAC remains stopped."""
import json,time
from hardware_stream import Device

d=Device('COM14')
try:
    d.request(6)
    for ms in [200,500,1000,2000]:
        d.request(6);before=d.status()
        seq,packet=d.packet(4,bytes((i*31)&255 for i in range(1024)))
        d.serial.write(packet[:500]);time.sleep(ms/1000);d.serial.write(packet[500:])
        d.response(4,seq);after=d.status()
        assert after['fill']==256 and after['errors']==before['errors'],after
        assert after['underruns']==before['underruns'],after
        print('PASS',json.dumps({'packet_gap_ms':ms,'frames':after['fill'],'protocol_error_delta':after['errors']-before['errors']}),flush=True)
    d.request(6);before=d.status();seq,packet=d.packet(4,bytes(1024))
    corrupt=bytearray(packet);corrupt[100]^=1;d.serial.write(corrupt)
    time.sleep(.02);after=d.status()
    assert after['fill']==0 and after['errors']==before['errors']+1,after
    assert d.request(1)==b'CELESTE/1'
    print('PASS corrupt CRC rejected without enqueuing samples; parser recovered',flush=True)
finally:
    try:d.request(6)
    finally:d.close()
