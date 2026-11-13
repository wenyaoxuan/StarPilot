import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { transformSync } from '../photo-test/node_modules/esbuild/lib/main.js';

const folder = new URL('../../starpilot-watch/entry/src/main/ets/common/', import.meta.url);
function compile(file) {
  return transformSync(readFileSync(new URL(file, folder), 'utf8'), { loader: 'ts', format: 'esm' }).code;
}
const url = (code) => 'data:text/javascript;base64,' + Buffer.from(code).toString('base64');
const astro = url(compile('Astro.ets'));
const { lstDeg, jdFromUnixMs, norm180, norm360, civilToUtcMs } = await import(astro);
const engine = url(compile('PolarAlignEngine.ets').replace('"./Astro"', JSON.stringify(astro)));
const { polarTarget, driftCandidate, driftCandidates, compareDrift, remainingDriftSeconds,
  PolarAxis, DriftField, DriftDirection, DriftTrend } = await import(engine);

assert.deepEqual(polarTarget(31.2, false), { north: true, altitude: 31.2, azimuth: 0 });
assert.deepEqual(polarTarget(-33.45, true), { north: false, altitude: 33.45, azimuth: 180 });
assert.equal(polarTarget(-90, true).azimuth, null);
assert.equal(polarTarget(90, false).azimuth, null);
assert.equal(polarTarget(0, false).azimuth, 180);
assert.equal(polarTarget(0, true).azimuth, 0);
assert.equal(polarTarget(NaN, false), null);
assert.equal(polarTarget(91, false), null);

const time = Date.UTC(2000, 0, 1, 12);
assert.equal(civilToUtcMs(2000, 1, 1, 20, 0, 480), time);
const site = { lat: 30, lon: 37.3, mask: [], southWindow: false };
const limited = { ...site, southWindow: true };
const local = lstDeg(jdFromUnixMs(time), site.lon);
function star(hourAngle, decDeg = 0, mag = 2) {
  return { id: 'synthetic-' + hourAngle, name: 'synthetic', nameEn: 'synthetic', constellation: '',
    raHours: norm360(local - hourAngle) / 15, decDeg, mag, identifiable: true };
}
function near(actual, expected) {
  assert.ok(Math.abs(actual - expected) < 1e-8, `expected ${expected}; got ${actual}`);
}
const meridian = driftCandidate(star(0), limited, PolarAxis.Azimuth, time);
assert.equal(meridian.field, DriftField.Meridian);
near(meridian.alt, 60);
near(meridian.az, 180);
const west = driftCandidate(star(58), site, PolarAxis.Altitude, time);
const east = driftCandidate(star(-58), site, PolarAxis.Altitude, time);
assert.equal(west.field, DriftField.EastWest);
assert.equal(east.field, DriftField.EastWest);
near(west.alt, Math.asin(Math.cos(Math.PI / 6) * Math.cos(58 * Math.PI / 180)) * 180 / Math.PI);
near(west.az + east.az, 360);
assert.equal(driftCandidate(star(-58), limited, PolarAxis.Altitude, time), null);
const southwest = driftCandidate(star(45), limited, PolarAxis.Altitude, time);
assert.equal(southwest.field, DriftField.Southwest);
assert.equal(driftCandidate(star(58), limited, PolarAxis.Altitude, time).field, DriftField.Southwest);
assert.equal(driftCandidates([star(0), star(-58)], limited, PolarAxis.Altitude, time).length, 0);
const south = { ...site, lat: -30 };
near(norm180(driftCandidate(star(0), south, PolarAxis.Azimuth, time).az), 0);
assert.equal(driftCandidate(star(0), { ...south, southWindow: true }, PolarAxis.Azimuth, time), null);
assert.equal(driftCandidate(star(0), { ...site, mask: Array(16).fill(80) }, PolarAxis.Azimuth, time), null);
assert.equal(driftCandidate(star(0), { ...site, lat: 75 }, PolarAxis.Azimuth, time), null);
assert.equal(driftCandidate(star(90), site, PolarAxis.Altitude, time), null);
assert.equal(driftCandidate(star(0, 25), site, PolarAxis.Azimuth, time), null);
assert.equal(driftCandidate(star(0, 0, 5), site, PolarAxis.Azimuth, time), null);
const wrongLongitude = driftCandidate(star(0), { ...site, lon: site.lon + 40 }, PolarAxis.Azimuth, time);
assert.equal(wrongLongitude, null);
assert.ok(driftCandidates([star(45), star(58)], site, PolarAxis.Altitude, time)[0].field === DriftField.EastWest);

