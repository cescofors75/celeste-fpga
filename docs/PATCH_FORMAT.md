# Patch and session v1

`patches/parallel-dreams.json` is the canonical example. `celeste-core` is the
validation authority. Unknown fields, nodes, parameters, invalid versions,
out-of-range/nonfinite normalized values, duplicate routes, cycles, invalid
encoder numbers and invalid modulation assignments are rejected.

Patch contains format/version/name, audio `routes`, normalized `parameters`,
`hardware` encoder assignments, separate `modulation` routes and configurable
`touch` actions. Audio nodes: sample, future line, glitch, delay, filter,
wavefolder, vca, mixer, out. Output accepts only mixer; non-mixer nodes accept
one driver. Capability validation against actual FPGA firmware is a distinct
deployment step, not implied by a syntactically valid design graph.

Session contains format `celeste-session`, version 1, patch, sample metadata
`{name,size,sha256}` or null, position in 48 kHz frames, looping bool, optional
tempo. The original WAV is never embedded. Re-import requires an identical
SHA-256/size WAV and clamps position to its prepared length. Browser stores
only the current patch in localStorage; sessions are explicit JSON downloads.

Labels: delay.time = 1 + 599*n milliseconds (requested range only); cutoff =
20*1000^n Hz (20 Hz..20 kHz); lfo.rate = .05 + 9.95*n Hz; other values percent.
These are documented host mappings, not final hardware register quantization.
The editor supplies factory defaults for omitted parameters when importing a
valid partial patch, then exports the complete resolved parameter map.
