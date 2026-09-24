# Hardware transport proof · 2026-09-19

After connection confirmation, Gowin identified device ID `0x0000081B`.
Original SRAM UserCode: `0x0000C7E9`.

## Pin provenance and diagnostics

Clock pin 4, reset 88, UART RX 70, UART TX 69 come from the
[official Sipeed UART constraints](https://github.com/sipeed/TangNano-20K-example/blob/main/uart/src/top.cst).
LED 15 comes from inherited CELESTE constraints. No pin was guessed.
The diagnostics use existing 27 MHz / 9 = 3 Mbaud, not the audio clock.

`uart_probe` passed simulation with 512 consecutive bytes. After synthesis and
place-and-route it was loaded only into SRAM; UserCode `0x585F` read back.
COM14 echoed 16/32/48/64 bytes correctly, but large echoes lost data (initially
256 sent, 71 returned). Echo alone cannot locate the loss direction.

`uart_sink_probe` counts payload bytes and accumulates a 32-bit sum, returning
only a 12-byte count/sum/framing-error report on request. Readback UserCode:
`0x2727`. Protocol: 0 clears; 255 requests report; 1..254 are payload. Benchmark
payload repeated ASCII 65..87, avoiding command bytes.

| Sent | FPGA count | Sum matched | Framing errors | Time including report |
|---:|---:|---|---:|---:|
| 64 | 64 | yes | 0 | 18.58 ms |
| 256 | 256 | yes | 0 | 7.47 ms |
| 1024 | 1024 | yes | 0 | 11.58 ms |
| 8192 | 8192 | yes | 0 | 35.66 ms |
| 65536 | 65536 | yes | 0 | 218.54 ms |
| 2097152 | 2097152 | yes | 0 | 6.8760765 s |

Measured host→FPGA bulk throughput: **304,993 bytes/s**, exceeding the raw
stereo PCM16 requirement of 192,000 bytes/s. Counts/sums are not order-sensitive
checks; framed audio must still validate CRC and sequences. Small transaction
latency is material: stop-and-wait requests can erase this bandwidth margin.

The directional result suggests the echo loss is in continuous FPGA→host
return traffic. It does not identify the specific bridge/driver fault. Keep
status/ACK messages short; optimize and measure the framed host scheduler
before claiming reliable audio. No PCM5102 audio was tested here.

## Gowin resources

| Diagnostic | LUT | ALU | Registers | BSRAM | DSP | Fmax | Setup/hold violations |
|---|---:|---:|---:|---:|---:|---:|---|
| Echo | 163 | 21 | 112 | 1 | 0 | 232.013 MHz | 0/0 |
| Sink | 320 | 70 | 271 | 0 | 0 | 176.080 MHz | 0/0 |

Both constrained at 27 MHz. Reports under `build/uart_probe` and
`build/uart_sink`. Warning PR1014 about clock routing remains; timing closure
of these diagnostics is not an audio jitter assessment. UART input uses a
two-flop synchronizer; asynchronous input/reset paths are excluded from timing.

## State after the initial diagnostic

Restored the exact previous SRAM image from the prior project's
`releases/minidrummachine-fx-fast/minidrummachine-fx-fast.fs`.
Independent readback confirms **C7E9** again. Flash was not erased/programmed.
The diagnostic temporarily replaced HDMI/audio; the old image was restored
at that point. The subsequent integrated test below supersedes this state.

## Integrated streaming test — 2026-09-19

Current SRAM image: `build/stream/impl/pnr/celeste_stream.fs`, UserCode **E81A**.
Clock MS5351 CLK2 -> pin 13 is configured to 12,288,000 Hz with
`pll P1:35,1217,3125 D2@P1:72,0,1 O2@D2:0` (no save). Console readback confirms
that frequency. This is register readback and sample-count/wall-time evidence,
not a physical oscilloscope measurement. UART remains 27 MHz / 9 = 3 Mbaud.

The board combines two asynchronous byte FIFOs, framed endpoint, an 8192-frame
PCM FIFO, inherited I2S and inherited HDMI showing actual PCM on its scope.
The host writes up to 32 packets together, bounded by reported FIFO free space.

| Physical board test | Sent / consumed stereo frames | Underruns / overruns / protocol errors | Minimum polled fill | Wall time including prefill |
|---|---:|---|---:|---:|
| 5 seconds silence | 240,000 / 240,000 | 0 / 0 / 0 | 2738 | 5.125 s |
| 20 seconds tone | 960,000 / 960,000 | 0 / 0 / 0 | 3814 | 20.125 s |

Tone: 440 Hz L, 660 Hz R, amplitude 2048/32768. Script
`scripts/hardware_stream.py` uses actual COM14, checks every ACK sequence and
CRC, and asserts exact consumption at EOF. No physical audio capture was made;
clean audible output still requires the user's listening confirmation.

`scripts/prepare_board.py` was run successfully after these tests: it configures
the volatile clock, checks the timing report, loads SRAM and validates PING and
status. Current counters were reset by that reload. Flash and the prior project
remain untouched. Power cycling restores the old Flash image and needs prepare.

Browser/WASM tests pass, but the native Chrome serial chooser prevented unattended
end-to-end hardware browser validation. `node scripts/test-hardware-browser.mjs`
opens Chrome and waits for manual COM14 selection, then tests ten seconds through
the actual WASM/Web Serial stack. This test has not yet passed on hardware.
Long-duration, loop, disconnect and listening acceptance remain pending.

## Reload, diagnostics and listening confirmation

After a user power cycle, the old Flash image booted as expected. Reloaded
CELESTE and repeated 15 seconds of tone: 720,000 frames consumed exactly,
zero underruns/overruns/protocol errors, minimum polled fill 2490. The user did
not hear this tone and confirmed that the older firmware had produced sound.
Do not infer the reason for the unheard brief tone from the successful counters.

`hardware_regression.py` then passed ten cycles of stopped prefill, flush,
running STOP with stable consumed count, restart and exact finite EOF. A
deliberately corrupt CRC was rejected without consuming samples; a subsequent
PING succeeded. Only the expected single protocol error was recorded.

Built and loaded **E936**, which adds command 8 for measured sample sums, peaks,
nonzero frames and digital I2S activity. No audio-path change was made. Its RTL
diagnostics passed known-sample/serialized-bit assertions; timing has zero
setup/hold violated endpoints. The native diagnostic run was blocked by COM14
being in use by the user's browser, so hardware sums have not been compared yet.

The user then explicitly confirmed **a WAV in “FPGA → PCM5102” mode sounds good
through the PCM5102**. This is manual end-to-end browser/WASM/Web Serial/FPGA/DAC
listening validation. No analog recording or oscilloscope capture was made.
The automated native-browser test remains uncompleted; prolonged playback,
loop and reconnect under load still need acceptance. The user's active browser
playback was left uninterrupted. SRAM only; no Flash changes.
