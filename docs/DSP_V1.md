# Parallel DSP build 4DAE — 2026-09-19

The user confirmed clean WAV playback through PCM5102 and requested DSP,
live encoder values, the small screen and improved HDMI. This build adds
three source-parallel branches and a saturating stereo mixer. No soft CPU,
WASM effects, Flash writes or prior-project edits are involved.

## Signal and control behavior

- Glitch: deterministic pseudo-random sample hold; amount crossfades source
  and held samples, probability controls retriggering. This is not a granular
  buffer/reverse processor.
- Delay: 8192 stereo PCM16 frames, 1–8192 samples (0.0208–170.667 ms), feedback
  bounded below 50%. Written-sample tracking masks uninitialized RAM.
- Filter: fixed-point state-variable low-pass, approximately 20–3880 Hz,
  with bounded resonance/damping. Saturating state updates prevent wrapping.
- Mixer: independently smoothed dry/glitch/delay/filter gains and master.
  Source samples Q1.15; controls U0.16; wide signed products/accumulators;
  arithmetic truncation and explicit saturation at audio boundaries.
  Full-scale normalized gain loses up to two LSBs through cascaded scaling.
- All three branches consume the same stereo source on each 48 kHz tick.
  Computation finishes six audio clocks later; the I2S output has one frame
  of pipeline latency. STOP clears DSP state and invalidates delay history.
- Target parameter/gain changes slew by at most 256/65535 per frame (~5.3 ms
  for a full-range step). Route masks fade branch gains. Delay-time moves
  slide the read head and can produce intentional pitch change.
- Triangle LFO, ~0.05–11.77 Hz, can modulate filter cutoff with normalized
  depth. Only LFO → filter.cutoff modulation is deployed.

Valid V1 audio graph: Sample → any of Glitch / Delay / Filter → Mixer → Out,
plus Sample → Mixer. Serial effect chains, Wavefolder/VCA and Chaos remain
offline; connected edits reject unsupported routes or mappings. This is a
configurable parallel graph, not an arbitrary routing matrix.

## Registers and synchronization

SET_PARAM kind 3: u16 ID + u16 value, applied without synthesis/reload.
IDs 0–12 respectively: glitch.amount, glitch.probability, delay.time,
delay.feedback, filter.cutoff, filter.resonance, mixer.dry, mixer.glitch,
mixer.delay, mixer.filter, mixer.master, lfo.rate, lfo.depth.
ID 32: route mask dry/glitch/delay/filter in bits 0–3. IDs 40–47: encoder
assignments (parameter IDs 0–12). IDs 13–15 are reserved.

GET_CONTROLS kind 9 returns 48 bytes: 16 u16 register values (0–31), eight
mapping bytes (32–39), route mask (40), encoder-online bit0 and selected
encoder bits1–3 (41), revision u32 (42–45), extension version 1 u16 (46–47).
Engine mask is 7; capabilities 7 = streaming + DSP + physical controls.

The reused M5Stack driver reads actual I2C encoder counters, discards restart
jumps beyond ±32 and changes the mapped register by 512 units per detent.
Host writes have priority if they coincide with an encoder event. Web reads
actual values/revision back; pending edits are not replaced by older readback.
The web knobs support vertical drag, arrows, Shift+arrows, Home/End;
double-click opens mapping. Mappings remain part of saved patches.

## Transport changes

Standalone USB requests measured ~17 ms each. An initial control-sweep test
underran despite clean raw audio streaming. The corrected host sends up to
two coalesced parameter writes, PCM blocks, optional control readback and
GET_STATUS in one credit-bounded window. Every response still has its own
sequence and CRC validation. FPGA return bytes retain 3 Mbaud signaling but
are paced ~29.7 microseconds apart to avoid long bursts into the bridge.
No independent control polling runs during browser hardware streaming.

