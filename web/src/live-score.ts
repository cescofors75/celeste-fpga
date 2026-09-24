export const LIVE_BPM=168;
export const LIVE_RATE=48000;
export const LIVE_BARS=192;
export const LIVE_FRAMES=Math.round(LIVE_BARS*4*60/LIVE_BPM*LIVE_RATE);
export const LIVE_SECONDS=LIVE_FRAMES/LIVE_RATE;
export const LIVE_SECTION_SECONDS=16*4*60/LIVE_BPM;
export const liveScenes=[
 '01 · First light — espacio y aire','02 · Soft currents — entra el break',
 '03 · Deep blue — bajo y movimiento','04 · Glass gardens — chorus y ecos',
 '05 · Orbital drift — pulsos estéreo','06 · Parallel tides — dos delays',
 '07 · Still water — suspensión ambiental','08 · Night train — regreso del groove',
 '09 · Fragments — detalles de glitch','10 · Open sky — filtro y envolvente',
 '11 · Afterimages — texturas y reflejos','12 · Weightless — regreso al silencio',
];
export const sectionAt=(seconds:number)=>Math.min(11,Math.floor((((seconds%LIVE_SECONDS)+LIVE_SECONDS)%LIVE_SECONDS)/LIVE_SECTION_SECONDS));
