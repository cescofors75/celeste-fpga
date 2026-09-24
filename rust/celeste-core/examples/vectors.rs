fn main(){
 let packet=celeste_core::protocol::encode(4,0x12345678,&[0,128,255,127]).unwrap();
 let text=packet.iter().map(|b|format!("{b:02x}\n")).collect::<String>();
 std::fs::write("fpga/sim/audio_packet.hex",text).unwrap();
 let ping=celeste_core::protocol::encode(1,0,&[]).unwrap();std::fs::write("build/ping.bin",ping).unwrap();
 for (name,kind) in [("ping",1),("status",2),("param",3),("start",5),("stop",6),("drain",7)] {
  let b=celeste_core::protocol::encode(kind,0,&[]).unwrap();
  std::fs::write(format!("fpga/sim/{name}_packet.hex"),b.iter().map(|v|format!("{v:02x}\n")).collect::<String>()).unwrap();
 }
}
