# CELESTE byte protocol v1 (bring-up)

All multibyte values are little-endian. Maximum payload 1024 bytes. A byte-stream
adapter must retain packet boundaries through framing, not USB read sizes.

| Offset | Size | Field |
|---|---:|---|
| 0 | 2 | magic `43 45` (CE) |
| 2 | 1 | version 1 |
| 3 | 1 | kind |
| 4 | 4 | sequence number |
| 8 | 2 | payload byte length |
| 10 | N | payload |
| 10+N | 2 | CRC-16/CCITT-FALSE of version through payload |

CRC: polynomial 0x1021, initial 0xffff, no reflection/xorout. Check value for
`123456789` is 0x29b1. Payloads must be fully staged and validated before side
effects. Host serializes control requests and permits up to 32 credit-bounded
audio requests in one window. It stops on a timeout; there is no
unsafe automatic replay of audio. Response echoes sequence and request kind
OR 0x80. 0xff is an error with one byte reason. Planned reasons: 1 unsupported,
2 malformed, 3 insufficient FIFO capacity, 4 illegal state.

| Kind | Request | Response |
|---:|---|---|
| 1 PING | empty | ASCII `CELESTE/1` |
| 2 GET_STATUS | empty | 32-byte status below |
| 3 SET_PARAM | u16 ID + u16 normalized value | ACK after validated register write |
| 4 AUDIO | 1..256 complete L16,R16 frames | ACK after all frames committed |
| 5 START | empty | ACK; start on sample boundary |
| 6 STOP | empty | ACK after stream FIFO/staging cleared |
| 7 DRAIN | empty | ACK; stop cleanly once queued audio is consumed |
| 8 GET_AUDIO_DIAGNOSTICS | empty | 32-byte measured digital audio diagnostics (E936+) |
| 9 GET_CONTROLS | empty | 48 bytes: values, mappings, routes, panel state, revision (4DAE) |

Status offsets: 0 sample rate u32; 4 FIFO capacity u16; 6 fill u16 (including
staged output); 8 underruns u32; 12 overruns u32; 16 consumed sample counter u32;
20 protocol errors u32; 24 engine mask u16; 26 route mask u16; 28 capabilities
u16 (bit 0 PCM streaming, bit 1 DSP parameter control, bit 2 encoder controls); 30 running u16.
Counter wrap is modulo 2^32. Values are device facts, never UI estimates.

## Flow control

STOP, poll status, prefill the advertised FIFO (32768 frames on the SDRAM build),
START, then transmit only blocks that fit the last reported free space. For
finite files send DRAIN immediately after the last block, before START if the
whole file fits the prefill. No USB/serial write completion is interpreted as
FIFO consumption. Browser timer jitter is absorbed by FIFO, not by timing
individual samples on the host. Response pacing at high baud needs actual
throughput measurement. The SDRAM board uses a 32768-frame FIFO and bounded batched writes
to amortize USB latency. Control and ACK sequences remain individually checked.

The RTL endpoint implements PING, GET_STATUS, AUDIO, START, STOP, DRAIN and
live control commands, including CRC responses and sequence echo. Builds
without the DSP parameter still reject SET_PARAM. The integrated board
firmware uses UART at 3 Mbaud, clock-domain FIFOs and a 12.288 MHz audio clock.
The current image is stored in Flash; the audio clock was saved separately.
Check the handshake/capabilities after boot. `scripts/prepare_board.py` is a
recovery/setup tool for boards still running an older incompatible image.

During audio streaming, parameter writes, control readback and GET_STATUS are
batched with PCM in one window to avoid extra ~17ms USB turnarounds. See
[DSP_V1.md](DSP_V1.md) for register IDs, 48-byte snapshot and measured results.

GET_AUDIO_DIAGNOSTICS returns eight u32 values: consumed frames, frames with
either channel nonzero, sum of unsigned 16-bit left samples, equivalent right
sum, packed absolute peaks (left low16 / right high16), high DIN bits sampled on
BCK rising edges, BCK rising edges, LRCK rising edges. Counters wrap modulo
2^32, persist across STOP and reset on board reset. These measure internal
digital signals; they are not analog DAC feedback. The sums permit comparison
against the actual transmitted PCM file. `hardware_stream.py --diagnostics`
checks them. Command 8 is an optional bring-up extension, not required by UI.

## Transport evidence · 2026-09-19

