import * as S from './astro.mjs';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const A = require('astronomy-engine');

const D2R = Math.PI / 180;
const R2D = 180 / Math.PI;

const cases = [
  { name: 'Beijing 2026-11-07', lat: 39.9042, lon: 116.4074, tz: 480, y: 2026, m: 11, d: 7 },
  { name: 'Beijing 2026-01-15', lat: 39.9042, lon: 116.4074, tz: 480, y: 2026, m: 1, d: 15 },
  { name: 'Shanghai 2026-06-21', lat: 31.2304, lon: 121.4737, tz: 480, y: 2026, m: 6, d: 21 },
  { name: 'Lhasa 2027-03-01', lat: 29.6520, lon: 91.1721, tz: 480, y: 2027, m: 3, d: 1 },
  { name: 'Sydney 2026-12-21', lat: -33.8688, lon: 151.2093, tz: 660, y: 2026, m: 12, d: 21 },
  { name: 'Tromso 2026-12-21', lat: 69.6492, lon: 18.9553, tz: 60, y: 2026, m: 12, d: 21 }
];

function angDiff(a, b) {
  let d = (a - b) % 360;
  if (d > 180) d -= 360;
  if (d < -180) d += 360;
  return Math.abs(d);
}

function horSep(a, b) {
  const a1 = a.altDeg * D2R;
  const a2 = b.altDeg * D2R;
  const dAz = (a.azDeg - b.azDeg) * D2R;
  const cosSep = Math.sin(a1) * Math.sin(a2) + Math.cos(a1) * Math.cos(a2) * Math.cos(dAz);
  return Math.acos(Math.max(-1, Math.min(1, cosSep))) * R2D;
}

function eqOf(x) {
  return { raHours: x.ra, decDeg: x.dec };
}

const rows = [];
const max = {
  sunPos: 0, sunAltAz: 0, moonLon: 0, moonLat: 0, illum: 0,
  starPos: 0, starAltAz: 0, twiMin: 0, riseMin: 0, setMin: 0
};

A.DefineStar(A.Body.Star1, 0.712, 41.267, 2500000);

for (const c of cases) {
  const midnight = S.civilToUtcMs(c.y, c.m, c.d, 0, 0, c.tz);
  const ms = midnight + 12 * 3600000;
  const jd = S.jdFromUnixMs(ms);
  const date = new Date(ms);
  const obs = new A.Observer(c.lat, c.lon, 0);

  const refSun = A.Equator(A.Body.Sun, date, obs, true, true);
  const ourSun = S.sunEquatorial(jd);
  const sunPos = S.angularSeparationDeg(ourSun, eqOf(refSun));

  const refHor = A.Horizon(date, obs, refSun.ra, refSun.dec, null);
  const ourSunHor = S.equatorialToHorizontal(ourSun, jd, c.lat, c.lon);
  const sunAltAz = horSep(ourSunHor, { azDeg: refHor.azimuth, altDeg: refHor.altitude });

  const refEcl = A.EclipticGeoMoon(date);
  const ourEcl = S.moonEcliptic(jd);
  const moonLon = angDiff(ourEcl.lambdaDeg, refEcl.lon);
  const moonLat = Math.abs(ourEcl.betaDeg - refEcl.lat);

  const refIll = A.Illumination(A.Body.Moon, date).phase_fraction;
  const ourIll = S.moonPhase(jd).illumination;
  const illum = Math.abs(ourIll - refIll);

  const refStar = A.Equator(A.Body.Star1, date, obs, true, true);
  const ourStar = S.precessFromJ2000(0.712, 41.267, jd);
  const starPos = S.angularSeparationDeg(ourStar, eqOf(refStar));

  const refStarHor = A.Horizon(date, obs, refStar.ra, refStar.dec, null);
  const ourStarHor = S.targetHorizontal({ raHours: 0.712, decDeg: 41.267 }, jd, c.lat, c.lon);
  const starAltAz = horSep(ourStarHor, { azDeg: refStarHor.azimuth, altDeg: refStarHor.altitude });

  const tw = S.astronomicalTwilight(midnight, c.lat, c.lon);
  const noon = new Date(midnight + 12 * 3600000);
  const refEve = A.SearchAltitude(A.Body.Sun, obs, -1, noon, 1, -18);
  const refMorn = refEve ? A.SearchAltitude(A.Body.Sun, obs, +1, refEve.date, 1, -18) : null;
  let twiMin = 0;
  if (tw.eveningEndMs > 0 && refEve && refMorn) {
    twiMin = Math.max(
      Math.abs(tw.eveningEndMs - refEve.date.getTime()) / 60000,
      Math.abs(tw.morningStartMs - refMorn.date.getTime()) / 60000
    );
  }

  const rs = S.sunRiseSet(midnight, c.lat, c.lon);
  const refRise = A.SearchRiseSet(A.Body.Sun, obs, +1, new Date(midnight), 1);
  const refSet = A.SearchRiseSet(A.Body.Sun, obs, -1, new Date(midnight), 1);
  let riseMin = 0;
  let setMin = 0;
  if (rs.riseMs > 0 && refRise) riseMin = Math.abs(rs.riseMs - refRise.date.getTime()) / 60000;
  if (rs.setMs > 0 && refSet) setMin = Math.abs(rs.setMs - refSet.date.getTime()) / 60000;

  const row = { name: c.name, sunPos, sunAltAz, moonLon, moonLat, illum, starPos, starAltAz, twiMin, riseMin, setMin };
  rows.push(row);

  for (const k of ['sunPos', 'sunAltAz', 'moonLon', 'moonLat', 'illum', 'starPos', 'starAltAz', 'twiMin', 'riseMin', 'setMin']) {
    if (row[k] > max[k]) max[k] = row[k];
  }
}

