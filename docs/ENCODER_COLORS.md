# Encoder colors

`shared/palette.json` is the single palette for the web, encoder LEDs and the
HDMI/LCD renderer. Run `node scripts/generate-palette.mjs` after changing it;
`node scripts/generate-palette.mjs --check` detects stale FPGA tables.

The eight physical LEDs use the active hardware mappings, including bank 0/1,
live reassignment and the extended Delay 2 / sonic parameters. Effect mix
controls use their effect's color; master and dry mix remain neutral. The ninth
switch LED retains its previous color.

The web uses RGB888; HDMI and LCD use the corresponding RGB565 values. Physical
LED channels are scaled uniformly to 1/8 brightness. This preserves the palette
with quantization and avoids driving the panel at full brightness. Perceived
brightness and hue can vary between LED, LCD and HDMI displays.

The M5 panel's register format is R,G,B. Our I2C master sends the low byte first,
so the generated 24-bit LED words contain R in bits 7:0 and B in bits 23:16.
Reference: https://raw.githubusercontent.com/m5stack/M5Unit-8Encoder/master/src/UNIT_8ENCODER.cpp

Validation:

- `fpga/sim/tb_palette.sv`: both default banks, RGB byte ordering, live and
  inactive-bank reassignment, disconnected-panel bank retention and HDMI colors.
- `tb_controls.sv`: framed protocol accepts extended mappings and rejects
  reserved/read-only parameter assignments.
- `web/src/palette.test.ts`: effect mix colors and default mappings.
- `node scripts/test-palette-browser.mjs`: rendered encoder and mini-display
  colors, bank changes and remapping, with no page errors.

The protocol now permits the existing encoder parameters 23–26 and 28–31.
Previously its mapping validator only accepted 0–17 despite the web offering
these extended parameters. Reserved registers remain unavailable as mappings.
