# LINE IN: diagnostico de sincronizacion

Firmware instrumentado: comando UART 10, respuesta 32 bytes / 8 uint32 LE.
Solo disponible en LINE_IN>=2. No modifica audio, tolerancias ni controles.

| Indice | Campo |
|---|---|
| 0 | Minimo age entre tramas (ciclos menos uno), 0xffffffff antes de medir |
| 1 | Maximo age entre tramas (ciclos menos uno) |
| 2 | Ultimo intervalo rechazado (ciclos menos uno) |
| 3 | Total intervalos fuera de 252..260, excluyendo primera trama |
| 4 | Veces sin trama durante 2049 ciclos del reloj de proceso |
| 5 | Intentos de enviar audio cuando el mailbox de salida no estaba libre |
| 6 | Muestras recibidas mientras Chaos aun estaba ocupado |
| 7 | Reinicios de guardia Henon |

Los campos 0..5 se reinician al cargar/resetear FPGA. Los campos 6..7 vienen del
core Chaos y tambien se reinician cuando este se resetea por STOP/perdida de lock.
No usar esos dos campos para afirmar ausencia historica de fallos tras una perdida.

Uso: python scripts/check_line_clock.py --port COM14 --seconds 120.
Lee estado, estos contadores y actividad de audio cada ~2 s. Guarda todas las
lecturas; son instantaneas distintas, no una captura simultanea de todos los campos.
El intervalo de edad se mide entre pulsos received_valid en el dominio DSP.
No es una medida analogica del jitter ni distingue por si solo un mal contacto
de una trama I2S rechazada. No se han aumentado tolerancias para ocultar fallos.

Evidencia previa: contador acumulado 128, estable durante 10 s y otros 32 s.
Tras instrumentar: primer ensayo 45 s, 0 errores en todos los contadores,
min/max age 255/256 (periodos de 256/257 ciclos).
La ausencia de fallos en una ventana no demuestra que el fallo intermitente este
resuelto. El usuario indica cortes con cables quietos y alimentacion conectada.

## Arquitectura de reloj

PCM1808 puede ser maestro o esclavo. Ahora el ADC genera BCK/LRCK y DAC sigue ese
mismo BCK; el DSP usa 12,288 MHz y cruza tramas completas mediante handshake.
Un reloj comun distribuido desde Tang simplificaria esta arquitectura, pero no
sustituye verificar alimentacion, niveles y cableado.
Para Tang maestra: ADC MD1=MD0=0 antes de alimentar, MCLK local aislado de SCKI,
BCK/LRCK entradas del ADC. No modificar el cableado actual durante estas pruebas.
Fuente: https://www.ti.com/lit/ds/symlink/pcm1808.pdf, seccion 7.3.5.1.

Ensayo extendido: 120,015 s, 5760247 tramas adicionales segun status, cero fallos en los contadores. No se ha reproducido el fallo anterior ni se afirma corregido. Build instrumentado: 9476 logic, 4877 FF, 14,5 DSP, 10 BSRAM; setup/hold 0.
