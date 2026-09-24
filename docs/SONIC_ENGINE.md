# Sonic engine upgrade

## What changes audibly

- VCA modulation is now multiplicative: `Level × max(0, 1 − LFO − Chaos)`.
  Depth 100% spans unity to silence with one full LFO cycle, independently of
  the base Level. Combined modulation clamps at zero rather than wrapping.
  Zero depth retains bit-exact static VCA gain. LFO is triangular.
- Filter output is selectable LPF, HPF, BPF or notch from the existing stereo
  state-variable core. Cutoff and resonance remain active in all four modes.
  Mode changes fade down, switch at zero gain, then fade up (~1.4 ms total).
  This is one multimode filter instance, not four simultaneous instances.
- Glitch has Texture (sample hold) and Stutter (captured stereo fragment) modes.
  Stutter captures 256, 512, 1024 or 2048 frames: 5.3, 10.7, 21.3 or 42.7 ms.
  At each completed capture, Probability decides whether to repeat it 1–16
  times. Amount blends live and repeated audio. The first/last 32 samples of
  each repeated grain fade toward live audio to soften seams. A new Size is
  latched only for a new capture; unfilled memory is never played. This is
  micro-stutter, not a long beat slicer, reverse playback or time stretch.
- Texture hold length no longer wraps at maximum Amount.
- Chaos Rate controls target changes from 0.05 to 11.77 Hz. Targets are
  pseudo-random, smoothed by a fixed 64-unit/sample slew. Amount controls depth.
  LFO and Chaos still target Filter Cutoff or VCA Level only.

Both delays retain their 170.67 / 85.33 ms stereo buffers. Stutter uses four
additional BSRAM blocks (8 KiB). The full design uses all 46 BSRAM blocks;
additional long buffers require a different memory allocation/architecture.
Independent branch state and synchronous sample timing remain unchanged;
some arithmetic units are shared between clock phases. This is not a claim
that every arithmetic operation has its own dedicated multiplier.

## Protocol and UI

Capabilities bit `0x400` advertises these additions (combined capabilities
2047). GET_CONTROLS retains the 110-byte v6 format and fifteen signal meters.
New normalized 16-bit registers:

| ID | Parameter | Encoding |
|---|---|---|
| 23 | glitch.mode | bit 15: 0 Texture, 1 Stutter |
| 28 | filter.mode | bits 15:14: LPF, HPF, BPF, Notch |
| 29 | glitch.size | bits 15:14: 256, 512, 1024, 2048 frames |
| 30 | glitch.repeats | 1 + bits 15:12 |
| 31 | chaos.rate | phase increment 4474 + 16 × value at 48 kHz |

All are assignable to encoders. Web selectors display actual mode/size names;
HDMI shows filter type and Glitch mode. Encoder rows on HDMI/LCD identify new
parameters and show mode/size labels when those parameters are mapped.
Old firmware never receives these registers from the new control bridge.
New-mode presets require the advertised capability. Existing patches receive
default settings for missing controls; new defaults select Stutter. VCA depth
semantics intentionally change, so existing deeply modulated patches sound
stronger. Select Texture to retain the old Glitch character.

Presets: Stutter Memory, High Pass Air, Band Focus, Notch Sweep;
Breathing VCA now uses full depth. Demonstration presets clear component
bypasses and isolate the relevant audio branch. Global bypass remains a user
control and is reported if it would mask a preset.

## Verification

`npm run test:audio`: 85/85 checks, 314444 stereo frames against synthesizable
RTL. Includes exact capture/replay, all grain sizes, silence, spectral mode
separation, full-depth VCA, existing delay/feedback/headroom/stereo tests and
sample-wise parallel superposition (0 LSB difference in tested case).

Measured filter gains at 93.75 / 1078.125 / 9000 Hz, with the same cutoff and
resonance, in dB:

| Mode | Low | Centre | High |
|---|---:|---:|---:|
| LPF | -0.02 | -3.73 | -35.02 |
| HPF | -42.30 | -3.60 | +0.99 |
| BPF | -21.16 | -3.66 | -17.00 |
| Notch | -0.09 | -40.12 | +0.86 |

`tb_sonic_controls`: exact full-depth VCA endpoints, combined modulation
clamping, safe grain resize, bounded filter-mode transitions, effective Chaos
rate, and a 32-clock DSP deadline (256 clocks available per audio frame).

`scripts/check_sonic_hardware.py`: actual I2S signatures, new register readback,
frame counts and transport errors across eight configurations. This measures
digital data sent to PCM5102; it does not measure analog noise/distortion.


Final implementation: 17378/20736 logic, 6249/15750 registers,
22/24 DSP, 46/46 BSRAM. Setup/hold violated endpoints: 0/0.
Bitstream SHA256: `8afd7ca4abd1c2e07a0e81eeaf038ff6638025ce6456d793fae8766146483b32`.
Web/WASM: 36 tests pass. Browser flow verifies mode/size selectors, new
preset loading, persisted encoder mapping, and available modulation targets.
HDMI simulation render: `build/sonic-hdmi.png` (fixture levels, not a camera
capture of the connected display).

Physical coverage uses identical inputs in all eight cases. Input sums are
recorded separately from the serialized I2S one-bit counter and the measured
post-DSP output peak. Distinct bit counts show a changed digital stream;
these counters are not a sample-by-sample waveform capture or a THD measure.
