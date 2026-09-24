# Bypass por componente y dos delays

La ampliación posterior de [medidores independientes](SIGNAL_METERS.md)
añade los niveles que faltaban de Delay 2 y separa procesamiento de mezcla.
Sustituye las limitaciones de visualización y el formato de snapshot descritos abajo.

Ampliación del 20/09/2026. Requiere capacidad `0x100` (GET_STATUS 511),
snapshot versión 5. No funciona con el firmware antiguo de Flash.

## Uso

1. En cada efecto pulsa **FX ON / BYPASS**. Bypass deja pasar la entrada de
   ese componente, conserva sus parámetros y su nivel de mezcla. No es mute.
   LFO y Chaos desactivan su profundidad al entrar en bypass.
2. Selecciona Delay y pulsa **Añadir Delay 2**. Hay dos instancias físicas:
   Delay 1 conserva 1–8192 muestras (170,7 ms), Delay 2 tiene 1–4096 (85,3 ms).
3. Selecciona Delay 2 y elige **Dos delays en paralelo** o **Dos delays en serie**.
   También puedes conectar los puertos manualmente. Delay 2 admite una sola
   entrada: Sample In o Delay 1. Su salida va al Mixer.
4. Ajusta tiempo, feedback y mezcla de cada delay por separado. Para una
   comparación clara empieza con un patch vacío, estos dos delays y Mixer/Out.
   Los botones de topología conservan los demás efectos del patch.

En serie, el bypass de Delay 1 deja únicamente el tiempo de Delay 2; el
bypass de Delay 2 conserva el tiempo de Delay 1. El bypass global sigue
enviando la fuente original a la salida. Los seis bypass de audio hacen una
transición de aproximadamente 5,3 ms. El cambio de tiempo/ruta del delay no
tiene todavía crossfade de lectores y puede producir un transitorio.

Los buffers continúan procesando durante bypass. Al desactivarlo puede
reaparecer su cola. Al deshabilitar la ruta completa de Delay 2 su buffer
se pausa; STOP reinicia ambos estados. No se prometen spillover ni colas
continuas entre cambios de topología.

## Contrato FPGA

- Registro 22: bits 0 Glitch, 1 Delay 1, 2 Filter, 3 Wavefolder, 4 VCA,
  5 Delay 2, 6 LFO, 7 Chaos. Un bit a 1 activa bypass.
- 24: tiempo Delay 2, `1 + (valor >> 4)` muestras.
- 25: feedback Delay 2, aproximadamente 0–50%.
- 26: contribución Delay 2 al Mixer, ganancia U0.16.
- 27: bit 0 habilita Delay 2; bit 1 selecciona Delay 1 como entrada.
  Sin bit 1 recibe Sample In. No hay matriz arbitraria de efectos.
- 32: máscara de las seis ramas originales. Delay 1 sigue calculándose
  aunque no tenga salida directa al Mixer, para alimentar Delay 2 en serie.
- GET_CONTROLS: 96 bytes. Registros 32×u16 en 0–63, mappings 64–71,
  rutas 72, flags 73, revisión u32 en 74–77, versión 5 en 78,
  reservado 79 y ocho medidores u16 en 80–95.

El JSON de patch conserva `version: 1` y añade `bypass` opcional, por ejemplo
`{"delay":true}`. Añade el nodo `delay2` y los parámetros `delay2.time`,
`delay2.feedback`, `mixer.delay2`. El nuevo lector acepta patches anteriores;
un lector antiguo puede rechazar estos campos nuevos.

## Ejecución y recursos

Los dos delays tienen memoria y estado independientes. Algunas operaciones
aritméticas de feedback, ganancia e interpolación se reutilizan en ciclos
distintos. Esto permite conservar 22/24 DSP. Las rutas de audio pueden ser
paralelas aunque compartan unidades aritméticas en el tiempo; no se debe
afirmar que cada operación dispone de un multiplicador dedicado.

Build final: 14.736/20.736 celdas (72%), 22/24 DSP (92%), 42/46 BSRAM (92%).
Setup y hold: cero endpoints violados. El presupuesto restante no permite otra instancia
idéntica de Delay 2. Glitch, Filter, Wavefolder, VCA, LFO y Chaos siguen
teniendo una instancia cada uno. Quitar un bloque no libera recursos de
la netlist. La web limita la duplicación a la segunda instancia de Delay.

El DSP ampliado termina antes de 32 ciclos de los 256 disponibles por
frame. La latencia de entrega al serializador sigue siendo un frame.
La cifra anterior de seis ciclos solo se aplica al camino sin Delay 2 y
sin bypass por componente en transición/activo.

Los medidores mantienen los ocho canales anteriores. Delay 2 no tiene
medidor propio en esta versión; la web lo indica y no inventa actividad.
HDMI muestra Delay 2 y su selección serie/paralelo; amarillo identifica
bypass individual. Los valores de recursos son de compilación, no una
medición de carga dinámica.

## Regresión

`npm run test:rtl` incluye `tb_dual_delay`: impulsos paralelos frente a
cascada, 4096 muestras de memoria, paso directo estéreo de seis bypass,
bypass de cada delay dentro de la cascada y continuidad de la transición.

`node scripts/test-dual-delay-browser.mjs` comprueba añadir Delay 2,
topologías, bypass, parámetros, persistencia y eliminación en navegador
con Rust/WASM real. `npm test` incluye los registros, offsets de snapshot,
capability gating y rechazo de rutas imposibles.

La auditoría anterior está en [AUDIO_AUDIT.md](AUDIO_AUDIT.md); sus recursos,
snapshot y plazo de seis ciclos describen la versión anterior. Los logs
de esta ampliación están en `build/dual-delay-*.log`.

Verificación física: firmware cargado en SRAM, capacidades 511 y snapshot 5.
`scripts/check_dual_hardware.py` verifica escritura y lectura de las dos
topologías y los ocho bypass, transmite 480.000 frames de tono en paralelo y
480.000 en serie y restaura registros al terminar. Ambos ensayos finalizaron
sin underruns, overruns ni errores de protocolo, con sumas PCM correctas y
actividad en I²S. La respuesta temporal de cada efecto se verifica en RTL;
estos contadores físicos no son una captura analógica de la salida del DAC.

SHA256 de la imagen cargada:
`745c78365b90a70967bf6a0adf50260716d5ca68e61bf1b52571679710e6f52f`.

Regresión final: 54/54 comprobaciones numéricas de audio, 28 tests web/WASM,
14 bancos RTL, prueba del editor en navegador y render HDMI inspeccionado.
`node scripts/test-hardware-browser.mjs --dual` añade la prueba de los
botones web contra los registros FPGA reales y requiere elegir COM14 en Chrome.

**Pendiente:** la prueba Chrome con placa no se completó en esta sesión.
El último intento devolvió `NotFoundError: No port selected by the user`
y agotó el plazo de conexión. No se considera un PASS. Sí pasan por separado
el editor con WASM real, el protocolo/control en RTL y el ensayo físico de
las dos topologías descrito arriba. El Chrome de prueba se cerró y liberó
sus recursos; la aplicación de desarrollo sigue en `http://127.0.0.1:5173/`.
