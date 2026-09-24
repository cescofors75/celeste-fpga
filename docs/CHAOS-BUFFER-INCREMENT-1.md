# Chaos Buffer Matrix — incremento CBM-4 de laboratorio

## Prioridad aceptada

Chaos Buffer + Cellular, despues Recursive Feedback. Spectral y Grain quedan
fuera de este incremento. El feedback matricial es DSP conocido; la propuesta
CELESTE reside en el control y el resultado audible, no en inventar esa tecnica.

## Estado previo comprobado

LINE IN PCM1808 maestro, 48 kHz nominal, I2S 24 bits reducido a DSP PCM16.
El 24-09-2026 la lectura de 2 s mostro 96968 tramas y 0 fallos acumulados.
El intervalo de consulta serie introduce sobrecoste: no usar ese cociente como
medida precisa de frecuencia. La escucha del loopback fue confirmada antes por
el usuario; no hay captura analogica ni nueva prueba analogica A/B automatizada.

Build anterior completo (con reset de encoders): 17769/20736 logic, 6545 FF,
22/24 DSP, 30/46 BSRAM. Es inviable presuponer cinco motores adicionales.

## Cambios aislados

- chaos_buffer4.sv: cuatro cabezales logicos de lectura, posicion y direccion
  independientes, pasos +1/-1, edades individuales, panoramicas fijas.
- 2048 tramas estereo PCM16 = 8192 bytes = 42,67 ms. Memoria se llena antes de
  habilitar wet, sin leer memoria no inicializada en la salida.
- Mapa Henon independiente por cabezal, sin acoplamiento en esta fase.
- RAW cambia posicion abruptamente; XFADE mezcla trayectorias anterior/nueva
  durante 32 muestras (0,667 ms). No es un filtro antialias.
- Una escritura y ocho lecturas de RAM por muestra, compartiendo un puerto.
  Cuatro estados independientes NO significan cuatro lectores fisicos simultaneos.
- 22 ciclos de calculo desde captura a done; el wrapper conserva su espera de 32.
  Hay ~256 ciclos de 12,288 MHz por muestra. Confirmacion ciclo a ciclo pendiente
  de ejecutar el testbench; timing fisico se registra por separado.
- Mezcla panoramica normalizada por 8 por canal, suma de 22 bits. Dry/wet
  complementario, master al final. Saturacion explicita a PCM16.
- Fixed point Henon: 24 bits signed, 20 fraccionarios; x*x de 48 bits,
  producto por a de 46 bits, b*x de 44 bits. Desplazamiento aritmetico trunca
  hacia menos infinito. a=1468006/2^20; b=314573/2^20.
- Todos los estados se actualizan desde su propio x/y anterior. No existe aun
  acoplamiento entre cabezales. Guardia |x|>1920000 reinicia la semilla de ese
  cabezal y cuenta el evento. No confundir una guardia con prueba de estabilidad.
- Comprobacion inicial de Q14 detecto periodos 459–633 y fue descartada.
  Q20 presenta periodos 11209–13728 para estas semillas. No se promete aperiodicidad.

## Integracion

La variante celeste_chaos_lab_board conserva CDC, UART, encoders, LINE IN y DAC.
Sustituye Parallel Fabric; NO contiene simultaneamente los efectos anteriores.
LINE_IN=3; capability 16384 identifica laboratorio. No anuncia capacidades de
los seis FX antiguos. Medidores antiguos se dejan a cero, no se inventa telemetria.
HDMI/LCD conservan etiquetas anteriores: no son la UI definitiva del motor.
No conectar la web de produccion para configurar este prototipo.

Controles temporales via registros existentes:
- p0 Amount: dry/wet de transformacion, 0=entrada, 65535=wet.
- p2 Size: longitud 256..1279 muestras, mas 0/4/8/12 por cabezal.
- p10 Master: ganancia final.
- p20 bit15: bypass directo conservando Master.
- p23 bit15: 1 RAW, 0 XFADE.
Los demas parametros de la especificacion no estan implementados; no se les
atribuye funcion sonora. Velocidades variables, ganancias/pan editables,
acoplamiento, transitorios y fundido configurable son incrementos posteriores.

## Validacion reproducible

1. Ejecutar python scripts/chaos_reference.py.
2. Genera build/chaos-reference/report.json y vectores input.hex/expected.hex.
3. Compilar tb_chaos_buffer4 con chaos_buffer4.sv; ejecutar desde raiz del repo.
   Compara 24000 tramas exactas, RAW y XFADE, y plazo <=24 ciclos.
4. Compilar scripts/build_chaos_lab.tcl con Gowin usando ruta absoluta.
5. Informe fisico: build/chaos-lab/impl/pnr/celeste_chaos_lab.*.

Referencia software comprobada: silencio, impulso, seno estereo, transitorios,
escala completa, bypass exacto, Amount=0 y reproducibilidad. Los tests de
referencia no demuestran equivalencia del RTL. Windows Application Control
bloquea Icarus; no se ha eludido esa restriccion ni marcado simulacion como pasada.

Pendiente: simulacion RTL bit-exacta, prueba de placa de esta variante, latencia
analogica, estabilidad frente a automatizacion, escucha A/B bateria/voz/bajo/pad.
Los contadores internos de deadline/guardia existen en el core/testbench pero
no se exportan aun por UART; antes de validacion fisica completa hay que exponerlos.
No se ha cargado este firmware experimental ni modificado el cableado funcional.

## Orden siguiente

1. Cerrar equivalencia RTL y escucha del CBM-4.
2. Cellular separado del renderizador: 256 bits, reglas 30/90/110, borde circular,
   semilla reproducible; verificar generaciones de referencia antes de mapear acciones.
3. Cuatro delays con Hadamard /2, permutaciones y signos. Empezar fijo con g<1,
   damping, energia, saturacion, reduccion automatica de feedback y reset suave.
4. Medir variante Chaos+Feedback simultanea; normalizar mezcla y estudiar retardos.
   No introducir realimentacion cruzada entre motores durante la primera validacion.

Referencia original de Henon: https://acoustique.ec-lyon.fr/chaos/Henon76.pdf

## Resultado de implementacion fisica (24-09-2026)

Variante completa con controles y video: 9067/20736 logic, 4679 FF,
14,5/24 DSP y 10/46 BSRAM. Setup=0, Hold=0 endpoints violados.
Estos recursos no son el coste aislado del core. Archivo generado:
deliverables/celeste_chaos_lab_UNVALIDATED.fs. No cargar como firmware validado.
Informe: deliverables/CHAOS-CBM4-validation.json.
