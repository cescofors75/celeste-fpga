use serde::Serialize;
use std::io::Cursor;

pub const SAMPLE_RATE: u32 = 48_000;
pub const MAX_FILE_BYTES: usize = 128 * 1024 * 1024;
#[derive(Serialize)]
pub struct Metadata {
    pub source_rate: u32,
    pub source_channels: u16,
    pub source_bits: u16,
    pub frames: usize,
    pub target_rate: u32,
    pub duration: f64,
}
pub struct Audio {
    pub metadata: Metadata,
    /// Interleaved signed Q1.15 stereo. The host owns the complete sample.
    pub pcm: Vec<i16>,
}
pub fn quantize(x: f64) -> i16 {
    if !x.is_finite() { return 0; }
    (x * 32768.0).round().clamp(-32768.0, 32767.0) as i16
}
pub fn decode(bytes: &[u8]) -> Result<Audio, String> {
    if bytes.len() > MAX_FILE_BYTES { return Err("WAV exceeds 128 MiB limit".into()); }
    let mut reader = hound::WavReader::new(Cursor::new(bytes)).map_err(|e| e.to_string())?;
    let spec = reader.spec();
    if ![1,2].contains(&spec.channels) || ![44100,48000].contains(&spec.sample_rate) {
        return Err("Use mono/stereo WAV at 44.1 or 48 kHz".into());
    }
    let samples: Vec<f64> = match spec.sample_format {
        hound::SampleFormat::Float if spec.bits_per_sample == 32 => reader.samples::<f32>()
            .map(|v| v.map(|x| if x.is_finite() { x as f64 } else {0.0})).collect::<Result<_,_>>(),
        hound::SampleFormat::Int if [8,16,24,32].contains(&spec.bits_per_sample) => {
            let scale = 2_f64.powi(spec.bits_per_sample as i32 - 1);
            reader.samples::<i32>().map(|v| v.map(|x| x as f64 / scale)).collect::<Result<_,_>>()
        },
        _ => return Err("Unsupported WAV encoding".into()),
    }.map_err(|e| e.to_string())?;
    let channels = spec.channels as usize;
    if samples.is_empty() || samples.len() % channels != 0 { return Err("Empty or incomplete WAV frames".into()); }
    let input_frames = samples.len() / channels;
    let frames = (input_frames as u64 * SAMPLE_RATE as u64).div_ceil(spec.sample_rate as u64) as usize;
    let mut pcm = Vec::with_capacity(frames * 2);
    for frame in 0..frames {
        let position = frame as f64 * spec.sample_rate as f64 / SAMPLE_RATE as f64;
        for channel in 0..2 {
            let channel = channel.min(channels - 1);
            let value = if spec.sample_rate == SAMPLE_RATE {
                samples[frame * channels + channel]
            } else {
                // 32-tap Hann-windowed sinc reconstruction; 44.1 -> 48 kHz only.
                // Clamp endpoints and normalize the kernel to preserve DC.
                let center = position.floor() as isize;
                let (mut sum, mut weight) = (0.0, 0.0);
                for tap in -15..=16 {
                    let idx = center + tap;
                    let d = position - idx as f64;
                    if d.abs() >= 16.0 { continue; }
                    let sinc = if d.abs() < 1e-12 { 1.0 } else { (std::f64::consts::PI*d).sin()/(std::f64::consts::PI*d) };
                    let w = sinc * (0.5 + 0.5 * (std::f64::consts::PI*d/16.0).cos());
                    sum += samples[idx.clamp(0,input_frames as isize-1) as usize * channels+channel] * w;
                    weight += w;
                }
                sum / weight
            };
            pcm.push(quantize(value));
        }
    }
    Ok(Audio { metadata: Metadata {source_rate: spec.sample_rate, source_channels: spec.channels,
        source_bits: spec.bits_per_sample, frames, target_rate: SAMPLE_RATE, duration: frames as f64 / SAMPLE_RATE as f64}, pcm })
}

