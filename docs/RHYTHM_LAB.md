# CELESTE Rhythm Lab — prueba con Line-In

Variante independiente del Euclidiano mínimo y del sistema de efectos original. No genera música: necesita audio externo por Line-In. Relojes, 48 kHz, cableado y transporte I2S conservados.

## Controles (iguales en ambos bancos)

| Encoder | Control | Rango / inicio |
|---|---|---|
| 1 | Pulsos del patrón A | 1–16 / 5 |
| 2 | Rotación de A | 0–15 / 0 |
| 3 | Patrones simultáneos | 1, 2 o 4 / 1 |
| 4 | Mutación Turing | 0–100% / desactivado |
| 5 | Probabilidad de evento | 0–100% / 100% |
| 6 | División del delay | 1/32, 1/16, 3/32, 1/8 / 1/16 |
| 7 | Mezcla del delay | 0–50% / 25% |
| 8 | Feedback del delay | 0–75% / 37,5% |

Táctil: DRY / FX completo. Pulsar encoder 4: activar/desactivar Turing. Girarlo también activa Turing. A mutación 0, el registro circula sin cambios y repite sus acentos cada 16 pasos de A. Los demás botones no tienen función. El selector de banco no cambia las asignaciones. Esta variante no incluye control web ni protocolo serie CELESTE.

## Motores

- Tempo fijo 120 BPM, compás de 2 segundos. Cuatro subdivisiones simultáneas de ese mismo compás: A 16 pasos / K variable, B 12 / 5, C 10 / 3, D 7 / 2. Todos cierran exactamente a las 96000 muestras; la subdivisión de 7 alterna intervalos con diferencia máxima de una muestra.
- Cada voz es un gate sobre la misma señal estéreo. Sus envolventes se promedian; no son cuatro instrumentos ni cuatro delays. Coincidir no puede elevar la ganancia por encima de la entrada. Rampa de amplitud de aproximadamente 2,67 ms y suavizado de la suma al cambiar el número de patrones.
- Turing: registro circular de 16 bits, semilla fija B4D3 y mutación probabilística. Modula únicamente acentos de 100% / 75% de amplitud. No añade ruido ni cambia afinación. Mutación y probabilidad usan generadores deterministas, no muestras de ruido en el audio.
- Probabilidad: decide si aceptar un evento al comienzo de cada paso, por voz; 100% acepta todos y 0% ninguno. Las decisiones se mantienen durante el paso. No se interrumpe el audio aleatoriamente por muestra.
- Un único delay estéreo, sin modulación de lectura: 62,5 / 125 / 187,5 / 250 ms. Mezcla y feedback normalizados mediante combinaciones convexas para evitar saturación. El feedback reduce proporcionalmente la inyección nueva. Los cambios de tiempo atenúan primero la contribución del delay, cambian el tap y vuelven a subirla; sin barrido de pitch. Los controles y DRY tienen rampas.
- DRY recupera las muestras de entrada a ganancia unitaria tras su transición, conservando la latencia del transporte. Las secuencias siguen avanzando en DRY.

## Pantallas

HDMI y ST7789 muestran los ocho valores, modo DRY/FX, estado Turing, reloj de entrada, cuatro patrones, paso actual y registro Turing. Verde en el paso actual: evento aceptado; rojo: descanso/rechazo. Las voces desactivadas están atenuadas. Los patrones base dibujados son los usados por el gate; las decisiones de probabilidad se reflejan en el paso actual.

## Prueba sugerida

1. Conecta un loop al Line-In. Toca DRY/FX para comparar.
2. Pon mezcla de delay a 0, Turing OFF y probabilidad 100%. Compara 1, 2 y 4 patrones.
3. Activa Turing con encoder 4 y déjalo en 0: acentos repetibles. Sube la mutación para que evolucionen.
4. Prueba probabilidad 50%; vuelve a 100% para recuperar todos los eventos.
5. Sube mezcla del delay a 25–50%; compara divisiones. Feedback controla las repeticiones.

La sincronización es interna, sin detección del tempo ni alineación automática al inicio del loop externo.

## Construcción y conservación

Build: scripts/build_rhythm.tcl, salida separada build/rhythm-lab. Código en rhythm_gate.sv, rhythm_delay.sv, rhythm_controls.sv, rhythm_screen.sv, rhythm_video.sv y celeste_rhythm_board.sv. No se han cambiado los archivos del Euclidiano mínimo para esta variante.

El Euclidiano escuchado por el usuario queda en deliverables/checkpoints/2026-09-24-euclidean-working/. La versión completa anterior permanece en deliverables/checkpoints/2026-09-24-encoder-banks/.

Validación: scripts/test_rhythm_reference.py comprueba temporización, Turing, probabilidad, límites numéricos, DRY, impulsos del delay, feedback y cambio de tap (11 pruebas de modelo Python, no simulación RTL). La escucha en hardware queda pendiente del usuario. El firmware se carga solo en SRAM; no sustituye la flash persistente.

Carga realizada el 24/09/2026 en SRAM: programador Finished, retorno 0, reloj de audio confirmado a 12,288 MHz. Compilación final: 4207/20736 celdas, 32/46 BSRAM, 9,5/24 DSP; 0 violaciones Setup/Hold. Detalle en deliverables/rhythm-validation.json y build/rhythm-loaded.json.
