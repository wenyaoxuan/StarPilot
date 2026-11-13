import * as S from './solar.mjs';
import { createRequire } from 'node:module';
const require = createRequire(import.meta.url);
const A = require('astronomy-engine');
const D2R = Math.PI / 180;
const R2D = 180 / Math.PI;

const bodies = [
  ['SUN', A.Body.Sun],
  ['MOON', A.Body.Moon],
  ['MERCURY', A.Body.Mercury],
  ['VENUS', A.Body.Venus],
  ['MARS', A.Body.Mars],
  ['JUPITER', A.Body.Jupiter],
  ['SATURN', A.Body.Saturn],
  ['URANUS', A.Body.Uranus],
  ['NEPTUNE', A.Body.Neptune]
];
const cases = [
  { name: 'Shenzhen 2026-11-08', lat: 22.5431, lon: 114.0579, y: 2026, m: 11, d: 8 },
  { name: 'Beijing 2026-11-08', lat: 39.9042, lon: 116.4074, y: 2026, m: 11, d: 8 },
  { name: 'Beijing 2026-01-15', lat: 39.9042, lon: 116.4074, y: 2026, m: 1, d: 15 },
  { name: 'Sydney 2026-12-21', lat: -33.8688, lon: 151.2093, y: 2026, m: 12, d: 21 },
  { name: 'Tromso 2026-12-21', lat: 69.6492, lon: 18.9553, y: 2026, m: 12, d: 21 }
];

function sep(a, b) {
  const d1 = a.decDeg * D2R, d2 = b.decDeg * D2R;
  const dra = (a.raHours - b.raHours) * 15 * D2R;
  const c = Math.sin(d1) * Math.sin(d2) + Math.cos(d1) * Math.cos(d2) * Math.cos(dra);
  return Math.acos(Math.max(-1, Math.min(1, c))) * R2D;
}
let max = 0;
for (const c of cases) {
  const date = new Date(Date.UTC(c.y, c.m - 1, c.d, 12, 0, 0));
  const jd = date.getTime() / 86400000 + 2440587.5;
  const obs = new A.Observer(c.lat, c.lon, 0);
  const parts = [];
  for (const [id, body] of bodies) {
    const ours = S.solarPosition(id, jd, c.lat, c.lon);
    const ref = A.Equator(body, date, obs, true, true);
    const e = sep(ours, { raHours: ref.ra, decDeg: ref.dec });
    if (e > max) max = e;
    parts.push(`${id}:${(e * 60).toFixed(2)}'`);
  }
  console.log(c.name.padEnd(22), parts.join(' '));
}
console.log('MAX separation arcmin', (max * 60).toFixed(2));
