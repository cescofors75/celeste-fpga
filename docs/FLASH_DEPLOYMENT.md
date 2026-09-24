# Flash deployment — 2026-09-20

User requested persistent flashing. Programmed external SPI flash EF4017 using Gowin programmer operation 9 (erase, program, verify): success. Reprogram operation 1 then booted the stored image successfully.

Bitstream: build/stream/impl/pnr/celeste_stream.fs
SHA256: 8de7a32f2d6a62dfc14f271f1662f48e1f858f2186398317b7e99a7b615e390c

Saved audio clock O2=12288000 Hz via pll_clk -s; console reported save success. Configuration: pll P1:35,1217,3125 D2@P1:72,0,1 O2@D2:0.

After reprogram: CELESTE/1 handshake, capabilities 1023, 48000 Hz. Two-second silent stream: 96000 frames sent and consumed, zero underruns, overruns, protocol errors, and nonzero output samples. Physical USB power cycle has not been performed.

Clock persistence command reference: https://en.wiki.sipeed.com/hardware/en/tang/tang-nano-20k/example/unbox.html


## Sonic engine update — 2026-09-20

External flash erase/program/verify succeeded for SHA256
8afd7ca4abd1c2e07a0e81eeaf038ff6638025ce6456d793fae8766146483b32.
Capabilities 2047, snapshot v6. Operation 1 reloaded from flash; an immediate
protocol probe timed out during startup, then the next probe succeeded.
Post-boot two-second silence: 96000 frames consumed, zero transport faults,
zero nonzero input samples and zero serialized I2S one bits. No physical
power cycle was performed. The previously saved 12.288 MHz clock remains.

Before flashing, eight physical audio configurations each completed 48000
frames with zero transport errors, distinct I2S one-bit counts and nonzero
measured DSP output. Logs: build/sonic-hardware.log, sonic-flash.log,
sonic-reboot.log and sonic-boot-test.log. Full behavior and limitations are
in SONIC_ENGINE.md. Previous verified image retained in build/verified-v6.

## USB stability update — 2026-09-21

External SPI flash erase/program/verify succeeded, then operation 1 booted the
stored image. SHA256:
97707af63e516a36e90caac2c79010a0ad9b5336df9bb774458e845a347aeb3d.
Capabilities 4095, FIFO 32768 stereo frames, snapshot v6. Timing analysis:
zero setup and zero hold violations. Resources: 17274/20736 logic cells,
30/46 BSRAM, 22/24 DSP. Previous sonic image retained in build/pre-sdram-backup.

Before flash, the receiver accepted 200, 500 and 1000 ms pauses inside valid
packets while stopped; a corrupt CRC was rejected and PING recovered. After
boot from flash, a 500 ms pause inside an AUDIO packet during playback passed:
100000 exact frames, source checksums 3276681200 / 3276637616, zero underruns,
overruns and protocol errors. Logs: build/usb-final-packet-gaps.log,
usb-final-active-gap.log, usb-final-flash.log, usb-final-reboot.log,
usb-final-boot-gap.log. A physical unplug/replug has not been performed.

See USB_STREAMING.md for the cause, host changes and live validation.

## Final deep-reservoir deployment — 2026-09-21

External SPI flash erase/program/verify succeeded for SHA256
75b26393828728af9f971039333d245591bb22d82288210aac59ffa0c51ff482.
Operation 1 booted the stored image: capabilities 8191, 131072 stereo frames
(512 KiB / 2.731 seconds), status 40 bytes, control snapshot v6 unchanged.
An immediate probe during startup timed out; a subsequent probe and full
post-boot test passed. No physical USB unplug/replug was performed.

Post-boot validation deliberately paused for 2000 ms inside an AUDIO packet.
All 393339 pseudorandom stereo frames were consumed; source sums matched
9719782 / 4289400339; underruns, overruns and protocol errors were all zero.
This pattern differs between 65536-frame blocks to detect high-row aliasing.
Logs: build/usb-deep-flash.log, usb-deep-boot.log, usb-deep-early-probe.log,
usb-deep-boot-gap.log. The earlier 683 ms image is preserved in
build/usb-683ms-verified; the original sonic image in build/pre-sdram-backup.

The same final bitstream passed 315.38 seconds of automated DEMO LIVE in the
user's Codex browser before Flash programming, with all transport counters zero.
Pause/resume, Stop and original patch restoration passed. Evidence:
build/usb-deep-live.json. Timing: setup 0 / hold 0 violations. Resources:
17193/20736 logic, 30/46 BSRAM, 22/24 DSP. All 20 RTL benches and 49 web tests
pass; production build and simulated browser lifecycle pass.

## Shared encoder palette — 2026-09-21

SPI flash erase/program/verify succeeded for SHA256
a158ce77bd38e0dee9e09e6cad3ed684d5db8748b286e098faf2ca299b880155.
The previous deep-buffer image is preserved in `build/pre-palette-backup`.
Timing: zero setup / hold violations. Resources: 17892/20736 logic,
30/46 BSRAM and 22/24 DSP. All 21 RTL benches and 51 web tests passed;
production build and palette browser checks passed. Web tests used one worker
and a 20-second test timeout while Gowin was compiling (the standard 5-second
limit timed out in existing PCM/stream tests under concurrent load).

Initial SRAM hardware validation passed: the real panel remained online while
23 parameter mappings were accepted and read back, then the original mapping
was restored. A ten-second silence stream consumed exactly 480000 frames with
zero underruns, overruns and protocol errors; I2S diagnostics matched silence.

After boot from flash, the FPGA responds with capabilities 8191 and the expected
131072-frame FIFO, but the encoder panel reports offline. A subsequent reload
of the same image into SRAM did not restore the panel. A physical power cycle
of board and panel has been requested; post-power-cycle confirmation is pending.
Do not treat physical LED observation or post-boot panel recovery as verified.

Evidence: `build/palette-{build,rtl,web-tests,web-build,browser,hardware,audio,flash}.log`,
`build/palette-boot-status.log`, `build/palette-boot-hardware.log`,
`build/palette-recovery.log`. See `docs/ENCODER_COLORS.md` for palette details.

## Requested reflash — 2026-09-21

Reflashed the existing shared-encoder-palette image (SHA256 a158ce77bd38e0dee9e09e6cad3ed684d5db8748b286e098faf2ca299b880155) to external SPI Flash. Gowin operation 9 reported program and verify success; operation 1 restarted from Flash. Timing report: zero setup and hold violations.

Post-boot CELESTE/1 handshake passed, capabilities 8191, 131072-frame FIFO at 48000 Hz. Two seconds of silence consumed all 96000 frames with zero underruns, overruns and protocol errors; I2S diagnostics matched silence. The encoder panel still reports offline; physical power cycling and visual/audio confirmation remain pending. Evidence: build/reflash-20260921{,-boot,-test,-panel}.log.
