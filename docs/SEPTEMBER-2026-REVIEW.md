# Revisión de septiembre de 2026 — 24/09/2026

Este documento sustituye los estados iniciales del README y contextualiza los informes históricos.

## Publicado

- FPGA y editor web: https://github.com/cescofors75/celeste-fpga
- Plugin nativo Windows/Mac y Tang Control: https://github.com/cescofors75/celeste-VST3
- Portfolio: https://cesco.dev (repositorio porfolia2026).

## Versión estable

SHA-256: adcd8ecdfa6d671aaf86671159a24c0c3b8afdb99148b025418bac6149804247. Programación SPI externa, verificación y reinicio desde flash aprobados. 48 kHz estéreo, capacidades 59391. HDMI en columna, 16 controles, efectos ampliados y demo de 4:34.

No se ha recompilado ni reflasheado hardware durante esta revisión editorial. La imagen conservada es la misma ya verificada.

## Evidencia

La demo completa y vuelta al inicio terminaron con contadores a cero en la pasada final; otras sesiones registraron pérdidas ADC. Durante la última prueba del controlador C++ los registros respondieron y se restauró el feedback, pero había 640977 pérdidas históricas. La calidad analógica y la causa de los cortes intermitentes siguen pendientes. No presentar una pasada correcta como resolución de ese fallo.

El controlador del plugin leyó 44 controles y verificó escritura/lectura/restauración en COM14. Windows y Mac Universal superaron pruebas DSP y de host; AU probado en Apple Silicon e Intel. Sin retorno USB de audio ni sincronía de transporte DAW. Prueba manual en DAW comercial y conexión física desde Mac pendientes.

## Experimentos conservados

Euclidean/Rhythm procesan una entrada externa; no son generadores de batería. Chaos/Cellular/Feedback fueron ensayos sonoros y no sustituyen la versión ampliada de referencia. Sus archivos se conservan para trazabilidad; sus bitstreams experimentales locales no se publican como estables.
