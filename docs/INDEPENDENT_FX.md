# CELESTE: ramas independientes, tester y Mute/Solo

## Uso

En la web, conecta COM14 con el firmware ampliado y abre **Tester de componentes**.
Selecciona un motor y pulsa **Probar solo**. Se guarda el patch anterior, se quita
su bypass general y se prepara una ruta aislada con volumen moderado. **Restaurar
mi patch** recupera parámetros, rutas, Mute, Solo y bypass anteriores. Para LINE IN
debe entrar audio por el PCM1808; no se necesita WAV.

- **Mute:** silencia la aportación de la rama, conservando sus parámetros.
- **Solo:** escucha exclusivamente la rama seleccionada. Repetir lo desactiva.
  Activar Solo también quita el Mute de esa rama.
- **Bypass:** conserva la rama y su mezcla, pero utiliza audio seco.
- En Delay → Delay 2, Mute de cualquiera silencia la salida de esa cadena;
  Solo en cualquiera conserva la cadena como rama aislada. Para escuchar un
  motor sin el otro, usar el tester o darle una ruta propia al Mixer.
- Botón del encoder: pulsación corta al soltar = Mute; mantener aproximadamente
  700 ms = Solo, una sola vez, sin generar después un Mute al soltar.
- Un encoder asignado a Master alterna Mute de todas las ramas; mantenerlo limpia
  Solo. Estos gestos sustituyen al anterior reset a cero en el firmware ampliado.
- Los dos bancos cubren ahora motores originales y nuevos; ver
  `ENCODER_BANKS_EXPANDED.md`. LFO, Chaos y Envelope son moduladores:
  sus pulsaciones no activan Mute/Solo de audio.

## Motores añadidos

| Motor | Función | Controles |
| --- | --- | --- |
| Chorus | Mezcla directa con retardo corto modulado e interpolado | Rate, Depth, Mix |
| Flanger | Mezcla directa con retardo muy corto modulado | Rate, Depth, Mix |
| Bitcrusher | Reducción de resolución y retención de muestras | Bits, Rate reduction, Mix |
| Freeze | Captura estéreo de 2048 muestras; bucle con solape de 128 | Capture/Hold, Mix |
| Tremolo | Modulación triangular de amplitud | Rate, Depth, Mix |
| Auto-pan | Modulación complementaria de amplitud izquierda/derecha | Rate, Depth, Mix |
| Envelope | Seguidor del nivel de entrada que mueve el cutoff del Filter | Depth, Release |

Freeze almacena 42,67 ms a 48 kHz; el solape deja un periodo efectivo de 40 ms.
Es una textura de fragmento corto, no un congelador espectral. Chorus/Flanger
incluyen señal directa dentro del efecto. Los nuevos Mix usan 8 bits efectivos
con rampas de hasta 5,3 ms. Los LFO propios abarcan aproximadamente 0,05–11,8 Hz.

Los seis motores de audio pueden funcionar simultáneamente con los originales.
Reciben Sample In en paralelo y se suman al Mixer; no se permite una cadena
arbitraria entre ellos. La cascada existente Delay → Delay 2 se conserva.
Chorus y Flanger comparten historial de entrada, pero tienen estados y controles
independientes. La aritmética nueva comparte dos multiplicadores con una agenda
por muestra: ramas independientes no significa un multiplicador dedicado a cada
operación. No se comparten modos mutuamente excluyentes.

Los presets **Aurora Stereo**, **Neon Dust**, **Glacial Pulse** y **Living Echo**
son puntos de partida con ganancias moderadas. La suma de muchas ramas puede
saturar: reducir Mix o Master. La salida tiene saturación numérica, no un limitador
de loudness. Hay que valorar el resultado auditivo con la salida PCM5102.

## Protocolo y medidas

La capacidad 0x4000 junto con DSP completo anuncia la ampliación. Registros
64–85: rutas, bypass y parámetros nuevos; 88: Mute; 89: Solo. Bits de Mute/Solo:
Glitch, Delay, Filter, Wavefolder, VCA, Delay 2, Chorus, Flanger, Bitcrusher,
Freeze, Tremolo, Auto-pan, Dry, en ese orden.

Comando 11 devuelve 72 bytes: 32 registros uint16 LE y 8 picos uint8. Picos:
Chorus, Flanger, Bitcrusher, Freeze, Tremolo, Auto-pan, salida final, envolvente
de entrada. Los seis primeros se miden después de su mezcla y antes de Master;
la salida final se mide después de sumar todas las ramas. La telemetría está
cuantizada a 8 bits y retiene picos; no es una captura de audio.

El HDMI ampliado coloca los ocho encoders a la izquierda y muestra trece
ramas con Mute/Solo/Bypass y medidores reales. La mini pantalla conserva
los controles del banco activo. Ver `HDMI_EXPANDED.md`. Los recursos del
informe son reservas del firmware, no consumo dinamico.

## Verificación reproducible

- `vitest run`: interfaz, rutas, capacidades, presets, tester y Rust/WASM real.
- `scripts/expansion_reference.py`: modelo entero determinista, seis firmas
  distintas, equivalencia Solo/ruta aislada, silencio, Mute y bypass. Comprueba
  además 2.621.440 casos del escalado entero de Master contra la fórmula exacta.
- `fpga/sim/tb_expansion_fabric.sv`: comparación RTL con vectores del modelo.
  Pendiente de ejecución: Control de aplicaciones de Windows bloquea Icarus.
- `scripts/check_expanded_live.py`: prueba física de picos por rama, todas las
  ramas activas, Mute, Solo, Envelope y errores de entrega. Requiere audio LINE IN
  continuo. Restaura los registros originales al finalizar.

El modelo de referencia por sí solo no valida el RTL. La telemetría física tampoco
mide ruido/distorsión de la salida analógica. Los gestos de botones necesitan una
prueba manual con el array de encoders.
