"""Configure volatile 12.288 MHz clock and load CELESTE into SRAM only."""
import argparse, pathlib, re, subprocess, time, struct
import serial
from hardware_stream import Device

ROOT=pathlib.Path(__file__).resolve().parent.parent
GOWIN=pathlib.Path('C:/DEV/tools/Gowin_V1.9.11.03_Education/Gowin_V1.9.11.03_Education_x64')

def main():
    p=argparse.ArgumentParser();p.add_argument('--port',default='COM14');p.add_argument('--cable-index',default='4');p.add_argument('--line-in',action='store_true');p.add_argument('--chaos-lab',action='store_true');p.add_argument('--cellular-lab',action='store_true');p.add_argument('--feedback-lab',action='store_true');args=p.parse_args()
    if sum([args.line_in,args.chaos_lab,args.cellular_lab,args.feedback_lab])>1:p.error('Choose one firmware variant')
    name='celeste_feedback_lab' if args.feedback_lab else 'celeste_cellular_lab' if args.cellular_lab else 'celeste_chaos_lab' if args.chaos_lab else 'celeste_line_in_adc_master' if args.line_in else 'celeste_stream'
    fs=ROOT/('build/feedback-lab/impl/pnr' if args.feedback_lab else 'build/cellular-lab/impl/pnr' if args.cellular_lab else 'build/chaos-lab/impl/pnr' if args.chaos_lab else 'build/line-in-adc-master/impl/pnr' if args.line_in else 'build/stream/impl/pnr')/(name+'.fs')
    report=(fs.parent/(name+'_tr_content.html')).read_text()
    for kind in ['Setup','Hold']:
        match=re.search(r'Numbers of '+kind+r' Violated Endpoints</td>\s*<td>(\d+)</td>',report)
        if not match or int(match[1]):raise RuntimeError('Build timing has not closed: '+kind)
    with serial.Serial(args.port,115200,timeout=.3,write_timeout=2) as console:
        time.sleep(.5)
        # BL616 escape sequence requires separate USB transfers.
        for b in [b'\x18',b'\x03',b'\n']:
            console.write(b);console.flush();time.sleep(.08)
        console.read(8192)
        console.write(b'pll P1:35,1217,3125 D2@P1:72,0,1 O2@D2:0\n');console.flush();time.sleep(.2);console.read(8192)
        console.write(b'pll_clk\n');console.flush();time.sleep(.2)
        result=console.read(8192).decode(errors='replace');print(result)
        console.write(b'choose uart\n');console.flush();time.sleep(.2)
        if '12288000' not in result:raise RuntimeError('Audio clock readback failed')
    subprocess.run([str(GOWIN/'Programmer/bin/programmer_cli.exe'),'--device','GW2AR-18C','--cable-index',args.cable_index,'--channel','0','--operation_index','2','--fsFile',str(fs)],check=True,timeout=40)
    d=Device(args.port)
    try:
        assert d.request(1)==b'CELESTE/1'
        if args.chaos_lab or args.cellular_lab or args.feedback_lab:
            for key,value in [(20,65535),(23,0),(10,32768),(0,19660),(2,32768)]:d.request(3,struct.pack('<HH',key,value))
        d.request(5 if args.line_in or args.chaos_lab or args.cellular_lab or args.feedback_lab else 6);print('READY',d.status())
        if args.line_in:print('LINE IN: ADC MASTER. MCLK unconnected. ADC BCK=80 LRCK=86 DOUT=85. DAC remains 73/74/75. Run check_line_in.py.')
    finally:d.close()
if __name__=='__main__':main()