Two physical 30-second tone runs then consumed exactly 1,440,000 frames each,
with 151 and 152 control writes/readbacks, zero underruns/overruns/protocol
errors, and minimum observed fills 2198 and 2513. PCM channel sums matched
the sent file and the I2S data activity counter was nonzero. The final build
also passed a 30-second silent sweep after the last display-only adjustment.

## Displays and pins

HDMI: 640×480 bitmap text, live branch mask and eight mapped parameter bars.
ST7789: 240×240, CELESTE heading, actual RUN/READY state, eight assignments,
normalized register percentages, selected-control highlight and I2C status.
Percentages on physical screens are normalized parameter values; the web
also converts delay time, feedback, cutoff and LFO rate into engineering units.
Titles use LIVE values rather than claiming a custom patch name was transferred.

Display state crosses clock domains as a held bus with request/acknowledge
synchronizers; it cannot mix independently sampled parameter bits. Rendering
was inspected from exact HDL pixel simulation, not a mockup. Physical LCD/HDMI
appearance and turning an encoder still require the user's visual/action test.

Existing wiring reused unchanged: PCM BCK73/DIN74/LRCK75; encoder SDA76/SCL77;
LCD clock42/data41/reset48/DC49. SPI mode3 at 12.6 MHz, existing ST7789 init.
Touch actions remain reserved; no new physical touch behavior is claimed.

## Validation and limits

12 Rust tests, 11 JS/WASM/control tests, RTL FIFO/I2S/stream/protocol/endpoint/
UART/CDC/fabric/control tests and real browser loading/playback/session/mapping/
rotary-keyboard tests pass. RTL checks include stereo dry gain, delay impulse,
uninitialized-memory masking, filter response, glitch hold, route mute,
framed parameter writes, real register readback and mapped encoder updates.

Current hardware reports the I2C panel online. FPGA resource and timing results
are in FPGA_RESOURCES.md. No analog DSP output was recorded; subjective DSP
listening, native-browser live-control endurance and physical display/rotary
interaction remain user acceptance checks. No Flash changes: prepare_board.py
is needed again after power cycling.

## Canvas editor

New patch stops playback and starts an empty canvas. Add modules from the library, drag titles to move them, and connect output/input ports. Removing a module removes its audio/modulation routes. Optional `nodes` in patch JSON stores module IDs and coordinates; older patches retain their default layout. Connected FPGA mode disables unsupported destinations. Wavefolder, VCA and Chaos remain offline design modules. Only one browser/application can own COM14 at a time; disconnect before switching browsers. Browser regression covers empty creation, add/connect/drag, persistence and removal.

## Expanded firmware (supersedes the three-engine build above)

Wavefolder and VCA are additional source-parallel stereo paths. Chaos is a deterministic LFSR sample-and-hold modulation source with slew limiting (new target every 4096 samples). LFO and Chaos can target Filter cutoff and/or VCA level; these are currently the supported modulation destinations. Wavefolder drive spans approximately 1x to 5x before triangular folding. VCA level and modulation attenuate its own branch, not the master bus. Audio routes must remain source -> effect -> mixer -> output; arbitrary serial chains are not implemented.

Registers 13..17: wavefolder.drive, vca.level, chaos.amount, mixer.wavefolder, mixer.vca. Registers 18 and 19 are LFO/Chaos destination masks (bit 0 Filter, bit 1 VCA). Route bits 4/5 enable Wavefolder/VCA. GET_CONTROLS now returns 64 bytes: 24 u16 values, 8 mapping bytes, route mask, online/selected, u32 revision, u16 version=2. Capabilities bit 3 advertises this extension; old 48-byte snapshots remain readable in the web. Engine mask=63. Eight physical controls may map to parameter IDs 0..17.

Build SHA256: 75E9D8F48AF54830AA40FCA682E487878BD56D6A37A60FCADD9467569284444C.
Resources: 10301/20736 logic, 4004 registers, 34/46 BSRAM, 17.5/24 DSP. Setup and hold violated endpoints: zero. SRAM programmed, Flash unchanged.
Hardware validation: 30 seconds, 1,440,000 stereo frames, 152 live updates/readbacks, zero underruns/overruns/protocol errors; input sample checksums match and real I2S DIN transitions were measured. Analog listening remains a user acceptance check. Tests also cover VCA scaling/muting, wavefold identity/folding, Chaos activity and LFO destination isolation.