impl Audio {
    pub fn chunk(&self, start: usize, count: usize) -> Vec<u8> {
        let end = start.saturating_add(count).min(self.metadata.frames);
        if start >= end { return vec![]; }
        self.pcm[start*2..end*2].iter().flat_map(|s| s.to_le_bytes()).collect()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    fn wav(rate: u32, channels: u16, bits: u16, values: &[i32]) -> Vec<u8> {
        let mut c = Cursor::new(Vec::new());
        { let mut w = hound::WavWriter::new(&mut c, hound::WavSpec {channels, sample_rate:rate,bits_per_sample:bits,sample_format:hound::SampleFormat::Int}).unwrap();
          for &v in values { w.write_sample(v).unwrap(); } w.finalize().unwrap(); }
        c.into_inner()
    }
    #[test] fn formats_and_stereo_pairing() {
        for bits in [8,16,24,32] { let max = ((1_i64 << (bits-1))-1) as i32; let a=decode(&wav(48000,2,bits,&[max,-max,0,0])).unwrap(); assert!(a.pcm[0]>32000); assert!(a.pcm[1]< -32000); assert_eq!(a.chunk(1,99),vec![0;4]); }
    }
    #[test] fn resample_mono_dc_duration() {
        let a=decode(&wav(44100,1,16,&vec![8192;441])).unwrap();
        assert_eq!(a.metadata.frames,480); assert!(a.pcm.iter().all(|&v| v==8192));
    }
    #[test] fn quantization_saturates() { assert_eq!(quantize(1.5),32767); assert_eq!(quantize(-2.0),-32768); assert_eq!(quantize(f64::NAN),0); }
    #[test] fn reject_invalid() { assert!(decode(b"RIFF").is_err()); assert!(decode(&wav(22050,1,16,&[0])).is_err()); assert!(decode(&wav(48000,1,16,&[])).is_err()); }
    #[test] fn float_sanitized() {
        let mut c=Cursor::new(Vec::new());
        { let mut w=hound::WavWriter::new(&mut c,hound::WavSpec {channels:1,sample_rate:48000,bits_per_sample:32,sample_format:hound::SampleFormat::Float}).unwrap(); for v in [0.5_f32,f32::NAN,-2.0] {w.write_sample(v).unwrap();} w.finalize().unwrap(); }
        assert_eq!(decode(&c.into_inner()).unwrap().pcm,vec![16384,16384,0,0,-32768,-32768]);
    }
    #[test] fn pcm16_is_bit_exact_and_channels_stay_independent() {
        let values:Vec<i32> = (-32768..=32767).flat_map(|x|[x,0]).collect();
        let a=decode(&wav(48000,2,16,&values)).unwrap();
        assert!(a.pcm.iter().zip(values).all(|(&a,b)|a as i32==b));
        assert!(a.chunk(usize::MAX,usize::MAX).is_empty());
    }
    #[test] fn resampler_bandwidth_and_stereo_isolation() {
        use std::f64::consts::PI;
        for frequency in [100.0,1000.0,10000.0,18000.0,20000.0] {
            let values:Vec<i32>=(0..8820).flat_map(|n|[((2.0*PI*frequency*n as f64/44100.0).sin()*12000.0).round() as i32,0]).collect();
            let a=decode(&wav(44100,2,16,&values)).unwrap();
            assert_eq!(a.metadata.frames,9600);
            assert!(a.pcm.iter().skip(1).step_by(2).all(|&v|v==0));
            let (mut real,mut imag,mut residual)=(0.0,0.0,0.0);
            for n in 480..9120 {let phase=2.0*PI*frequency*n as f64/48000.0;let v=a.pcm[2*n] as f64;
                real+=v*phase.cos();imag+=v*phase.sin();residual+=(v-12000.0*phase.sin()).powi(2);}
            let amplitude=2.0*(real*real+imag*imag).sqrt()/8640.0;
            let gain_db=20.0*(amplitude/12000.0).log10();
            let error_db=20.0*((residual/8640.0).sqrt()/32768.0).log10();
            println!("RESAMPLE {frequency} Hz: gain {gain_db:.3} dB, error {error_db:.2} dBFS");
            assert!(gain_db.abs()<1.0,"resampler gain at {frequency}: {gain_db}");
            assert!(error_db < -35.0,"resampler error at {frequency}: {error_db}");
        }
    }
}
