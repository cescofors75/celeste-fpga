# Validación de la ampliación — 24 septiembre 2026

Firmware compilado y cargado en SRAM de la Tang Nano 20K. No se ha escrito
la flash persistente. Copia: `deliverables/celeste_line_in_expanded_fx.fs`.

SHA-256: `F3846E1CAF790F2B101C94AEB066E939E28E62C749967BD3443AC1CC6AABBEB2`.

## Resultados confirmados

- Gowin: bitstream generado; cero endpoints con violación Setup y Hold.
- Lógica 17.976/20.736; grupos físicos CLS 9.886/10.368; RAM 38/46; DSP 23/24.
  El margen de memoria no equivale a capacidad ilimitada para más motores.
- Web: 60 pruebas en 14 archivos, todas pasan. Tras los últimos cambios de
  validación, otras 15 pruebas focalizadas pasan. TypeScript y build Vite pasan.
- Rust/WASM real: presets, formato de patch, PCM y remuestreo incluidos en las
  pruebas anteriores. La ejecución nativa de Rust fue bloqueada por Control de
  aplicaciones de Windows; no se cuenta como una prueba pasada de esta revisión.
- Modelo entero: 12.000 frames estéreo, seis resultados distintos, Solo igual a
  ruta aislada, silencio, Mute y bypass; 2.621.440 casos exactos del Master.
  Esto es un modelo de referencia, no una simulación RTL ejecutada.
- Placa: handshake anuncia capacidad ampliada 26623. Parámetros nuevos aceptados
  y devueltos. 16 escrituras/lecturas de máscaras Mute/Solo verificadas.
- Diagnóstico físico posterior a la carga: cero errores de protocolo, underruns,
  overruns y fallos del plazo de procesamiento. Periodo de entrada 255–256 clocks.
- Navegador: tester y botones Mute/Solo visibles; cambio de Solo comprobado en
  modo offline, sin errores de consola durante la comprobación.

## Pendiente — no afirmar que está validado

- La prueba de efectos con LINE IN no pudo continuar: al ejecutarla solo había
  aproximadamente 14 LSB de pico de entrada, ruido de fondo. El script exige
  música continua. No se ha confirmado todavía salida audible de cada motor,
  Mute/Solo sobre señal real ni la cadena de los dos delays en esta revisión.
- Corto/Mantenido del array de encoders requiere pulsación manual.
- Simulación RTL: Icarus está bloqueado por Control de aplicaciones de Windows.
- Calidad analógica PCM5102: pendiente de escucha; no hay grabación de retorno
  para medir distorsión o ruido.
- El HDMI ampliado esta cargado en SRAM. Falta confirmar la imagen en el
  monitor fisico. Ver `HDMI_EXPANDED.md` para la validacion de esta revision.

Para completar la prueba física, reproducir música por PCM1808, dejar COM14
libre y ejecutar `scripts/check_expanded_live.py`. Restaura los controles al
terminar. Evidencias: `build/expanded-control-validation.json`,
`build/expanded-load.log`, `build/independent-fx-protocol-build.log`,
`build/expansion-reference/report.json` y los logs de pruebas `expanded-*.log`.
