# CELESTE · V1 architecture

## Current implementation

Clean WAV output was confirmed by the user. Build 4DAE now implements parallel
Glitch/Delay/Filter, live registers, physical encoders and HDMI/ST7789.
See [DSP_V1.md](DSP_V1.md) for implemented behavior and validation.

## Original milestone contract

The specification is an incremental hardware bring-up, not permission to call a
mockup a working FPGA instrument. The three DSP branches are gated on clean WAV
playback through the actual PCM5102. Until then the patch editor is an offline
design tool and local playback is explicitly **dry monitor**.

```
WAV file → worker → celeste-wasm → celeste-core → 48 kHz PCM16 stereo
                                                  ↓ chunks (256 frames)
                         Transport → validated packet staging → FIFO
                                                                  ↓
                    generic source_valid / source_left / source_right
                                                                  ↓
                       [clean-stream milestone, then parallel DSP]
                                                                  ↓
                                                     I²S → PCM5102
```

## Host

TypeScript + Vite, no UI framework or backend. The WAV stays on the host. A Web
Worker owns the Rust PreparedAudio allocation and only transfers bounded PCM
chunks or a downsampled waveform to the UI. Decode supports integer PCM
8/16/24/32 and IEEE float32, one/two channels at 44.1/48 kHz. Mono is duplicated.
44.1 kHz uses a normalized 32-tap Hann-windowed sinc resampler. This is sample
preparation, not the CELESTE effects engine. Input is capped at 128 MiB to bound
WASM/browser memory. Peak memory includes source, decoded floating samples and
prepared PCM; the limit is not a guarantee on memory-constrained browsers.

Transport is request/response over an abstract byte stream. The Web Serial
adapter is a candidate for the onboard BL616 UART bridge. It requires both a
successful CELESTE/1 handshake and status capabilities; opening a COM port is not
proof of an audio link. Timeouts/CRC errors are exposed. No production mock or
invented telemetry. Local Web Audio playback schedules prepared PCM chunks as a
diagnostic; routing/parameter edits deliberately do not change that dry sound.

## Audio and fixed point

Transport: little-endian L16,R16 signed Q1.15, 4 bytes/frame. Quantization rounds
to nearest and saturates to [-32768,32767]; NaN/Inf become silence. The inherited
24-bit I²S transmitter receives PCM16 shifted left eight bits, no gain change.
It emits two 32-bit slots, standard one-bit I²S delay, captures both channels
together, and changes data on falling BCK edges.

The clean-stream core requires **12.288 MHz**; BCK=3.072 MHz, LRCK=48 kHz.
Do not attach the old 25.2 MHz video clock: its old audio path ran at 49,218.75 Hz.
MS5351 CLK2 on pin13 supplies 12.288 MHz via a volatile configuration.
prepare_board.py configures and reads it back; it is not saved across power loss.

Board FIFO: 8192 complete stereo frames (32 KiB, 170.67 ms), synchronous BRAM read,
plus a one-frame output stage. All ports in the portable core share the audio
clock. Any separate transport clock requires a verified asynchronous FIFO/CDC
bridge; never cross valid/data directly. STOP clears buffered/staged samples.
START consumes prefetched data on an I²S boundary. DRAIN handles finite files
without turning a normal end of file into an underrun. Underflow emits silence
and increments a real counter. No memory-wide reset impedes BRAM inference.

## Fabric design evolution (implemented details supersede this plan)

Three physically independent paths (Glitch, Delay, Filter) receive the generic
source concurrently. A registered source mux per engine selects legal graph
edges; a mixer sums dry and branch outputs. V1 rejects cycles and multiple
drivers except at the mixer. Delays internal to a module do not create graph
cycles. Future Line In uses the same generic stereo source interface.

Planned widths: samples Q1.15; gain parameters UQ0.16; coefficients signed Q2.30;
mix accumulation at least signed 40 bits; explicit rounding and saturation on
output. Routing and coefficients use shadow registers committed at sample
boundaries, with a 96-frame (2 ms) gain transition on route changes. Delay length
must follow measured BRAM allocation, not the UI concept's 280 ms assumption.
The current delay display represents a requested design value, not hardware
capability. DSP register addresses/quantization are to be finalized with RTL.

## Reuse

Existing project: `../CELESTE TANG NANO 20K PCM  HDMI FXBOX`, git HEAD inspected
`9fc1e8c78cec8fda52ac419118c1ea34a3f63f83`. `i2s_tx.v` and `tb_i2s.sv` copied
unchanged; source files on disk are authoritative (HEAD is provenance only).
`fpga/reference/legacy-av.cst` is an unmodified wiring reference, not constraints
for a new top level. Existing `video_timing`, `tmds_encoder`, `ui_font`,
`tmds_output`, `st7789_panel`, `encoder8_panel`, `i2c_register_master`, and
`touch_input` were identified for later reuse. The old project was not edited.

Do not fake new HDMI routes: it must consume the same committed routing state
as the audio fabric. Hardware mapping/touch events are stored with the patch;
physical event synchronization and displays follow the clean audio gate.
