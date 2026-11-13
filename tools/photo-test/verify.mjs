import * as P from './photo.mjs';

let ok = true;
function near(name, got, want, tol) {
  const d = Math.abs(got - want);
  const pass = d <= tol;
  console.log(`${pass ? 'PASS' : 'FAIL'} ${name}: got ${got.toFixed(4)} want ${want.toFixed(4)} (d=${d.toFixed(4)})`);
  if (!pass) ok = false;
}

const fov85 = P.fovFor(P.A7R4, 85);
near('FOV 85 H', fov85.hDeg, 23.72, 0.02);
near('FOV 85 V', fov85.vDeg, 15.92, 0.02);
near('FOV 85 diag', fov85.diagDeg, 28.30, 0.05);
near('scale 85', fov85.pixelScaleArcsec, 9.124, 0.01);

const fov300 = P.fovFor(P.A7R4, 300);
near('FOV 300 H', fov300.hDeg, 6.81, 0.02);
near('FOV 300 V', fov300.vDeg, 4.54, 0.02);
near('scale 300', fov300.pixelScaleArcsec, 2.585, 0.01);

near('NPF 85 f1.8 dec0', P.npfSeconds(85, 1.8, 3.76, 0), 2.068, 0.01);
near('NPF 300 f6.3 dec0', P.npfSeconds(300, 6.3, 3.76, 0), 1.111, 0.01);
near('NPF 85 f1.8 dec60', P.npfSeconds(85, 1.8, 3.76, 60), 4.136, 0.02);
near('500 85', P.rule500Seconds(85), 5.882, 0.01);
near('500 300', P.rule500Seconds(300), 1.667, 0.01);
near('1px drag 85 dec0', P.pixelDragSeconds(85, 3.76, 1, 0), 0.607, 0.01);
near('1px drag 300 dec0', P.pixelDragSeconds(300, 3.76, 1, 0), 0.172, 0.01);
near('1px drag 85 dec60', P.pixelDragSeconds(85, 3.76, 1, 60), 1.213, 0.01);

const s1 = P.stackPlan(3600, 30);
console.log(`${s1.count === 120 && s1.actualTotalSec === 3600 ? 'PASS' : 'FAIL'} stack 3600/30 -> ${s1.count} x ${s1.actualTotalSec}`);
if (!(s1.count === 120 && s1.actualTotalSec === 3600)) ok = false;

const s2 = P.stackPlan(3600, 2.068);
console.log(`${s2.count === 1741 ? 'PASS' : 'FAIL'} stack 3600/2.068 -> ${s2.count} (${s2.actualTotalSec.toFixed(1)}s)`);
if (s2.count !== 1741) ok = false;

const s3 = P.stackPlan(3600, 0);
console.log(`${s3.count === 0 ? 'PASS' : 'FAIL'} stack zero sub -> ${s3.count}`);
if (s3.count !== 0) ok = false;

console.log(ok ? 'PASS' : 'FAIL');
process.exitCode = ok ? 0 : 1;
