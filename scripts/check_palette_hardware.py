"""Validate mapping acceptance/readback on the real board; restore the mapping."""
import json, struct, time
from hardware_stream import Device

d=Device('COM14')
original=None
try:
    snapshot=d.request(9)
    deadline=time.monotonic()+5
    while not snapshot[73]&1 and time.monotonic()<deadline:
        time.sleep(.1)
        snapshot=d.request(9)
    assert len(snapshot)==110
    bank=(snapshot[73]>>4)&1
    assert snapshot[73]&1, 'Encoder panel is not online'
    original=snapshot[64]
    address=40+8*bank
    tested=[]
    for parameter in [0,7,2,8,24,25,26,4,9,28,13,16,14,17,11,12,15,31,23,29,30,6,10]:
        d.request(3,struct.pack('<HH',address,parameter))
        time.sleep(.08)
        snapshot=d.request(9)
        assert ((snapshot[73]>>4)&1)==bank, 'Physical bank changed during test'
        assert snapshot[64]==parameter, (parameter,snapshot[64])
        assert snapshot[73]&1, 'Encoder panel disconnected during remapping'
        tested.append(parameter)
    print(json.dumps({'result':'PASS','active_bank':bank,'panel_online':True,
                      'accepted_and_read_back':tested,
                      'note':'LED output colors are verified in RTL; physical hue needs visual observation'}))
finally:
    try:
        if original is not None:d.request(3,struct.pack('<HH',address,original))
    finally:d.close()
