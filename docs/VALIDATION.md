# Validation · 2026-09-19

## Verified on this machine

| Boundary | Evidence |
|---|---|
| Native Rust | 12 tests: WAV integer/float, mono/stereo, quantization, invalid input, 44.1→48 DC/duration, CRC, framing, patch validation |
| Actual WASM in JS | 7 Vitest tests using generated `.wasm`, no decoder/protocol mocks |
| Browser worker | Playwright loads generated 44.1 kHz WAV, checks 48 kHz/1 second metadata |
| Browser playback | Real Web Audio scheduling enters dry monitor and reaches EOF; not a claim of subjective listening |
| Patch/session UI | Parameter edit, route creation, JSON download/reload, malformed import rejection, encoder reassignment |
| Hardware gating | FPGA Play disabled while disconnected; telemetry shows unavailable values |
| Responsive UI | Desktop 1536×1024 and mobile 390×844 screenshots, no horizontal document overflow |
| Web build | TypeScript strict check + Vite production build succeed |
| FIFO RTL | Full/empty, synchronous read, wrap, simultaneous push/pop, overflow/underflow, clear |
| Inherited I²S | 128 stereo frames decoded, sign, padding, pairing, clock spacing, reset |
| Streaming RTL | Prefill, 32-frame order, finite drain, underrun, stop |
| Packet RTL | Rust-generated vector, CRC corruption, resync, backpressure, truncated-frame timeout |
| Endpoint RTL | Rust packets through endpoint/FIFO to decoded I²S values 0x8000 / 0x7fff; PING/status/ACK/CRC/drain/unsupported command |
| USB enumeration | FTDI-compatible VID0403/PID6010, A/B, COM13/14; ports open at115200 |
| Actual protocol PING | **Not verified:** COM13 `FA`, COM14 timeout; neither valid |

No browser page errors were observed in the automated flow. Screenshots:
`build/browser-desktop.png`, `build/browser-mobile.png` (generated, ignored).
Browser checking also used agent-browser to inspect the initial live UI.

## Not verified / not implemented

- Physical oscilloscope measurement of LRCLK and analog audio capture.
- Unattended native Web Serial end-to-end test (manual COM14 chooser required).
- Ten-minute endurance, loop and disconnect during hardware playback.
- Subjective listening of the newly implemented Glitch/Delay/Filter and route transitions.
- User interaction check of physical encoder/web synchronization and HDMI/SPI views; touch actions remain undeployed.

The integrated board build E81A is now loaded in SRAM. UART/audio CDC and the
framed endpoint streamed 240,000 silence frames plus 960,000 tone frames, all
consumed with zero underruns, overruns or protocol errors. The MS5351 clock
readback is 12,288,000 Hz; runtime matches 48 kHz consumption. Integrated timing
has zero setup/hold violated endpoints. The asynchronous FIFO also passed a
1000-byte unequal-clock/backpressure simulation. Earlier raw ingress testing
reached 304,993 bytes/s. Flash and the prior project remain untouched.
See [hardware proof](HARDWARE_TRANSPORT_PROOF.md) for evidence and limits.

Subsequent E936 build adds digital audio diagnostics. Ten physical STOP/restart/
finite-EOF cycles passed, with a corrupt CRC rejected and parser recovery checked.
The user confirmed clean audible WAV playback in FPGA → PCM5102 mode through
the browser. This is manual end-to-end acceptance, not an automated audio capture.

## Environment findings

MSVC linker absent. Installed Rust GNU toolchain / MinGW compiler for the
project. Smart App Control rejected some generated host build programs in the
release path; native core tests and development WASM build work with pinned
Serde 1.0.217 and wasm-bindgen 0.2.100. Official prebuilt wasm-bindgen CLI was
used. Security settings were not changed. Initial Icarus VPI loader warning was
resolved by including its own binary directory in the child process PATH.

## Acceptance before DSP work

Produce a board build with preserved pin constraints and measured clocks. Test
at least ten minutes of stereo streaming, a finite file, loop, stop during fill,
disconnect, malformed packets and parameter traffic. Capture min FIFO fill,
underruns, overruns, sample counter, protocol errors, LUT/FF/BRAM/DSP and timing.
Confirm clean physical sound. Only then unlock phase 4.

## DSP build 4DAE

See DSP_V1.md for the current validation record: three 30-second real-board
control sweeps, input PCM sums checked, no faults after batching the USB
transactions; 12 Rust, 11 web tests and expanded RTL checks. The encoder panel
reports online. Hardware DSP listening and the physical rotary/display user
test are still separate from automated digital verification.
