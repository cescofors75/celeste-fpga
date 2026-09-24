# DEMO LIVE

Connect the sonic firmware, then press **DEMO LIVE**. The browser generates a
48-second stereo ambient source and sends its PCM to the FPGA. Effects run on
the FPGA; this is not a browser simulation of the DSP.

Six eight-second scenes cycle: dry, Filter/Wavefolder in parallel, two parallel
delays, cascaded delays, LFO/Chaos modulation, and Glitch. Automation uses the
device sample counter. The fabric graph follows the programmed routes; its
meters still come from device telemetry. Existing firmware also receives the
automated parameters/routes for its hardware displays.

**Pausar automatización** keeps audio playing and freezes the score. Manual
parameter edits pause automation. **Stop** stops audio and pauses the score.
**Salir** stops playback and restores the previous patch, source, output mode,
loop setting and global bypass. The demo does not overwrite the saved patch.
Closing/reloading the page discards in-memory audio, as with ordinary WAV use.

Audio up to 60 seconds is cached before playback (maximum 11.52 MB PCM).
DOM status rendering runs independently of serial refills. Serial audio uses
device acknowledgements rather than a browser timer to pace FIFO credit polls.
Any underrun, overflow or protocol fault stops playback and pauses automation.

Validation: `npm test`, `npm run build`, and
`node scripts/test-live-demo-browser.mjs`. The latter uses a simulated serial
transport and checks scene progression, pause, STOP, restoration and repeat
start. It does not establish physical audio quality or transport reliability.
Physical verification on COM14 (2026-09-21): the deep-SDRAM firmware and
optimized worker transport completed 315.38 seconds of automated DEMO LIVE
(more than six complete 48-second cycles) with zero underruns, overruns or
protocol errors. The patch stayed animated and real scene routes/controls
changed. Pause held the scene while the consumed-sample counter continued;
resume, Stop and restoration of the previous patch/source also passed.
Evidence: build/usb-deep-live.json. All 49 software tests and 20 RTL benches
pass, as do the production build and simulated browser lifecycle.

Earlier 171 ms and 683 ms queues failed under measured USB stalls. The final
131072-frame reservoir holds 2.731 seconds of source PCM; playback starts after
prefill. DSP controls still act after that queue. The receiver tolerates long
mid-packet gaps without weakening CRC. See [USB_STREAMING.md](USB_STREAMING.md)
for the measured causes, intermediate failures and physical interruption tests.
These are digital transport checks, not an analog noise/distortion measurement.
