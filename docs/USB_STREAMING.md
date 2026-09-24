# USB streaming stability

The original 8192-frame queue covered only 170.7 ms. Instrumented live runs
recorded consecutive USB operations taking 149 and 130 ms, exhausting that
queue. Dedicated-worker playback and batched controls improved the normal
headroom but did not eliminate the worst-case underrun. Direct Python tests
also reproduced failures, independently of the browser UI.

A second failure was reproduced independently: the old parser abandoned an
incomplete packet after 2^20 audio clocks (85.3 ms). A deliberate 200 ms pause
inside one AUDIO packet caused no ACK and incremented the protocol error
counter, even with playback stopped (`build/packet-gap-before.log`). The parser
now waits 2^25 clocks (2.731 s). CRC rejection remains unchanged. This change
prevents a recoverable delivery delay from becoming a lost packet and a
ACK timeout. Audio windows allow 3.5 seconds for the checked response.

The new board build stores the source PCM queue in the package SDR SDRAM:
131072 stereo PCM16 frames, 512 KiB, 2.731 seconds total reserve. The DSP's delay and
Glitch memories are unchanged. Internal BSRAM usage drops from 46 to 30 blocks.
The protocol advertises capacity 131072 and capability bits 0x800/0x1000
(total 8191). GET_STATUS has 40 bytes with uint32 capacity/fill at offsets 32/36.
Hosts must fill the advertised capacity before START; an 8192-frame first
write alone does not provide the new reserve. The intermediate 32768-frame
build still exhausted its reserve on a measured 656 ms in-browser USB/ACK stall.

`sdram_fifo.sv` uses bank 0, single-word bursts, CAS 2, automatic precharge,
refresh at most every 80 audio-clock cycles plus one transaction, and a
half-cycle-shifted SDRAM clock. STOP discards buffered PCM and reinitializes
the controller. The validated interruption duration is recorded below,
not a promise of immunity to arbitrary USB disconnects or operating-system
stalls. Failures remain visible and stop playback; samples are not silently
dropped, repeated or resampled to hide errors.

The web moves the serial port and complete PCM playback loop for sources up
to 60 seconds into a dedicated worker. Control writes and snapshots share
the audio batches. Sending each separately introduced unnecessary USB
round trips. PCM windows contain up to 64 packets per write (16384 frames).
An intermediate 16-packet version still underrran after about 150 seconds:
consecutive 330/137/99/154 ms batches drained the reservoir, with no protocol
error. Rejoining the 32-packet window amortizes its ACK/status turnaround.
The earlier large-window packet loss was traced to the old parser timeout.
A fixed 8192-frame window also proved insufficient under consecutive long
ACK delays. Refills now use the available FIFO credit, capped at 16384 frames,
so a depleted reservoir can recover in one continuous OS-queued write. The
Web Serial buffer is 128 KiB. A measured 306 ms batch left 17384 frames; the
next adaptive 15384-frame write raised the level to 21424, without an underrun.
Longer sources retain the chunked path. Diagnostics retain the last 16 batch
durations, preparation/write/ACK timings and FIFO levels. Four recent batches
are published with throttled status updates; connection clears old diagnostics.
Rust/WASM uses the release profile: a local 32-packet preparation benchmark
dropped from 7.59 ms to 0.91 ms. The UI does not render every ACK.

Validation tools:

- `npm test -- --maxWorkers=1` and `npm run build`.
- `npm run test:rtl`, including the SDRAM queue simulation.
- `scripts/check_sdram_hardware.py --pause-ms 2000`: mute the DAC, send at least
  100000 pseudorandom stereo frames (three FIFO wraps plus 123 on the deep build), verify source sums and sample count,
  deliberately suspend USB delivery, check all transport counters, restore Master.
- Add `--inside-packet` to suspend halfway through an AUDIO packet during
  playback; `scripts/check_packet_gaps.py` also tests 200/500/1000/2000 ms gaps while
  stopped and verifies that a deliberately corrupted CRC is still rejected.
- `scripts/hardware_stream.py --seconds 180 --tone --dsp-sweep --window-packets 32`.
- `scripts/test-live-demo-browser.mjs`: simulated UI lifecycle, not physical proof.

The SDRAM package interface names are documented by the original controller
example at https://github.com/nand2mario/sdram-tang-nano-20k/blob/main/src/sdram_top.v.
This project's queue controller is independently implemented for the 12.288 MHz
audio clock. Device information: https://wiki.sipeed.com/hardware/en/tang/tang-nano-20k/nano-20k.html.

## Validation of the intermediate 683 ms candidate, 2026-09-21

Bitstream SHA256: 97707af63e516a36e90caac2c79010a0ad9b5336df9bb774458e845a347aeb3d.
Gowin reports zero setup/hold violations; resource use is 17274/20736 logic,
30/46 BSRAM and 22/24 DSP. All 19 RTL benches pass, including exact full-depth
SDRAM PCM, refresh, wrap and display pipeline checks. All 47 web tests pass
with `--maxWorkers=1 --testTimeout=30000`; the default 5-second timeout was too
short for the exhaustive sample assertions on this loaded Windows host.
The production build and simulated browser lifecycle pass.

The flashed board accepted 200/500/1000 ms gaps within packets while stopped.
A deliberately corrupt CRC was rejected. After boot from Flash, a 500 ms
mid-packet pause during playback preserved all 100000 frames and both source
checksums with zero underruns, overruns or protocol errors. This validates the
transport digitally; it does not measure analog noise or distortion.
Logs: build/usb-final-packet-gaps.log, usb-final-boot-gap.log,
usb-final-rtl.log, usb-web-tests-final.log, usb-browser-lifecycle.log.

The temporary FTDI latency experiment was restored to 16 ms; the fix does not
require a driver setting change. The 1-second stopped-packet test validates
parser recovery only: it does not imply one second of uninterrupted playback
from a 683 ms reservoir.

## Deep-reservoir candidate — 2026-09-21

SHA256: 75b26393828728af9f971039333d245591bb22d82288210aac59ffa0c51ff482.
Capacity 131072 stereo frames, capabilities 8191. Gowin: zero setup and zero
hold violations; 17193/20736 logic, 30/46 BSRAM, 22/24 DSP.
All 20 RTL benches and 49 web tests pass; production build passes.
The real board accepted stopped-packet gaps of 200/500/1000/2000 ms and still
rejected a corrupt CRC. A 2000 ms mid-packet gap while playing passed with
393339 consumed frames, expected source checksums and no new transport errors.
The one pre-existing protocol error in that run is the intentional CRC test.
Logs: build/usb-deep-packet-gaps.log, usb-deep-active-gap.log, usb-deep-rtl.log,
usb-web-tests-final.log and usb-web-build-final.log.

Final physical live test: 315.38 seconds (15138364 consumed frames) of automatic
scene changes in the user's Codex browser, over six full 48-second loops, with
zero underruns, overruns or protocol errors. Pause held the scene while audio
continued to frame 16311281; resume, Stop and patch/source restoration passed.
Evidence: build/usb-deep-live.json. The same image was programmed and verified
in SPI Flash, then booted with operation 1. After startup, the 2000 ms mid-packet
interruption passed again with 393339 pseudorandom frames, checksums
9719782 / 4289400339 and all transport counters zero (usb-deep-boot-gap.log).
An initial probe made during boot timed out; it is preserved in
usb-deep-early-probe.log. This is not a physical unplug/replug test.