console.log('name'.padEnd(22), 'sunPos', 'sunAA', 'moonLon', 'moonLat', 'illum', 'starPos', 'starAA', 'twiMin', 'riseMin', 'setMin');
for (const r of rows) {
  console.log(
    r.name.padEnd(22),
    r.sunPos.toFixed(4), r.sunAltAz.toFixed(4), r.moonLon.toFixed(4), r.moonLat.toFixed(4),
    r.illum.toFixed(5), r.starPos.toFixed(4), r.starAltAz.toFixed(4),
    r.twiMin.toFixed(2), r.riseMin.toFixed(2), r.setMin.toFixed(2)
  );
}
console.log('MAX'.padEnd(22),
  max.sunPos.toFixed(4), max.sunAltAz.toFixed(4), max.moonLon.toFixed(4), max.moonLat.toFixed(4),
  max.illum.toFixed(5), max.starPos.toFixed(4), max.starAltAz.toFixed(4),
  max.twiMin.toFixed(2), max.riseMin.toFixed(2), max.setMin.toFixed(2));

// Target window sanity: M31 at Beijing, 2026-11-07.
const mid = S.civilToUtcMs(2026, 11, 7, 0, 0, 480);
const wins = S.targetVisibleWindows({ raHours: 0.712, decDeg: 41.267 }, mid, 39.9042, 116.4074, [], 20);
console.log('\nM31 windows @ Beijing (alt>=20, sun<=-18):');
for (const w of wins) {
  console.log(' ', new Date(w.startMs).toISOString(), '->', new Date(w.endMs).toISOString(),
    'peak', w.peakAltDeg.toFixed(1) + 'deg');
}
const best = S.longestWindow(wins);
console.log('longest', best ? ((best.endMs - best.startMs) / 3600000).toFixed(2) + ' h' : 'none');

// Horizon mask checks.
const sectors = new Array(16).fill(0);
sectors[0] = 30;
const mask = S.maskFromSectors(sectors);
let okMask = mask.length === 360 && mask[0] === 30 && mask[180] === 0;
console.log(`${okMask ? 'PASS' : 'FAIL'} maskFromSectors N30/S0 -> ${mask[0]}/${mask[180]}`);
okMask = okMask && S.targetVisibleWindows({ raHours: 0.712, decDeg: 41.267 }, mid, 39.9042, 116.4074, new Array(360).fill(90), 20).length === 0;
console.log(`${okMask ? 'PASS' : 'FAIL'} all-sky 90 blocks M31`);

const limits = {
  sunPos: 0.02, sunAltAz: 0.02, moonLon: 0.05, moonLat: 0.05, illum: 0.002,
  starPos: 0.02, starAltAz: 0.02, twiMin: 2, riseMin: 6, setMin: 6
};
let ok = true;
for (const k of Object.keys(limits)) {
  if (max[k] > limits[k]) {
    console.log(`FAIL ${k}: ${max[k]} > ${limits[k]}`);
    ok = false;
  }
}
console.log(ok && okMask ? 'PASS' : 'FAIL');
process.exitCode = (ok && okMask) ? 0 : 1;
process.exitCode = ok ? 0 : 1;
