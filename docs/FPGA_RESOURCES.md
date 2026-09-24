# FPGA resources and timing

Target: Tang Nano 20K, GW2AR-18C. Sonic engine + dual delay + independent signal meters,
Gowin 1.9.11.03 Education, 2026-09-20. Capabilities 2047, snapshot 6.
Reports: `build/stream/impl/pnr`. Details: [SIGNAL_METERS.md](SIGNAL_METERS.md).

| Metric | Current measured result |
|---|---|
| Logic | 17378 / 20736 (84%), including 13650 LUT, 3614 ALU, 19 RAM16 |
| Register | 6249 / 15750 (40%) |
| BRAM | 46 / 46 (100%) |
| DSP | 22 / 24 (92%); synthesis includes shared arithmetic and video |
| Setup / hold violated endpoints | 0 / 0 (includes recovery/removal checks) |

Logical storage budget: board FIFO 8192×32=262144 bits (32 KiB),
protocol staging 1024×8=8192 bits (1 KiB). Physical block packing and read-port
inference must be checked with Gowin. No full-length sample resides in FPGA.
Delay 1: another 8192×32 bits (32 KiB), 170.67 ms stereo. Delay 2 adds
4096×32 bits (16 KiB), 85.33 ms stereo. Glitch adds 2048×32 bits (8 KiB), up to 42.67 ms stereo capture/replay. The display snapshot
uses a bundled-data handshake to avoid wasting nine BRAM blocks on a wide,
shallow FIFO. Pixel timing margin is narrow but positive at 25.2 MHz in Gowin's
specified slow corner; further graphics need a fresh timing check.

Audio clock constraint is 81.380208 ns for 12.288 MHz on MS5351 CLK2/pin13.
PCM5102 wiring remains 73/74/75. The serializer reset uses a falling-edge
synchronizer placed at R47C32, as in the working prior lab. Audio and UART/video
domains are asynchronous and communicate through Gray-pointer FIFOs.
PR1014 generic clock routing warnings remain; timing closure is not a jitter
measurement. Scope reset and audio reset assert asynchronously and release
synchronously in their respective domains.
