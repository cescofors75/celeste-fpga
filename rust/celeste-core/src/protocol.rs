pub const MAX_PAYLOAD: usize = 1024;
pub const PING: u8=1;
pub const GET_STATUS: u8=2;
pub const SET_PARAM: u8=3;
pub const AUDIO: u8=4;
pub const START: u8=5;
pub const STOP: u8=6;
#[derive(Debug, PartialEq)]
pub struct Packet {pub kind:u8,pub sequence:u32,pub payload:Vec<u8>}
pub fn crc16(bytes:&[u8])->u16 {
    let mut crc=0xffff_u16;
    for &b in bytes { crc^=(b as u16)<<8; for _ in 0..8 {crc=if crc&0x8000!=0 {(crc<<1)^0x1021} else {crc<<1};} }
    crc
}
pub fn encode(kind:u8, sequence:u32, payload:&[u8])->Result<Vec<u8>,String> {
    if payload.len()>MAX_PAYLOAD {return Err("Packet too large".into());}
    let mut b=vec![0x43,0x45,1,kind]; b.extend(sequence.to_le_bytes()); b.extend((payload.len() as u16).to_le_bytes()); b.extend(payload);
    b.extend(crc16(&b[2..]).to_le_bytes()); Ok(b)
}
pub fn decode(b:&[u8])->Result<Packet,String> {
    if b.len()<12 || b[..3]!=[0x43,0x45,1] {return Err("Invalid header".into());}
    let len=u16::from_le_bytes([b[8],b[9]]) as usize;
    if len>MAX_PAYLOAD || b.len()!=len+12 {return Err("Invalid packet length".into());}
    if crc16(&b[2..b.len()-2])!=u16::from_le_bytes([b[b.len()-2],b[b.len()-1]]) {return Err("CRC mismatch".into());}
    Ok(Packet {kind:b[3],sequence:u32::from_le_bytes(b[4..8].try_into().unwrap()),payload:b[10..10+len].to_vec()})
}
#[cfg(test)] mod tests {
    use super::*;
    #[test] fn crc_standard_vector(){assert_eq!(crc16(b"123456789"),0x29b1);}
    #[test] fn packet_roundtrip_and_corruption(){let mut b=encode(AUDIO,0x12345678,&[0,128,255,127]).unwrap(); assert_eq!(decode(&b).unwrap().sequence,0x12345678); b[10]^=1;assert!(decode(&b).is_err());}
    #[test] fn bounds(){assert!(encode(1,0,&vec![0;1025]).is_err());for n in 0..12 {assert!(decode(&vec![0;n]).is_err());}}
}