Sipeed documents the onboard BL616 as the FPGA programmer and USB/UART bridge:
[board manual](https://wiki.sipeed.com/hardware/en/tang/tang-nano-20k/nano-20k.html),
[unboxing / bridge selection](https://wiki.sipeed.com/hardware/en/tang/tang-nano-20k/example/unbox.html).
Windows detects VID 0403 / PID 6010, channels A/B, serial 2025030317,
COM13/COM14. Both ports opened at 115200 and produced no unsolicited data.
A binary CELESTE PING at 115200 returned only `FA` on COM13 and timed out on
COM14. Neither is a valid CELESTE response. Do not treat channel A as a verified
UART; it may be the debugger channel. No bitstream or bridge firmware was loaded.
Enumeration is not proof of FPGA RX/TX pin mapping or sustained throughput.

PCM16 stereo is 192000 bytes/s; UART 8N1 requires 1.92 Mbaud before framing.
For 256-frame blocks, audio packet overhead is 12/1024=1.172%. Status and ACK
turnarounds add more. 115200 is suitable only for control diagnostics. 3 Mbaud
is a candidate. WebUSB bulk transport is not assumed available; if UART cannot
sustain the rate, evaluate a documented bridge/host service or a dedicated USB
interface. Do not lower the sample rate or drop channels silently.


## Two encoder banks (capability 0x40, snapshot version 3)

The M5 8Encoder switch register 0x60 bit 0 selects bank 0/1. Each bank has
8 independently assignable controls. SET_PARAM 40..47 maps bank 0, 48..55 maps
bank 1 (parameter IDs 0..17). Register 21 is read-only: 0 / 65535 for bank 0/1.
GET_CONTROLS retains its 80-byte size: byte 57 bit 0 = panel online,
bits 1..3 = selected encoder, bit 4 = active bank. Bytes 48..55 always contain
the active bank mappings; byte 62 = 3 for that release. The last bank persists while the panel
is offline. Touch bypass remains register 20 and is independent of the selector.
Patch JSON optionally includes hardwareBank1; absent fields use factory bank 1
assignments. Bank 0 remains in hardware, preserving older patch files.

## Audited audio arithmetic (capability 0x80, snapshot version 4)

The 2026-09-20 release advertises capabilities 255 and snapshot version 4.
The GET_CONTROLS payload remains 80 bytes, with unchanged offsets and bank
semantics. Capability 0x80 identifies corrected Glitch interpolation, exact
unity gain, fractional filter-state accumulation and wide mixing before
master/output saturation. It does not add arbitrary graph routing or DSP
instances. See [AUDIO_AUDIT.md](AUDIO_AUDIT.md) for measured coverage and limits.

## Component bypass and second delay (capability 0x100, snapshot version 5)

Capabilities 511 identify the dual-delay build. GET_CONTROLS expands to 96
bytes with 32 registers. Bank mappings begin at 64, routes at 72, flags at 73,
revision at 74, version at 78 and the eight existing meters at 80. New host
registers 22 and 24–27 control per-component bypass and independent Delay 2.
See [DUAL_DELAY.md](DUAL_DELAY.md) for the full contract and routing limits.

## Independent signal telemetry (capability 0x200, snapshot version 6)

Capabilities 1023 identify the 15-meter build. GET_CONTROLS is 110 bytes,
preserving the first 80 bytes of v5. Meters 0–7 keep their original meaning;
8–13 measure six effects before their mixer gains, and 14 measures Delay 2
after its mixer gain. See [SIGNAL_METERS.md](SIGNAL_METERS.md).

## Sonic controls (capability 0x400, snapshot version 6 unchanged)

Capabilities 2047 add normalized registers 23 (Glitch mode), 28 (Filter mode),
29 (Glitch grain size), 30 (repeat count) and 31 (Chaos rate). All are available
to encoder mappings. Snapshot size and meter offsets remain unchanged.
VCA modulation now multiplies the base gain by a full-range attenuation factor;
full LFO Depth can close the VCA completely. See [SONIC_ENGINE.md](SONIC_ENGINE.md)
for register encodings, mode-switch behavior and compatibility notes.


## SDRAM source reservoir (capability 0x800)

Capabilities 4095 advertise a 32768-frame stereo PCM16 FIFO in package SDRAM.
Status remains 32 bytes and the control snapshot remains v6 / 110 bytes.
Hosts must honor the advertised capacity and finish prefilling it before START
(or prefill the complete finite source if shorter). No DSP parameter changes.
See USB_STREAMING.md for the physical interruption and soak tests.

## Wide FIFO credits (capability 0x1000)

The deep-SDRAM board advertises capabilities 8191. GET_STATUS extends its
payload from 32 to 40 bytes: uint32 little-endian capacity at offset 32 and
uint32 fill at offset 36, both in stereo frames. The legacy uint16 fields
at offsets 4/6 saturate at 65535; hosts must use the extension when bit 0x1000
is set. All other offsets and the v6 control snapshot remain unchanged.
The board holds 131072 stereo frames (512 KiB, 2.731 seconds at 48 kHz).
The host prefills the advertised capacity before START. CRC framing is unchanged.
