# Cellular Glitch: primera prueba independiente

Chaos: puntuación del usuario 2; decisión final aplazada. Siguiente: Cellular; después Feedback matricial.

Implementación: 256 células binarias en anillo, reglas 30/90/110 y semilla fija reproducible. Deciden saltos, repetición, inversión y silencios de cuatro cabezales lógicos. Congelación global condicionada por células. No son 256 voces. Las células actualizan en paralelo; los cuatro lectores de audio comparten RAM y procesamiento durante cada muestra. Todavía no combina los demás motores.

RAM de audio 8192 muestras estéreo PCM16 (170,67 ms a 48 kHz); fragmentos 128–4223 muestras; transición XFADE de 128 muestras o RAW. Regla 90 en un anillo de 256 células llega a cero: se reinyecta la semilla y se cuenta el evento. Densidad máxima usa comparación de ocho bits: 255/256, no probabilidad exactamente uno.

## Controles de esta prueba

Banco 0: encoder 1 Amount (mezcla); 2 Density; 5 Size; 8 Master. Las etiquetas heredadas de pantalla no se han adaptado todavía. Otros efectos dibujados en la web no pertenecen a esta versión. Bypass global p20; regla p28 (0=30,16384=90,32768=110); p23 bit15 RAW. Pulsación del encoder conserva reset a cero.

Preset inicial de escucha: Amount 65535, Density 55705, Size 28672 (1920 muestras=40 ms), Master 26214; regla30, XFADE, bypass desactivado. Carga SRAM temporal; apagar pierde esta versión.

## Validación

Referencia Python: reglas comprobadas contra evaluador escalar, repetibilidad, bypass exacto, silencio, rangos PCM16, RAW/XFADE a escala completa y mezcla seca exacta. Vectores de 24000 muestras por regla. No es una captura FPGA ni valida calidad analógica.

Banco RTL preparado en fpga/sim/tb_cellular_buffer4.sv, pendiente de ejecutar: Windows bloquea Icarus. Síntesis y place/route Gowin completados, cero endpoints Setup/Hold violados. Diseño completo: 10202/20736 lógica, 5073 registros, 34/46 BSRAM, 8,5/24 DSP. Existe advertencia de enrutamiento de reloj genérico; el informe no sustituye la prueba de estabilidad física.

Diagnóstico UART 10 conserva nombres legacy chaos_deadline_faults/chaos_guard_resets: en Cellular significan fallos de plazo del renderizador/reinyecciones de semilla. Una reinyección de regla90 no es pérdida de audio. Los contadores del motor se reinician con su reset.

Pendiente: valoración auditiva, simulación RTL y adaptación de etiquetas de interfaz antes de integración general. Feedback matricial todavía no implementado en esta variante.

## Revisión tras primera escucha

El usuario considera Cellular mejor que Chaos, pero encuentra ruido molesto. Se amplía XFADE de 32 a 128 muestras (0,67 a 2,67 ms) manteniendo mínimo de fragmento 128: la transición finaliza antes del siguiente salto. Se amplían acumuladores de mezcla a 26 bits. En empalme sintético entre DC de extremos opuestos, el salto máximo baja de 2048 a 512 unidades PCM16. Esto valida el suavizado, no demuestra que todo el ruido audible provenga de estos empalmes. RAW conserva los cambios abruptos. Calidad auditiva pendiente de nueva escucha.

Revisión suavizada cargada en SRAM con parámetros preservados y comprobados por lectura. Gowin: Setup/Hold cero; 10174 celdas, 5081 registros, 34 BSRAM, 8,5 DSP. Medición física 15 s sin pérdidas ni fallos de plazo (build/cellular-soft-clock-validation.json). Pico de entrada alcanzó magnitud 32768 en ambos canales: posible saturación de origen/ADC, pendiente comparar con menor nivel de fuente; no demuestra por sí solo recorte sostenido.
