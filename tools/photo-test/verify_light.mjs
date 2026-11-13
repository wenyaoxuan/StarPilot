import * as L from './lightpollution.mjs';
import * as P from './photo.mjs';
let ok = true;
function near(name, got, want, tol) {
  const d = Math.abs(got - want);
  const pass = d <= tol;
  console.log(`${pass ? 'PASS' : 'FAIL'} ${name}: got ${got.toFixed(4)} want ${want.toFixed(4)} (d=${d.toFixed(4)})`);
  if (!pass) ok = false;
}
const ref = { name:'ref', brand:'x', format:'FF', cropFactor:1, sensorW:36, sensorH:24,
  pixelPitchUm:3.75, pixelsX:9600, pixelsY:6400 };
const rate82 = L.skyElectronRate(ref, 4.2, 8.2);
near('SharpCap calibration B8.2 f4.2 3.75um', rate82, 14.5, 0.5);
console.log('B1 SQM', L.bortleToSqm(1), 'B9 SQM', L.bortleToSqm(9));
console.log('B1 rate', L.skyElectronRate(ref,4.2,1).toFixed(3), 'B9 rate', L.skyElectronRate(ref,4.2,9).toFixed(3));
const c = P.CAMERAS.find(x => x.name === 'A7R IV');
for (const iso of [100,800,3200,12800]) {
  const m = L.skyModel(c, 2.8, 9, iso);
  console.log(`ISO ${iso}: rn=${m.readNoiseE.toFixed(2)} tSky=${m.skyLimitedSec.toFixed(2)} tSat=${m.saturationSec.toFixed(1)} rec=${m.recommendedSubSec.toFixed(2)}`);
}
const m1 = L.skyModel(c,2.8,1,800), m9 = L.skyModel(c,2.8,9,800);
console.log('B1 vs B9 skyRate ratio', (m9.skyRate/m1.skyRate).toFixed(2));
console.log('B1 tSky', m1.skyLimitedSec.toFixed(1), 'B9 tSky', m9.skyLimitedSec.toFixed(2));
console.log(ok ? 'PASS' : 'FAIL');
process.exitCode = ok ? 0 : 1;
