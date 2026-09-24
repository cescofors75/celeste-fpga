# Feedback matricial: FDN-4 de laboratorio

Prueba independiente posterior a Chaos y Cellular. No contiene sus motores ni procesa los módulos antiguos dibujados en la web.

Cuatro líneas mono independientes de 1493, 1601, 1867 y 1999 muestras (31,1 / 33,4 / 38,9 / 41,6 ms a 48 kHz). Matriz Hadamard normalizada H/2. Inyección [L,R,-L,-R]/4, salida [(tap0-tap2)/2,(tap1-tap3)/2]. Realimentación máxima 0,9375; filtro de un polo dentro de cada línea. Memorias de 24 bits con saturación de contención a +/-131071. Mezcla y volumen finales saturan a PCM16. No se atribuye originalidad a la técnica FDN.

Las cuatro memorias mantienen estados simultáneos, pero la aritmética se comparte y agenda en 18 ciclos de los 256 disponibles por muestra: no son cuatro motores aritméticos físicamente paralelos. Esta versión no demuestra aún un conjunto de efectos diferentes ejecutándose en paralelo.

## Controles

Banco 0: encoder1 Amount (seco/efecto, p0), encoder2 Feedback (p1; escala efectiva 0–93,75%), encoder5 Tone (p2; aumenta brillo al subir), encoder8 Master (p10). p20 bypass conserva la cola internamente y desvanece mezcla a seco. Todos estos controles tienen rampa de 32 unidades por muestra (máximo ~43 ms). No se cambia duración de retardo al girar, para evitar saltos de lectura. Pulsar encoder mantiene reset a cero.

Etiquetas web/HDMI heredadas: Size/Time del encoder5 representa Tone en este laboratorio. No hay aún controles de tamaño, modulación o freeze de FDN; no deben anunciarse como disponibles.

## Validación

scripts/feedback_reference.py: identidad energética de H/2 antes de redondeo, silencio, seco exacto tras rampa, primer eco de impulso en muestra1493, reproducibilidad de 30000 frames, señal extrema a feedback máximo y seis segundos de decaimiento. La protección actúa bajo DC extremo; su contador permite detectarlo, no es una garantía de ausencia de distorsión. Datos en build/feedback-reference/report.json.

fpga/sim/tb_feedback_matrix4.sv compara los vectores y plazo de procesamiento; ejecución pendiente por bloqueo de Icarus en Windows. La referencia Python no sustituye la simulación RTL ni la escucha de FPGA. RAM no se limpia físicamente al reset: contadores impiden leer datos antiguos hasta completar cada línea.

Diagnóstico10: campo legacy chaos_deadline_faults corresponde a plazos de FDN; chaos_guard_resets cuenta saturaciones internas de contención. Contadores se reinician con reset del motor. Recursos, timing y prueba física se añadirán tras la compilación.

## Compilación y carga

Gowin completado: 9900/20736 celdas, 4764 registros, 14/46 BSRAM, 7,5/24 DSP; cero endpoints Setup/Hold violados. Aviso de enrutamiento de reloj genérico presente. Cargado temporalmente en SRAM, ajuste inicial p0=32768, p1=32768 (ganancia efectiva 0,46875), p2=24576, p10=26214, p20=0. Registros leídos y confirmados. No guardar en flash durante esta comparación.

Prueba física de 30 s: cero pérdidas, errores de protocolo, fallos de plazo o activaciones de contención interna. Informe build/feedback-clock-validation.json. No equivale a validación auditiva ni analógica; puntuación del usuario pendiente.