const start = Date.UTC(2026, 11, 31, 23, 59, 30);
for (const seconds of [60, 120, 180]) {
  const end = start + seconds * 1000;
  assert.equal(remainingDriftSeconds(end, start), seconds);
  assert.equal(remainingDriftSeconds(end, start + 45200), seconds - 45);
  assert.equal(remainingDriftSeconds(end, end), 0);
  assert.equal(remainingDriftSeconds(end, end + 99999), 0);
}

const first = {
  session: 1, start, seconds: 60, starId: 'synthetic', starName: 'synthetic', site: 'demo', north: true,
  mount: '赤道仪', image: '未翻转', side: '架台东侧', axis: PolarAxis.Azimuth, field: DriftField.Meridian,
  alt: 59, az: 180, hourAngle: 0, direction: DriftDirection.Up, strength: 2, adjustments: 0,
  trend: DriftTrend.Unknown,
};
assert.equal(compareDrift(first, { ...first, strength: 1 }), DriftTrend.Smaller);
assert.equal(compareDrift(first, { ...first, strength: 1, direction: DriftDirection.Down }), DriftTrend.Reversed);
assert.equal(compareDrift(first, { ...first, direction: DriftDirection.Left }), DriftTrend.Unknown);
assert.equal(compareDrift(first, { ...first, direction: DriftDirection.Unsteady, strength: -1 }), DriftTrend.Unknown);
assert.equal(compareDrift(first, { ...first, direction: DriftDirection.None, strength: 0 }), DriftTrend.Smaller);
for (const difference of [{ starId: 'wrong-star' }, { session: 2 }, { seconds: 120 },
  { image: '上下翻转' }, { image: '左右镜像' }, { side: '架台西侧' }, { hourAngle: 9 }, { strength: -1 }]) {
  assert.equal(compareDrift(first, { ...first, ...difference }), DriftTrend.Unknown);
}
console.log('Polar: both hemispheres, equator/poles, longitude/UTC, meridian/altitude fields, obstruction, timers and drift trend OK');

// Exercise the record schema and export format with an in-memory filesystem.
// Atomic file persistence is verified separately on the watch.
const files = url(`
  export const entries = new Map();
  export const fileIo = { accessSync: path => entries.has(path) };
  export const readBoundedText = path => entries.get(path);
  export function writeAtomicText(path, text, limit) {
    if (new TextEncoder().encode(text).length > limit) throw Error('too large');
    entries.set(path, text);
  }
`);
const store = await import(url(compile('PolarStore.ets')
  .replace('"@kit.CoreFileKit"', JSON.stringify(files))
  .replace('"./BoundedTextFile"', JSON.stringify(files))
  .replace('"./PolarAlignEngine"', JSON.stringify(engine))));
const { entries } = await import(files);
const rows = Array.from({ length: store.POLAR_LIMIT }, (_, index) => ({
  ...first, start: first.start + index * 180000, starName: '天仓一',
}));
assert.equal(store.POLAR_LIMIT, 96);
assert.deepEqual(store.loadPolarRounds('/test'), []);
store.savePolarRounds('/test', rows);
assert.deepEqual(store.loadPolarRounds('/test'), rows);
store.exportPolarRounds('/test', rows);
const output = entries.get('/test/' + store.POLAR_EXPORT);
assert.equal(output.trimEnd().split('\n').length, rows.length + 1);
assert.match(output, /天仓一.*向上.*明显/);
store.savePolarRounds('/test', []);
assert.deepEqual(store.loadPolarRounds('/test'), []);
entries.set('/test/polar-rounds-v1.json', JSON.stringify({ version: 1, rounds: [null] }));
assert.throws(() => store.loadPolarRounds('/test'));
entries.set('/test/polar-rounds-v1.json', JSON.stringify({ version: 1, rounds: [first, ...rows] }));
assert.throws(() => store.loadPolarRounds('/test'));
console.log('Polar: 96-round schema, UTF-8 export format, clear and corrupt/over-cap rejection OK');
