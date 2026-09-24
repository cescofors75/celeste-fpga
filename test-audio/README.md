# Test audio

`npm run test:browser` creates a one-second, 440 Hz mono WAV at 44.1 kHz with
peak level 0.125 in `build/test-44100.wav`, loads it through the real WASM worker,
and checks conversion and playback. Rust tests generate 8/16/24/32-bit PCM and
float WAVs in memory, including clipping and nonfinite values.

For hardware acceptance, additionally use stereo channel-ID, impulse, silence,
full-scale positive/negative, and at least ten minutes of uninterrupted content.
Record FIFO minima, underruns/overruns and protocol errors. Verify frequency
and LRCLK with measurement equipment; a successful simulation is insufficient.
