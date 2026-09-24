"""Exercise new controls and measured I2S output on real hardware; restore registers."""
import json, math, struct, time
from hardware_stream import Device

d = Device('COM14')
saved = None
try:
    assert d.request(1) == b'CELESTE/1'
    assert not d.status()['running'], 'Stop playback first'
    assert d.status()['capabilities'] & 1024, 'Requires sonic engine firmware'
    saved = d.request(9)
    def put(k, v): d.request(3, struct.pack('<HH', k, v))
    results = {}
    cases = [('reference', {6: 65535}),
             *[(f'filter_{mode}', {9: 65535, 4: 18000, 5: 20000, 28: mode*16384}) for mode in range(4)],
             ('stutter', {7: 65535, 0: 65535, 1: 65535, 23: 65535, 29: 65535, 30: 30583}),
             ('tremolo', {17: 65535, 14: 65535, 11: 30000, 12: 65535, 18: 2}),
             ('chaos', {17: 65535, 14: 65535, 15: 65535, 19: 2, 31: 65535})]
    total = 48000
    pcm = b''.join(struct.pack('<hh', round(1800*math.sin(2*math.pi*997*i/48000)+700*math.sin(2*math.pi*7100*i/48000)),
                              round(1400*math.sin(2*math.pi*613*i/48000))) for i in range(total))
    for name, values in cases:
        d.request(6)
        for k in range(32):
            if k != 21: put(k, values.get(k, 65535 if k == 10 else 0))
        put(32, 63)
        # STOP resets histories from the now committed controls.
        d.request(6)
        snapshot = d.request(9)
        assert len(snapshot) == 110
        for k, v in values.items(): assert struct.unpack_from('<H', snapshot, 2*k)[0] == v
        initial = d.status(); before = d.diagnostics()
        output_peak = 0
        cursor = 0; started = False; state = initial; began = time.monotonic()
        while cursor < total or state['running']:
            free = state['capacity']-state['fill']
            if cursor < total and (not started or free >= 3072):
                count = min(free, total-cursor); data = pcm[cursor*4:(cursor+count)*4]
                state = d.batch([data[i:i+1024] for i in range(0, len(data), 1024)]); cursor += count
                if not started: d.request(5); started = True
                if cursor == total: d.request(7)
                if state['fill'] > 4096:
                    output_peak = max(output_peak, struct.unpack_from('<H', d.request(9), 80+7*2)[0])
            else:
                time.sleep(.004); state = d.status()
            assert all(state[k] == initial[k] for k in ('underruns','overruns','errors')), state
            assert time.monotonic()-began < 15
        assert state['samples']-initial['samples'] == total
        after = d.diagnostics()
        signature = [(after[k]-before[k]) & 0xffffffff for k in ('sum_l','sum_r','din_ones')]
        output_peak = max(output_peak, struct.unpack_from('<H', d.request(9), 80+7*2)[0])
        assert output_peak > 0, (name, 'No measured DSP output')
        assert after['nonzero']-before['nonzero'] > 40000, (name, after)
        results[name] = signature
        print(json.dumps({'case': name, 'frames': total, 'input_sums': signature[:2], 'i2s_one_bits': signature[2], 'output_peak': output_peak, 'errors': 0}), flush=True)
    assert len({tuple(v[:2]) for v in results.values()}) == 1, 'Input changed between comparisons'
    assert len({v[2] for v in results.values()}) == len(results), 'Each engine/mode must alter actual serialized samples'
    print('PASS: eight distinct I2S bit counts from identical inputs, nonzero measured DSP output, exact frame counts, control readback, zero transport faults')
finally:
    if saved:
        d.request(6)
        for k, v in enumerate(struct.unpack('<32H', saved[:64])):
            if k != 21: put(k, v)
        put(32, saved[72])
    d.close()
