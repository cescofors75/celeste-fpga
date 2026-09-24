# DEMO LIVE — Parallel Tides

Pieza original generada localmente: 192 compases a 168 BPM, 274,286 segundos (4:34), estéreo 48 kHz / 16 bits. No utiliza grabaciones de artistas ni samples externos. Breaks con síncopas y notas fantasma, bajo profundo centrado, acordes extendidos, campanas y pasajes ambientales. Variación determinista por semilla; nueva semilla en cada inicio. Intro de 3 segundos y salida de 6 segundos, pico máximo 0,68 FS.

## Uso con el firmware Line-In ampliado

1. Salida de audio del ordenador → entrada estéreo del PCM1808.
2. Escucha desde la salida del PCM5102.
3. Conecta COM14 en la web y pulsa DEMO LIVE · 4:34.
4. La composición se prepara en un worker (aproximadamente medio minuto según el ordenador). La interfaz informa del progreso.
5. La música sale por el dispositivo de reproducción predeterminado del navegador. Las rutas, mezclas y parámetros se envían a la FPGA; HDMI, pantalla y web muestran esos controles reales.

No hay retorno de audio del PCM5102 al navegador. Escuchar solo el ordenador permite oír la composición original, no los efectos de la FPGA. Sin el cable ordenador → PCM1808, la web no puede introducir esta música en el firmware Line-In.

El botón táctil/BYPASS permite comparar la entrada con los efectos. Pausar automatización conserva la música en marcha. Salir y restaurar mi patch detiene la demo y recupera el patch, fuente, posición, modo, loop y bypass anteriores. Los cambios de la demo no sobrescriben el patch guardado.

## Doce escenas, 16 compases cada una

| Escena | Combinación |
|---|---|
| First light | Chorus + Auto-pan, introducción ambiental |
| Soft currents | Filtro con apertura gradual + Chorus |
| Deep blue | VCA modulado por LFO + Auto-pan |
| Glass gardens | Chorus + Delay |
| Orbital drift | Tremolo + Auto-pan + Filter |
| Parallel tides | Delay y Delay 2 en paralelo + Chorus |
| Still water | Freeze discreto + Chorus + Delay; captura, hold y liberación |
| Night train | Filter + Chorus + Wavefolder suave |
| Fragments | Glitch discreto + Delay + Auto-pan |
| Open sky | Filter con LFO, Chaos y Envelope + Tremolo |
| Afterimages | Flanger + Bitcrusher discreto + Delay → Delay 2 |
| Weightless | Chorus + Delay + Auto-pan, salida ambiental |

Las aportaciones de efectos bajan a cero durante las transiciones de topología. La ruta seca mantiene la continuidad. La suma de ganancias por Master se comprueba por debajo de 0,65. Los delays usan divisiones cortas compatibles con su memoria: aproximadamente 89,3 y 67 ms. No se prometen ecos largos que no caben en esta FPGA.

Solo se presentan los módulos usados en cada escena; las asignaciones de los 16 encoders se conservan. En firmware anterior sin expansión se usan combinaciones compatibles de los motores antiguos.

## Temporización y límites

Con Line-In el reloj de las escenas sigue las muestras realmente consumidas por el reproductor local, no el contador libre del ADC ni el intervalo de interfaz. Con firmware USB sigue el contador de consumo de la FPGA. La preparación trabaja fuera del hilo de interfaz; el reproductor local agenda 0,8 segundos de audio por adelantado.

Para firmware USB, la pieza completa entra en la precarga acotada a 64 MiB y se transfiere al worker de serie antes de comenzar, evitando volver a pedir fragmentos durante la interpretación. El WAV de esta pieza ocupa unos 50,2 MiB. La demo ambient corta de 48 segundos permanece como opción separada.

## Validación

70 pruebas Vitest aprobadas, TypeScript, paleta compartida y compilación Vite aprobados. Comprobaciones específicas: render completo de la pieza, pico/DC/estéreo/estructura/costura; todos los pasos de las doce escenas con y sin expansión; límites de mezcla; liberación Freeze; mapeos; reloj de reproducción y precarga larga.

La prueba del navegador conecta a la placa real y comprueba la interfaz y el avance. No existe captura analógica de retorno: la calidad audible de la cadena completa debe confirmarse por escucha del usuario.

Prueba real completada: ciclo completo y vuelta al inicio, pausa/reanudación y restauración de Aurora Stereo y fuente anterior verificados en navegador; sin errores de consola ni protocolo. Al final se observaron 1924 pérdidas de sincronía ADC, 4689 intervalos incorrectos y 29 timeouts, sin pérdidas de envío ni plazos DSP incumplidos. En diez segundos posteriores con la demo detenida no aumentaron. Causa no determinada: no se considera validada la continuidad analógica de toda la pasada. Evidencia: build/long-live-line-in-diagnostics.json. La web queda conectada, en PATCH, con la demo detenida y lista para iniciar.

Retest final tras recargar el firmware completo guardado: pasada íntegra de 274,286 segundos y vuelta al inicio, cero pérdidas ADC, cero desbordamientos y cero errores de protocolo en todas las lecturas. Señal real medida en entrada/salida. Aurora Stereo y fuente anterior restaurados; web conectada en PATCH y demo detenida. La incidencia anterior no se reproduce en esta pasada, sin afirmar una causa resuelta. Informe: deliverables/final-line-in-validation.json. Carga en SRAM; flash persistente sin cambios.
