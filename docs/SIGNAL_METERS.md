# Visualización de ramas — snapshot 6

> Latest sonic firmware, resources and expanded tests: [SONIC_ENGINE.md](SONIC_ENGINE.md).

Corrección: los cables de entrada usaban el medidor posterior al volumen de
mezcla y Delay 2 no tenía medidor. Eso ocultaba actividad real, especialmente
con ganancias pequeñas o cuando Delay 1 alimentaba Delay 2 sin ir al Mixer.

GET_STATUS añade capacidad `0x200` (total 1023). GET_CONTROLS versión 6 tiene
110 bytes: conserva los primeros 80 bytes del snapshot 5 y amplía los medidores
a 15 valores u16 desde el offset 80. La amplitud se divide por 32768.

| Índice | Señal |
|---|---|
| 0 | Entrada Sample In |
| 1 | Rama Dry después de su ganancia |
| 2–6 | Glitch, Delay 1, Filter, Wavefolder, VCA después de sus ganancias de mezcla |
| 7 | Salida final |
| 8–12 | Los mismos cinco efectos antes de su ganancia de mezcla y después de su bypass individual |
| 13 | Delay 2 antes de su ganancia de mezcla |
| 14 | Delay 2 después de su ganancia de mezcla |

La web conserva compatibilidad con snapshots 3–5. No sustituye medidores
ausentes por señales de otro motor. Cada cable Sample In → efecto usa la
entrada medida; cada efecto → Mixer usa su contribución posterior a ganancia;
Delay 1 → Delay 2 usa la salida de Delay 1 anterior a su ganancia de mezcla.

Los indicadores dentro de los bloques muestran la salida anterior a mezcla.
Por tanto, un bloque puede tener actividad mientras su cable al Mixer está
apagado porque su ganancia es cero. Bypass global no detiene los motores:
se mantiene la actividad de entrada y se apagan sus aportaciones al Mixer.

Se considera actividad desde cuatro LSB PCM16 (aproximadamente −78 dBFS).
No es una afirmación de audibilidad. Los picos se retienen 200 ms antes de
decaer, para no perder transitorios entre lecturas de la web (cada 150 ms).
STOP/reset borra los medidores y su retención. La barra web tiene escala logarítmica;
HDMI usa bandas de nivel. Las animaciones solo se activan con medida de señal
y reproducción activa. HDMI distingue entrada y salida y anima todas las
ramas activas simultáneamente. Los medidores son envolventes digitales, no
capturas analógicas del PCM5102 ni seguimiento de cada muestra individual.

Pruebas: `web/src/signal.test.ts`, snapshot en `web/src/control.test.ts`,
RTL `fpga/sim/tb_signal_meters.sv`, y prueba física
`scripts/check_signal_hardware.py`. Esta última compara las dos topologías,
incluyendo Delay 1 con ganancia cero al Mixer mientras alimenta Delay 2.

Verificado en la placa: 240.000 frames por topología, cero errores de
transporte. En serie, pico bruto Delay 1 = 3248 LSB con aportación al Mixer = 0;
Delay 2 = 3668 LSB bruto y 1680 LSB después de mezcla. En paralelo ambos delays
presentan señal antes y después de la mezcla. Evidencia: `build/signal-hardware.log`.

Build final con retención: 16.626/20.736 celdas, 21/24 DSP, 42/46 BSRAM;
cero endpoints de setup/hold violados. SHA256:
`8de7a32f2d6a62dfc14f271f1662f48e1f858f2186398317b7e99a7b615e390c`.
