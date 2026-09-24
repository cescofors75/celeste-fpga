# Dos bancos de encoders: motores completos

| Encoder | Banco 0 | Banco 1 |
|---|---|---|
| 1 | Glitch Amount | Chorus Depth |
| 2 | Delay Time | Flanger Depth |
| 3 | Delay 2 Time | Bitcrusher Bits |
| 4 | Filter Cutoff | Freeze Capture/Hold |
| 5 | Wavefolder Drive | Tremolo Depth |
| 6 | VCA Level | Auto-pan Depth |
| 7 | LFO Depth | Envelope Depth |
| 8 | Chaos Amount | Master Level |

Se elige la intensidad para los moduladores porque permite oir su aportacion
sin cambiar a la vez la velocidad. LFO y Chaos necesitan una ruta a Filter o VCA;
Envelope actua sobre Filter. Los efectos necesitan ruta y mezcla distinta de cero.
Freeze: cualquier giro positivo activa HOLD; negativo activa CAPTURE. No cambia
por girar el encoder de otro modulo. Los demas controles saturan entre 0 y 65535.

Corto: Mute de la rama. Mantener 700 ms: Solo. Master corto silencia todo y
mantenido limpia Solo. LFO, Chaos y Envelope no tienen Mute/Solo de audio.

Los identificadores de asignacion pasan de 5 a 7 bits en el firmware ampliado.
La capacidad 0x8000 junto con 0x4000 y DSP completo anuncia esta extension.
El comando 9 mantiene su formato: ocho bytes de asignaciones del banco activo;
los valores nuevos se leen con el comando 11. Los registros de asignacion
siguen siendo 40..55 y aceptan 66..85 salvo 76, ademas de los parametros antiguos.

Ambas pantallas muestran el mismo valor de registro usado por el motor, con
porcentaje truncado y 100% para 65535. Freeze se muestra como estado. La cache
de ocho valores se actualiza por turnos a reloj de audio, cada ocho ciclos, y
cruza hacia video mediante la captura CDC existente. Esto evita ocho grandes
multiplexores de lectura en paralelo. Los colores provienen de shared/palette.json.

La web migra una vez el patch guardado al reparto nuevo. Los presets de fabrica
lo adoptan al cargarse y DEMO LIVE lo mantiene. Las asignaciones personalizadas
siguen siendo editables; Hardware tiene el boton Aplicar reparto de 16 controles.
La recepcion del comando 11 actualiza tambien los mandos, porcentajes y mini
pantalla web, sin esperar a editar otro parametro.

## Validacion de esta revision

- Compilacion scripts/build_hdmi_expanded.tcl: Setup 0, Hold 0.
- Logica 19.384/20.736; CLS 10.013/10.368; RAM 38/46; DSP 23/24.
- 66 pruebas web pasan; TypeScript, paleta compartida y build Vite pasan.
- Verificados visualmente ambos bancos y sus dieciseis etiquetas en la web.
- Freeze web: ArrowRight muestra HOLD; ArrowLeft restaura CAPTURE. Sin errores de consola.
- Cargada en SRAM. Controles de audio previos restaurados, bancos nuevos aplicados.
- La placa devuelve capacidad 59391 y confirma las ocho asignaciones activas.
- Diez segundos sin errores, underruns, overruns o fallos de plazo DSP.
- No se ha medido audio analogico: la entrada solo tenia 18 LSB de ruido de fondo.
- Giro fisico y coincidencia visual HDMI/LCD pendientes de confirmacion del usuario.
- tb_encoder_banks.sv preparado: bancos, giro, limites, Freeze, cache y Mute/Solo.
  No ejecutado: Icarus bloqueado por Control de aplicaciones de Windows.

Artefacto: deliverables/celeste_line_in_encoder_banks.fs
SHA256: adcd8ecdfa6d671aaf86671159a24c0c3b8afdb99148b025418bac6149804247
Evidencias: build/encoder-banks-validation.json, build/encoders-loaded-validation.json,
build/encoder-banks-build.log y build/encoder-banks-web-tests.log.
