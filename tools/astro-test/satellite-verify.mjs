import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { transformSync } from '../photo-test/node_modules/esbuild/lib/main.js';

const ets = new URL('../../starpilot-watch/entry/src/main/ets/common/', import.meta.url);
function compile(name, imports = {}) {
  let { code } = transformSync(readFileSync(new URL(name + '.ets', ets), 'utf8'), { loader: 'ts', format: 'esm' });
  for (const [dependency, url] of Object.entries(imports)) {
    code = code.replace(JSON.stringify('./' + dependency), JSON.stringify(url));
  }
  return 'data:text/javascript;base64,' + Buffer.from(code).toString('base64');
}
const sgp4Url = compile('Sgp4NearEarth');
const orbitUrl = compile('SatelliteOrbit', { Sgp4NearEarth: sgp4Url });
const astroUrl = compile('Astro');
const { jdFromUnixMs, sunEquatorial } = await import(astroUrl);
const { NearEarthSgp4 } = await import(sgp4Url);
const { IssFreshness, parseIssOmm, issFreshness } = await import(orbitUrl);
const { nextIssPass, satelliteLook, sunlit } = await import(compile('SatelliteEngine', {
  Astro: astroUrl, Sgp4NearEarth: sgp4Url, SatelliteOrbit: orbitUrl,
}));
const vector = (v) => [v.x, v.y, v.z];
const delta = (v, ref) => Math.hypot(...vector(v).map((x, i) => x - ref[i]));
const HOUR = 3600000;
const known = new NearEarthSgp4({
  epochMs: 0, meanMotion: 10.82419157, eccentricity: .1859667, inclination: 34.2682,
  node: 348.7242, perigee: 331.7664, anomaly: 19.3264, bstar: .000028098,
});
for (const [minutes, p, v] of [
  [0, [7022.46529266, -1400.08296755, .03995155], [1.893841015, 6.405893759, 4.534807250]],
  [360, [-7154.03120202, -3783.17682504, -3536.19412294], [4.741887409, -4.151817765, -2.093935425]],
]) {
  const state = known.at(minutes * 60000);
  assert.ok(delta(state.position, p) < 0.000001);
  assert.ok(delta(state.velocity, v) < 0.00000001);
}
const day = jdFromUnixMs(Date.UTC(2026, 10, 9));
const sun = sunEquatorial(day);
const ra = sun.raHours * Math.PI / 12;
const dec = sun.decDeg * Math.PI / 180;
const sunward = { x: 6800 * Math.cos(dec) * Math.cos(ra), y: 6800 * Math.cos(dec) * Math.sin(ra),
  z: 6800 * Math.sin(dec) };
assert.equal(sunlit(sunward, day), true);
assert.equal(sunlit({ x: -sunward.x, y: -sunward.y, z: -sunward.z }, day), false);
assert.throws(() => parseIssOmm('[]'));
assert.throws(() => parseIssOmm('garbage'));
assert.throws(() => parseIssOmm(' '.repeat(4097)));
console.log('Vallado 00005 TEME positions and velocities, invalid input and Earth shadow OK');

if (process.argv.length === 4) {
  const input = readFileSync(process.argv[2], 'utf8').replace(/^\uFEFF/, '');
  const orbit = parseIssOmm(input);
  const record = JSON.parse(input);
  const row = Array.isArray(record) ? record[0] : record;
  for (const edit of [{ NORAD_CAT_ID: 12345 }, { REF_FRAME: 'GCRF' }, { TIME_SYSTEM: 'TAI' },
    { MEAN_MOTION: '15.5' }, { EPOCH: '2026-02-31T00:00:00Z' }, { ECCENTRICITY: 0.1 }]) {
    assert.throws(() => parseIssOmm(JSON.stringify({ ...row, ...edit })));
  }
  const model = new NearEarthSgp4(orbit);
  assert.equal(issFreshness(orbit, orbit.epochMs - 3 * HOUR), IssFreshness.Future);
  assert.equal(issFreshness(orbit, orbit.epochMs + HOUR), IssFreshness.Recent);
  assert.equal(issFreshness(orbit, orbit.epochMs + 24 * HOUR), IssFreshness.Aging);
  assert.equal(issFreshness(orbit, orbit.epochMs + 48 * HOUR), IssFreshness.Expired);
  const ref = JSON.parse(readFileSync(process.argv[3], 'utf8').replace(/^\uFEFF/, ''));
  const site = ([lat, lon, km]) => ({ lat, lon, altitudeM: km * 1000 });
  let positionError = 0, velocityError = 0, lookError = 0, passError = 0;
  for (const point of ref.vectors) {
    const t = orbit.epochMs + point.minutes * 60000;
    const state = model.at(t);
    positionError = Math.max(positionError, delta(state.position, point.position));
    velocityError = Math.max(velocityError, delta(state.velocity, point.velocity));
    const actual = satelliteLook(state.position, t, site(ref.vectorSite));
    const azError = ((actual.az - point.look[1] + 540) % 360) - 180;
    lookError = Math.max(lookError, Math.abs(actual.alt - point.look[0]), Math.abs(azError));
    assert.ok(Math.abs(actual.rangeKm - point.look[2]) < 0.001);
  }
  assert.ok(positionError < 0.000001 && velocityError < 0.00000001 && lookError < 0.00001);
  let crossedMidnight = false;
  for (const fixture of ref.cases) {
    const siteInfo = site(fixture.site);
    const pass = nextIssPass(model, fixture.start * 1000, siteInfo, fixture.threshold);
    if (fixture.expected === null) {
      assert.equal(pass, null);
      continue;
    }
    for (const key of ['aos', 'peak', 'los']) {
      passError = Math.max(passError, Math.abs(pass[key] / 1000 - fixture.expected[key]));
    }
    assert.ok(Math.abs(pass.maxAlt - fixture.expected.maxAlt) < 0.25);
    crossedMidnight ||= new Date(pass.aos).getUTCDate() !== new Date(pass.los).getUTCDate();
    const ongoing = nextIssPass(model, pass.peak, siteInfo, fixture.threshold);
    assert.ok(ongoing.aos < pass.peak && ongoing.los > pass.peak);
    const grazing = nextIssPass(model, fixture.start * 1000, siteInfo, pass.maxAlt - 0.001);
    assert.ok(grazing && grazing.los - grazing.aos < 20000);
    assert.ok(Math.abs(grazing.peak - pass.peak) < 500);
  }
  assert.ok(crossedMidnight && passError < 1.5);
  console.log(`ISS vs Python sgp4: max position ${positionError} km, velocity ${velocityError} km/s, look ${lookError} deg, pass ${passError} s`);
}
