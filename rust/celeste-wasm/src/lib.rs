use wasm_bindgen::prelude::*;
use celeste_core::{audio,patch,protocol};
fn err(e:String)->JsValue {JsValue::from_str(&e)}
#[wasm_bindgen]
pub struct PreparedAudio {audio:audio::Audio}
#[wasm_bindgen]
impl PreparedAudio {
    #[wasm_bindgen(constructor)]
    pub fn new(bytes:&[u8])->Result<PreparedAudio,JsValue>{Ok(Self{audio:audio::decode(bytes).map_err(err)?})}
    pub fn metadata(&self)->String {serde_json::to_string(&self.audio.metadata).unwrap()}
    pub fn chunk(&self,start:u32,count:u32)->Vec<u8>{self.audio.chunk(start as usize,count as usize)}
    pub fn waveform(&self,bins:u32)->Vec<f32>{let n=(bins as usize).clamp(1,2048);let frames=self.audio.metadata.frames;
        (0..n).map(|i| {let a=i*frames/n;let b=((i+1)*frames/n).max(a+1).min(frames);self.audio.pcm[a*2..b*2].iter().map(|v|(*v as f32/32768.0).abs()).fold(0.0,f32::max)}).collect()}
}
#[wasm_bindgen]
pub fn validate_patch(s:&str)->Result<String,JsValue>{Ok(serde_json::to_string(&patch::parse_patch(s).map_err(err)?).unwrap())}
#[wasm_bindgen]
pub fn validate_session(s:&str)->Result<String,JsValue>{Ok(serde_json::to_string(&patch::parse_session(s).map_err(err)?).unwrap())}
#[wasm_bindgen]
pub fn encode_packet(kind:u8,sequence:u32,payload:&[u8])->Result<Vec<u8>,JsValue>{protocol::encode(kind,sequence,payload).map_err(err)}
#[wasm_bindgen]
pub fn validate_packet(bytes:&[u8])->Result<(),JsValue>{protocol::decode(bytes).map(|_|()).map_err(err)}
