# HDMI ampliado — columna de encoders y fabric paralelo

El firmware LINE IN ampliado muestra los ocho encoders del banco activo en una
columna izquierda: nombre real de la asignación, porcentaje (o modo enumerado)
y barra. El encoder seleccionado queda resaltado. Los valores vienen de los
registros de la FPGA, no de una copia del patch del navegador.

A la derecha se muestran trece ramas: Dry, Glitch, Delay, Filter, Wavefolder,
VCA, Delay 2, Chorus, Flanger, Bitcrusher, Freeze, Tremolo y Auto-pan. Los motores
sin ruta aparecen OFF. Los estados MUTE, SOLO y BYPASS se leen de los mismos
registros que controlan el audio; las ramas excluidas por Solo muestran `--`.
La dependencia Delay 1 → Delay 2 se conserva al representar Solo en serie.

Las barras de cada rama representan contribuciones medidas al mezclador. Las
nuevas ramas tienen resolución de 8 bits; son picos retenidos, no oscilogramas.
El medidor MIX / OUT toma la suma final de la expansión después del Master,
incluyendo los efectos antiguos y los nuevos. La animación de conexiones se
condiciona a actividad medida; las salidas silenciadas no animan por picos viejos.
LFO, Chaos y Envelope se identifican aparte como modulación. La revision posterior incorpora los nuevos motores en los dos bancos fisicos;
ver `ENCODER_BANKS_EXPANDED.md` para asignaciones, recursos y validacion actuales.

La captura CDC pasa de 803 a 907 bits y conserva el protocolo de bus retenido
hasta acuse. Los 104 bits adicionales contienen rutas, bypass, Mute/Solo y ocho
medidores. No se cruza el banco completo de parámetros nuevos ni se altera el
receptor ADC, los relojes o los motores DSP.

`build/hdmi-expanded-layout-reference.png` es una referencia de distribución
con datos de ejemplo, generada con la fuente bitmap del proyecto. No es una
captura de la placa ni una simulación del RTL. `fpga/sim/tb_expanded_screen.sv`
prepara comprobaciones de las trece filas, Mute/Solo, dependencia serie,
medidor de suma final y posición de encoders. Su ejecución está pendiente:
Icarus está bloqueado por Control de aplicaciones de Windows.

## Compilacion y carga final

Compilada con `scripts/build_hdmi_expanded.tcl` (colocacion 2). El enrutado
por defecto de esta revision fallo; no se usa su resultado. La compilacion
final termina correctamente, con cero endpoints violados de Setup y Hold.

- Logica: 17.640 / 20.736; CLS: 9.711 / 10.368.
- Registros: 7.755; BSRAM: 38 / 46; DSP: 23 / 24.
- Artefacto: `deliverables/celeste_line_in_hdmi_expanded.fs`.
- SHA256: `5da98a982a6c63cd9a21218bc212a7708e5909de903b87db1de448603474d5ed`.
- Cargada en SRAM, controles y rutas restaurados y leidos de vuelta.
- Diez segundos de actividad: cero errores, underruns, overruns o plazos DSP incumplidos.
- La entrada solo media 15 LSB: no es una prueba audible de los efectos.
- Evidencias: `build/hdmi-expanded-place2-build.log`,
  `build/hdmi-build-validation.json` y `build/hdmi-loaded-validation.json`.
