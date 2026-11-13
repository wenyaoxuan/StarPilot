import * as P from './photo.mjs';

let ok = true;
function near(name, got, want, tol) {
  const d = Math.abs(got - want);
  const pass = d <= tol;
  console.log(`${pass ? 'PASS' : 'FAIL'} ${name}: got ${got.toFixed(4)} want ${want.toFixed(4)} (d=${d.toFixed(4)})`);
  if (!pass) ok = false;
}

function cam(brand, name) {
  return P.CAMERAS.find(c => c.brand === brand && c.name === name);
}
function fovIndep(w, h, f) {
  const R = 180 / Math.PI;
  return {
    h: 2 * Math.atan(w / (2 * f)) * R,
    v: 2 * Math.atan(h / (2 * f)) * R,
    scale: 206264.80624709636 * (w * 1000 / 8) / 1000 / f
  };
}

const a6700 = cam('Sony', 'A6700');
const gh6 = cam('Panasonic', 'Lumix GH6');
const gfx = cam('Fujifilm', 'GFX 100S');
const a7s3 = cam('Sony', 'A7S III');
const canonR7 = cam('Canon', 'EOS R7');

const f1 = P.fovFor(a6700, 85);
const e1 = fovIndep(a6700.sensorW, a6700.sensorH, 85);
near('A6700 85 H', f1.hDeg, e1.h, 0.01);
near('A6700 85 V', f1.vDeg, e1.v, 0.01);
near('A6700 85 scale', f1.pixelScaleArcsec, 206264.80624709636 * a6700.pixelPitchUm / 1000 / 85, 0.01);

const f2 = P.fovFor(gh6, 300);
const e2 = fovIndep(gh6.sensorW, gh6.sensorH, 300);
near('GH6 300 H', f2.hDeg, e2.h, 0.01);
near('GH6 300 V', f2.vDeg, e2.v, 0.01);

const f3 = P.fovFor(gfx, 85);
const e3 = fovIndep(gfx.sensorW, gfx.sensorH, 85);
near('GFX 85 H', f3.hDeg, e3.h, 0.01);
near('GFX 85 V', f3.vDeg, e3.v, 0.01);

near('A7S3 85 scale', P.fovFor(a7s3, 85).pixelScaleArcsec,
  206264.80624709636 * a7s3.pixelPitchUm / 1000 / 85, 0.01);
near('A6700 85 equiv', P.equivalentFocalMm(a6700, 85), 127.5, 0.01);
near('GH6 300 equiv', P.equivalentFocalMm(gh6, 300), 600, 0.01);
near('GFX 85 equiv', P.equivalentFocalMm(gfx, 85), 67.15, 0.01);
near('R7 crop', canonR7.cropFactor, 1.6, 0.001);

near('A7R4 MP', P.cameraMegapixels(P.A7R4), 60.2, 0.2);
near('GFX MP', P.cameraMegapixels(gfx), 101.7, 0.5);

console.log(ok ? 'PASS' : 'FAIL');
process.exitCode = ok ? 0 : 1;
