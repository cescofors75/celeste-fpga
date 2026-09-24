# CELESTE — Euclidean Gate mínimo

Variante aislada, compilada el 24 de septiembre de 2026. No cargada en la Tang.

## Versión conservada

`deliverables/checkpoints/2026-09-24-encoder-banks/` contiene el código anterior en CELESTE-source.zip, el firmware celeste_line_in_encoder_banks.fs, resultados de validación y manifest.json con SHA256. Para volver al sistema anterior basta cargar ese firmware. El archivo fuente compartido modificado es fpga/rtl/top/line_in_audio.sv: incorpora una entrada de procesamiento externa opcional, desactivada por defecto. Los relojes, restricciones, transporte I2S y mailboxes originales se conservan.

## Prueba

LINE IN → multiplicación por envolvente del gate → LINE OUT.

- 48 kHz, estéreo, precisión de 16 bits del pipeline existente.
- 16 pasos; 5 pulsos y rotación 0 al arrancar.
- 120 BPM, pasos de semicorchea: 125 ms por paso y 2 segundos por ciclo.
- Patrón inicial: `X--X--X--X--X---`.
- Encoder 1: pulsos K, de 1 a 16.
- Encoder 2: rotación circular, de 0 a 15. Positivo desplaza eventos hacia pasos posteriores.
- Encoders 3–8 y pulsaciones de encoders: sin acción. Ambos bancos mantienen las mismas dos funciones.
- Botón táctil: alterna EUCLID / DRY. Arranca en EUCLID.
- Rampa lineal de 128 muestras (2,667 ms) entre silencio y ganancia unitaria. DRY también entra suavemente. A ganancia unitaria la muestra es idéntica a la entrada; a cero hay silencio exacto.
- El patrón continúa avanzando durante DRY. No hay sincronización externa de inicio con el drum loop.
- HDMI y LCD muestran el patrón utilizado por el audio, paso actual, pulsos, rotación, modo y envolvente.

Esta variante mínima utiliza controles físicos; no incluye protocolo UART ni control desde la web. No contiene los demás motores FX, mezclador de efectos ni sus presets. No requiere cambiar el cableado actual.

## Compilación y validación

Ejecutar scripts/build_euclidean.tcl con gw_sh de Gowin. El resultado se genera en build/euclidean-test, separado del firmware de producción.

Resultado: síntesis, placement, routing y generación del bitstream completados. Informe de tiempos: 0 endpoints con violaciones Setup y 0 Hold bajo las restricciones existentes. Recursos totales: 2969/20736 celdas lógicas, 1916/10368 CLS, 1/24 DSP.

scripts/test_euclidean_reference.py: 9 pruebas del modelo de referencia aprobadas, incluyendo todas las combinaciones K/rotación, distribución, rampa, silencio, ganancia unitaria, duración y controles. Son pruebas de modelo Python que leen la ROM del RTL; no una simulación ejecutada del RTL. Falta prueba física y escucha. Compilar no demuestra por sí solo ausencia de clicks o funcionamiento analógico.

Firmware listo: deliverables/celeste_euclidean_test.fs. No se ha flasheado ni alterado el firmware que está ejecutando la placa.