Presets: Folded Light, Breathing VCA, Chaotic Focus. The Hardware page displays synthesized resource totals, not dynamic usage. Removing nodes does not reclaim physical resources from a fixed bitstream. Multiple input sources and duplicate DSP instances remain pending; the two-source transport design depends on shared vs independent processing.

## Global bypass

Capability bit 4 enables a shared volatile bypass register (ID 20: 0=FX, 65535=dry). Web and the physical touch input toggle the same register. GET_CONTROLS reports the FPGA state; patch edits and preset loading do not overwrite bypass. Bypass blends to dry input in about 5.3 ms and preserves Master gain. Effect memories continue running, so bypass OFF restores the existing patch and tails. STOP resets DSP history but retains the control register.

Physical HTTM touch uses the previous project's GPIO 72, active high, synchronized to the 12.288 MHz audio clock and debounced for 122880 cycles (10 ms). A stable release after boot arms the input; holding the sensor does not repeat. Touch can toggle without a browser connection. An explicit simultaneous host write to bypass has priority; unrelated host writes do not discard a touch. Web, mini-screen and HDMI display the bypass state.

Bypass build SHA256: D80CC87DE89BD0ECD0D544B8B316968B59E1927FA42E8D287C6601AFF41EE95B. Supersedes the expanded build hash above. Resources: 10562/20736 logic, 34/46 BSRAM, 19.5/24 DSP. Setup/hold violations: zero. Loaded to SRAM only.

Bypass hardware test: 30 seconds / 1,440,000 stereo frames, 152 alternating bypass writes with register readback, zero underruns/overruns/protocol errors. Debounce/hold/startup/second press checked in RTL simulation; actual physical touch and subjective listening still require the user test.

## Signal dashboard and parallel-path diagnosis

The user's active patch was read from the connected UI: BYPASS ON, Wavefolder mixer gain=0, Delay=15%, Filter=40%. Bypass was turned OFF. Those two confirmed settings explain why changing Wavefolder drive had no audible effect. No claim of a serial effect chain: the HDL feeds every branch from the same source. A regression verifies two unity-transform branches at 25% sum to approximately 50% and removing one restores 25%.

Capability bit 5 advertises eight actual peak-envelope meters. GET_CONTROLS extends from 64 to 80 bytes, appending eight unsigned LE u16 peaks (0..32768): source, dry contribution, Glitch contribution, Delay contribution, Filter contribution, Wavefolder contribution, VCA contribution, post-bypass/post-Master output. Branch meters are post-branch-gain, before the final sum and bypass. Peak envelopes decay over about 85 ms and are reset by STOP. Web accepts 48-, 64- and 80-byte snapshots. Snapshot polling stays inside the audio transfer window to preserve throughput.

Web: prominent bypass warning, branch Mix controls, zero-mix/incomplete-route labels, measured meters, signal-dependent animated cables, explicit parallel arrangement, isolate/restore mix controls. Animated dashes indicate measured activity; their travel speed is not sample latency. HDMI: six source-parallel rows, post-gain meters, source/output meters, actual route/bypass state and synthesis-resource labels. Resource use is a compiled allocation, not CPU utilization; hiding or disconnecting a node does not free silicon. Logic-cell total on HDMI is capacity, not free-cell telemetry. Node positions/names remain web editor data; HDMI depicts the actual supported hardware route mask.

Dashboard release SHA256 450C7395BB613062EC96006E9262CD072B6C64AFDE7EBCEC22585593707E8F14. Resources: 12548/20736 logic (61%), 20.5/24 DSP (86%), 34/46 BSRAM (74%); zero setup/hold violations. Loaded to SRAM. Physical test: 1,440,000 stereo frames over 30 seconds, 152 updates, no underruns/overruns/protocol errors. Measured peak maxima [2047,1024,511,498,507,881,192,2811] for source/dry/Glitch/Delay/Filter/Wavefolder/VCA/output, respectively. Input checksums verified by hardware diagnostics. Screens were rendered from HDL and visually inspected; actual external HDMI appearance and subjective listening remain user acceptance checks.


