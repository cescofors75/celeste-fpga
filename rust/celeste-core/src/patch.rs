use serde::{Deserialize,Serialize};
use std::collections::{BTreeMap,BTreeSet};
pub const PARAMS: &[&str]=&["chorus.rate","chorus.depth","mixer.chorus","flanger.rate","flanger.depth","mixer.flanger","crusher.bits","crusher.rate","mixer.crusher","freeze.hold","mixer.freeze","tremolo.rate","tremolo.depth","mixer.tremolo","autopan.rate","autopan.depth","mixer.autopan","envelope.depth","envelope.release","glitch.mode","glitch.size","glitch.repeats","filter.mode","chaos.rate","glitch.amount","glitch.probability","delay.time","delay.feedback","delay2.time","delay2.feedback","mixer.delay2","filter.cutoff","filter.resonance","wavefolder.drive","vca.level","lfo.rate","lfo.depth","chaos.amount","mixer.dry","mixer.glitch","mixer.delay","mixer.filter","mixer.wavefolder","mixer.vca","mixer.master"];
pub const NODES: &[&str]=&["chorus","flanger","crusher","freeze","tremolo","autopan","sample","line","glitch","delay","delay2","filter","wavefolder","vca","mixer","out"];
#[derive(Clone,Debug,Serialize,Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Patch {#[serde(default,skip_serializing_if="BTreeMap::is_empty")] pub mute:BTreeMap<String,bool>,#[serde(default,skip_serializing_if="BTreeMap::is_empty")] pub solo:BTreeMap<String,bool>,#[serde(default,skip_serializing_if="BTreeMap::is_empty")] pub bypass:BTreeMap<String,bool>,#[serde(default,skip_serializing_if="Option::is_none")] pub nodes:Option<BTreeMap<String,[f64;2]>>,pub format:String,pub version:u32,pub name:String,pub routes:Vec<[String;2]>,pub parameters:BTreeMap<String,f64>,pub hardware:BTreeMap<String,String>,#[serde(default,rename="hardwareBank1",skip_serializing_if="Option::is_none")] pub hardware_bank1:Option<BTreeMap<String,String>>,#[serde(default)] pub modulation:Vec<[String;2]>,#[serde(default)] pub touch:BTreeMap<String,String>}
impl Patch {
    pub fn validate(&self)->Result<(),String>{
        if self.format!="celeste-patch"||self.version!=1 {return Err("Unsupported patch format/version".into());}
        if self.name.trim().is_empty()||self.name.len()>120 {return Err("Patch name must have 1–120 bytes".into());}
        for (key,v) in &self.parameters {if !PARAMS.contains(&key.as_str())||!v.is_finite()||!(0.0..=1.0).contains(v){return Err(format!("Invalid parameter: {key}"));}}
        if let Some(nodes)=&self.nodes {
            for (id,xy) in nodes {if !["chorus","flanger","crusher","freeze","tremolo","autopan","envelope","sample","glitch","delay","delay2","filter","wavefolder","vca","mixer","out","lfo","chaos"].contains(&id.as_str())||!xy.iter().all(|v|v.is_finite()&&*v>=0.0&&*v<=1090.0){return Err("Invalid canvas node".into());}}
            for [a,b] in &self.routes {if !nodes.contains_key(a)||!nodes.contains_key(b){return Err("Route references a missing canvas node".into());}}
            for [a,b] in &self.modulation {if !nodes.contains_key(a)||!nodes.contains_key(b.split('.').next().unwrap_or("")){return Err("Modulation references a missing canvas node".into());}}
        }
        if self.bypass.keys().any(|k| !["chorus","flanger","crusher","freeze","tremolo","autopan","envelope","glitch","delay","delay2","filter","wavefolder","vca","lfo","chaos"].contains(&k.as_str())) {return Err("Invalid bypass component".into());}
        if self.mute.keys().chain(self.solo.keys()).any(|k| !["dry","chorus","flanger","crusher","freeze","tremolo","autopan","glitch","delay","delay2","filter","wavefolder","vca"].contains(&k.as_str())) {return Err("Invalid mute/solo component".into());}
        let mut unique=BTreeSet::new();
        for [a,b] in &self.routes {
            if !NODES.contains(&a.as_str())||!NODES.contains(&b.as_str())||a==b||a=="out"||["sample","line"].contains(&b.as_str())|| (b=="out" && a!="mixer")|| (a=="mixer" && b!="out") {return Err(format!("Invalid route: {a} → {b}"));}
            if !unique.insert((a,b)){return Err("Duplicate route".into());}
            if b!="mixer" && self.routes.iter().filter(|r| &r[1]==b).count()>1 {return Err(format!("{b} accepts only one audio source"));}
        }
        let mut seen=BTreeSet::new();
        for _ in 0..NODES.len() { for &node in NODES { if self.routes.iter().filter(|r|r[1]==node).all(|r|seen.contains(r[0].as_str())) {seen.insert(node);} } }
        if seen.len()!=NODES.len(){return Err("Audio feedback cycles are not supported in V1".into());}
        for (encoder,param) in self.hardware.iter().chain(self.hardware_bank1.iter().flat_map(|m|m.iter())) {if !(1..=8).any(|i| encoder==&format!("encoder{i}"))||!PARAMS.contains(&param.as_str()){return Err("Invalid encoder mapping".into());}}
        let mut mods=BTreeSet::new();
        for [source,param] in &self.modulation {if !["lfo","chaos","envelope"].contains(&source.as_str())||!PARAMS.contains(&param.as_str())||!mods.insert((source,param)){return Err("Invalid modulation route".into());}}
        for (event,action) in &self.touch {if !["short","long","double"].contains(&event.as_str())||!["next-page","mutate","hold","none"].contains(&action.as_str()){return Err("Invalid touch mapping".into());}}
        Ok(())
    }
}
pub fn parse_patch(s:&str)->Result<Patch,String>{let p:Patch=serde_json::from_str(s).map_err(|e|e.to_string())?;p.validate()?;Ok(p)}
#[derive(Clone,Serialize,Deserialize)]
#[serde(deny_unknown_fields)]
pub struct SampleRef {pub name:String,pub size:u64,pub sha256:String}
#[derive(Clone,Serialize,Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Session {pub format:String,pub version:u32,pub sample:Option<SampleRef>,pub patch:Patch,pub position:u64,pub looping:bool,pub tempo:Option<f64>}
pub fn parse_session(s:&str)->Result<Session,String>{
    let session:Session=serde_json::from_str(s).map_err(|e|e.to_string())?;
    if session.format!="celeste-session"||session.version!=1||session.tempo.is_some_and(|v|!v.is_finite()||v<=0.0||v>999.0){return Err("Invalid session".into());}
    if let Some(sample)=&session.sample {if sample.name.is_empty()||sample.size==0||sample.sha256.len()!=64||!sample.sha256.bytes().all(|b|b.is_ascii_hexdigit()){return Err("Invalid sample reference".into());}}
    session.patch.validate()?;Ok(session)
}
#[cfg(test)] mod tests{
 use super::*;
 fn example()->Patch {parse_patch(include_str!("../../../patches/parallel-dreams.json")).unwrap()}
 #[test] fn valid_roundtrip(){let p=example();assert_eq!(parse_patch(&serde_json::to_string(&p).unwrap()).unwrap().name,p.name);}
 #[test] fn bank1_roundtrip_and_validation(){let mut p=example();p.hardware_bank1=Some(BTreeMap::from([("encoder1".into(),"wavefolder.drive".into())]));let s=serde_json::to_string(&p).unwrap();assert!(s.contains("hardwareBank1"));assert_eq!(parse_patch(&s).unwrap().hardware_bank1,p.hardware_bank1);p.hardware_bank1.as_mut().unwrap().insert("encoder9".into(),"vca.level".into());assert!(p.validate().is_err());}
 #[test] fn rejects_cycle(){let mut p=example();p.routes=vec![["glitch".into(),"delay".into()],["delay".into(),"glitch".into()]];assert!(p.validate().is_err());}
 #[test] fn rejects_parameter(){let mut p=example();p.parameters.insert("delay.feedback".into(),1.1);assert!(p.validate().is_err());}
 #[test] fn rejects_unknown_mapping(){let mut p=example();p.hardware.insert("encoder9".into(),"mixer.master".into());assert!(p.validate().is_err());}
}
