# CELESTE LINE IN — PCM1808 maestro

Variante actual: PCM1808 genera BCK y LRCK; Tang recibe audio I2S,
procesa en Parallel Fabric y alimenta el PCM5102 con el mismo reloj BCK.
La salida LRCK del DAC se retrasa un BCK para alinear el transmisor.
No se envia ningun reloj al PCM1808. El funcionamiento requiere que el
modulo genere I2S estereo de 24 bits, 64 BCK por trama, a 48 kHz.
Si no entrega relojes compatibles, el firmware no obtiene lock y silencia la salida.

## Cableado (cambiar con ambas placas apagadas)

| PCM1808 | Tang Nano 20K |
|---|---|
| BCK | GPIO 80 (entrada) |
| LRCK | GPIO 86 (entrada) |
| DOUT | GPIO 85 (entrada) |
| GND | GND |
| MCLK | Sin conectar |
| VT33 | Sin conectar |

Retirar microSD. Alimentar ADC mediante su USB. Los numeros son pines FPGA,
no posiciones del conector. No unir BCK/LRCK del ADC a GPIO 73/75.
PCM5102 conserva BCK=73, DIN=74, LRCK=75 y masa comun.
No cambiar puentes del modulo para esta prueba.

## Firmware y prueba

Compilar scripts/build_line_in.tcl con Gowin.
Resultado build/line-in-adc-master/impl/pnr/celeste_line_in_adc_master.fs.
Esta variante usa LINE_IN=2; LINE_IN=1 conserva el motor Tang-maestra como codigo.

Tras confirmar el cableado, cargar temporalmente en SRAM (no flash persistente):

```powershell
python scripts/prepare_board.py --port COM15 --line-in
python scripts/check_line_in.py --port COM15 --start --bypass --seconds 3
```

Cerrar conexiones serie del navegador antes de cargar. Detectar de nuevo el
puerto si cambia. La carga configura el reloj interno DSP a 12,288 MHz;
este reloj no sale hacia el ADC.

Conectar una fuente de nivel de linea al jack ADC, reproducir musica con
volumen moderado y escuchar PCM5102 empezando con volumen bajo.
Primero comprobar bypass y contadores de entrada, despues activar efectos.
El reproductor WAV/DEMO LIVE de la web no es fuente de audio en esta variante.

DSP trabaja a 16 bits por canal: entrada 24 bits reducida a 16 y salida rellenada.
Testbench fpga/sim/tb_line_in.sv cubre alineacion, salida, perdida de reloj,
parada/reinicio y trama incorrecta. Simulacion pendiente: Windows Application
Control bloquea Icarus. Compilar no sustituye la prueba fisica de audio.

Datasheet: https://www.ti.com/lit/ds/symlink/pcm1808.pdf