## Encoder bank release · 2026-09-19

The physical 0/1 selector now selects 8 mappings per bank. Bank 1 defaults:
Wavefolder Drive, Wavefolder Mix, VCA Level, VCA Mix, LFO Rate, LFO Depth,
Chaos Amount, Master. Bank 0 preserves the patch's original mappings.
Web, HDMI and the 240x240 display follow the active bank. In offline web design,
buttons 0/1 select the bank to edit; when connected the physical selector controls
it. Both mapping banks are saved/exported in patches and sessions. LFO/Chaos
need a modulation destination and nonzero depth/amount to affect sound; effect
branches need a complete Sample -> effect -> Mixer route and nonzero branch Mix.

SRAM release SHA256: 1ed0535f6c6c65aa03779ced8eab5dc16630e0f0b4bf54c46f134ba420c46a0f
Post-route resources: Logic 12844/20736 (62%), DSP 20.5/24 (86%), BSRAM 34/46
(74%). Setup/hold violated endpoints: 0/0. These are fixed build resources.
Physical readback confirms panel online, bank 1 and mappings
[13,16,14,17,11,12,15,10]. Manual switch/turn and screen observation remain a
user acceptance check. Exact HDL render samples: build/hdmi-bank1.png and
build/lcd-bank1.png (synthetic display values).

Hardware regression after SRAM load: 15 seconds, 720000 frames sent/consumed,
76 control updates including bypass; zero underruns, overruns or protocol errors.
All 8 meters responded, PCM checksums matched, I2S DIN activity confirmed.
Logs: build/banks-hardware-test.txt, build/prepare-banks.txt.
A 35-second physical monitoring window observed bank 1, panel online; no manual
switch/encoder event arrived during that window. COM14 was released afterward.


## Chaos investigation · 2026-09-19

User patch readback: route mask 8 (Filter only), bypass 0, cutoff 7864/65535,
resonance 22937/65535, LFO depth 0, Chaos amount 65535, Chaos target mask 1.
Browser playback was stopped with a streaming error. A new reproduction grew
underruns from 841 to 917; the parameter settings alone did not resolve it.

The independent exact-RTL test fpga/sim/tb_modulation.sv compares two identical
3 kHz inputs with Chaos OFF/ON: 94590 changed output samples, coefficient range
2225..9865, output energy ratio 162.28. It checks actual output samples rather
than only internal oscillator motion.

Physical FPGA A/B with a fixed 2 kHz tone (scripts/check_modulation_hardware.py):
Chaos OFF filter peak 285, mean meter 275; ON peak 3440, mean meter 2191, minimum
416. Both six-second runs added zero underruns, overruns or protocol errors.
Original patch registers/routes were restored. This measures digital FPGA
branch output; analog PCM5102 audibility is still a user check.

Web mitigation: cache clips up to 30 seconds before starting (bounded 5.76 MB),
refill when 3/8 FIFO credit is free instead of 1/2, and report counter deltas on
stream failure. Actual browser/USB scheduling can still interrupt playback;
passing Python transport tests alone does not verify the browser fix.
Regression tests preserve sample order through window boundaries and looping
for 5-frame and 41280-frame clips with one initial worker read.
Current audited release (2026-09-20): see [AUDIO_AUDIT.md](AUDIO_AUDIT.md).
It supersedes older arithmetic/resource measurements above: capabilities 255,
snapshot 4, 22/24 DSP, fractional filter-state accumulation and wide mixing.

Diagnostic WAV: build/modulation-test.wav, 2 seconds of 2 kHz + 3.5 kHz at low
amplitude, to distinguish filter movement from the spectrum of a musical sample.
