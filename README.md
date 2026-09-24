# CELESTE FPGA · Parallel Fabric

Revisión de septiembre de 2026, actualizada el **24/09/2026**. Firmware Tang Nano 20K, editor web, presets, HDMI, ST7789 y dos bancos de ocho encoders.

## Versión de referencia

**PCM1808 Line-In → motores DSP → PCM5102**, estéreo a 48 kHz. El firmware ampliado está grabado y verificado en flash externa. El editor web controla rutas y parámetros por USB; esta versión de Line-In **no recibe música por USB** ni devuelve audio al ordenador.

- Glitch, Delay, Filter LPF/HPF/BPF/notch, Wavefolder, VCA y Delay 2.
- Chorus, Flanger, Bitcrusher, Freeze, Tremolo y Auto-pan; LFO, Chaos y Envelope para modulación.
- Bypass por componente, Mute/Solo, dos delays en paralelo o serie (170,67 / 85,33 ms).
- HDMI: valores del banco activo en columna izquierda y ramas paralelas con medidores de contribución. Las ondas de la web son ilustrativas; las barras usan telemetría real.
- DEMO LIVE **Parallel Tides**, composición original de 4:34, 168 BPM y doce escenas. Salida analógica del PC → PCM1808; el navegador automatiza los efectos reales.
- 16 asignaciones físicas; pulsación corta Mute y mantenida Solo, con excepciones para moduladores/Master documentadas.

[Bitstream estable y fuente de referencia](firmware/stable/) · [Estado final](docs/SEPTEMBER-2026-REVIEW.md) · [Plugin VST3/AU y Tang Control](https://github.com/cescofors75/celeste-VST3) · [Portfolio](https://cesco.dev/proyectos/celeste-parallel)

## Ejecutar la web

Node 24, Rust con target wasm32-unknown-unknown y wasm-bindgen-cli **0.2.100**:

```sh
npm ci
rustup target add wasm32-unknown-unknown
cargo install wasm-bindgen-cli --version 0.2.100 --locked
npm run wasm
npm test
npm run build
npm run dev -- --port 5173
```

Abrir http://127.0.0.1:5173 en Chrome/Edge con Web Serial. Un solo propietario del puerto: cerrar la conexión del plugin antes de conectar la web. COM14 corresponde al equipo de desarrollo, no es un número universal. Para Line-In no hace falta cargar WAV.

## Firmware y hardware

`firmware/stable/manifest.json` identifica el binario exacto y sus pruebas. El ZIP de fuentes conserva la revisión que lo produjo. El árbol actual contiene también experimentos independientes (Euclidean/Rhythm, Chaos/Cellular/Feedback); no son la imagen estable que arranca la placa.

Compilación de la rama ampliada: Gowin Education 1.9.11.03, `scripts/build_hdmi_expanded.tcl`. Recursos de referencia: 19.384/20.736 celdas, 38/46 BSRAM y 23/24 DSP; no equivalen a una CPU con porcentaje libre ni a capacidad para duplicar efectos sin recompilar.

Cableado probado: ADC BCK→80, LRCK→86, DOUT→85, GND común y MCLK sin conectar; el ADC actúa como maestro. PCM5102 BCK→73, DIN→74, LRCK→75. Son números de pin de la FPGA según `fpga/constraints/line_in.cst`. Retirar microSD. La alimentación y los puentes dependen de la revisión de la placa PCM1808; este repositorio no certifica módulos visualmente similares.

Los scripts históricos de carga contienen rutas del equipo de desarrollo y algunos necesitan snapshots locales. No se ejecutan al instalar la web. El reloj de audio de la Tang es 12,288 MHz; no cambiar el modo eléctrico de los relojes sin comprobar la placa.

## Evidencia y límites

70 pruebas web documentadas; compilación TypeScript/Vite; una pasada completa de DEMO LIVE sin pérdidas y arranque desde flash verificado. También se observaron pérdidas intermitentes del ADC en otras sesiones: **la causa no está resuelta**. No hay medidas analógicas de ruido/distorsión ni certificación de continuidad prolongada. Las simulaciones RTL más recientes no se ejecutaron localmente por Control de aplicaciones de Windows.

El firmware tiene paralelismo físico entre bloques; no permite añadir instancias ilimitadas desde la web. El plugin nativo procesa en CPU y su modo Tang Control envía parámetros, no audio por USB.

## Mapa

- `fpga/`: RTL, constraints y bancos de prueba.
- `web/`, `rust/`, `shared/`: editor, protocolo/WASM y paleta común.
- `patches/`: presets; `scripts/`: build, pruebas y utilidades.
- `docs/`: evolución técnica y limitaciones por revisión.
- `firmware/stable/`: única imagen recomendada para reproducir esta revisión.

El código del plugin se mantiene en su propio repositorio. No se incluyen herramientas Gowin/JUCE, credenciales, grabaciones personales ni directorios de compilación.
