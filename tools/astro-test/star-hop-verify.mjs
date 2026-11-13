import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { transformSync } from '../photo-test/node_modules/esbuild/lib/main.js';

const ets = new URL('../../starpilot-watch/entry/src/main/ets/', import.meta.url);
function compile(name, imports = {}) {
  let { code } = transformSync(readFileSync(new URL(name + '.ets', ets), 'utf8'), { loader: 'ts', format: 'esm' });
  for (const [dependency, url] of Object.entries(imports)) {
    code = code.replace(JSON.stringify(dependency), JSON.stringify(url));
  }
  return 'data:text/javascript;base64,' + Buffer.from(code).toString('base64');
}

const astro = compile('common/Astro');
const engine = compile('common/StarHopEngine', { './Astro': astro });
const messier = compile('data/Messier');
const constellations = compile('data/Constellations');
const supplement = compile('data/StarHopSupplement');
const targets = compile('data/TargetCatalog', { './Constellations': constellations, './Messier': messier });
const catalog = compile('data/StarHopCatalog', {
  './Messier': messier, './StarHopSupplement': supplement, './TargetCatalog': targets,
});
const { jdFromUnixMs, lstDeg, norm360, precessFromJ2000 } = await import(astro);
const { HOP_MAX_STEP, HopLimit, defaultHopMagnitude, hopGeometry, makeHopField, planStarHop } = await import(engine);
const { asHopStar, hopStarMatches, referenceHopStars } = await import(catalog);
const { EXTRA_HOP_STARS } = await import(supplement);
const { findStaticTarget } = await import(targets);

function near(actual, expected, tolerance = 1e-9) {
  assert.ok(Math.abs(actual - expected) < tolerance, `expected ${expected}, got ${actual}`);
}
const cross = hopGeometry({ raHours: 23.99, decDeg: 0 }, { raHours: 0.01, decDeg: 0 });
near(cross.distance, 0.3);
near(cross.angle, 90);
const polar = hopGeometry({ raHours: 23.9, decDeg: 89.9 }, { raHours: 0.1, decDeg: 89.8 });
assert.ok(polar.distance < 0.11 && polar.angle > 170 && polar.angle < 180);
assert.equal(hopGeometry({ raHours: 0, decDeg: 90 }, { raHours: 0, decDeg: 89 }).angle, null);
const opposite = hopGeometry({ raHours: 0, decDeg: 0 }, { raHours: 12, decDeg: 0 });
near(opposite.distance, 180);
assert.equal(opposite.angle, null);

const stars = referenceHopStars();
assert.equal(EXTRA_HOP_STARS.length, 79);
assert.equal(stars.length, new Set(stars.map((s) => s.id)).size);
assert.ok(stars.length >= 700 && stars.every((s) => s.mag <= 6 && Math.abs(s.decDeg) <= 90));
assert.ok(EXTRA_HOP_STARS.every((s) => s.mag <= 4 && s.constellation.length === 3));
assert.ok(hopStarMatches(stars.find((s) => s.id === 'HIP677'), 'alpheratz'));
assert.ok(hopStarMatches(stars.find((s) => s.id === 'HIP677'), 'and'));
assert.equal(defaultHopMagnitude(9), 2.5);
assert.equal(defaultHopMagnitude(1), 6);

const beijing = { lat: 39.9042, lon: 116.4074, horizon: [], bortle: 9 };
const base = Date.UTC(2026, 10, 9);
function meridian(star, site, offset = 0) {
  const jd = jdFromUnixMs(base);
  const eq = precessFromJ2000(star.raHours, star.decDeg, jd);
  return base + norm360(eq.raHours * 15 + offset - lstDeg(jd, site.lon)) / 360 * 86164090.5;
}

for (const [id, start] of [
  ['M31', 'HIP677'], ['M42', 'HIP27989'], ['M45', 'HIP21421'],
  ['M13', 'HIP91262'], ['M57', 'HIP91262'], ['M27', 'HIP97649'],
]) {
  const target = asHopStar(findStaticTarget(id));
  const time = meridian(target, beijing);
  const field = makeHopField(target, stars, beijing, 5, time);
  assert.equal(field.limit, HopLimit.Ready);
  const route = planStarHop(field, start);
  assert.equal(route[0]?.star.id, start, id + ' starting star');
  assert.equal(route.at(-1)?.star.id, id);
  assert.ok(route.slice(1).every((point, i) => hopGeometry(route[i].star, point.star).distance <= HOP_MAX_STEP + 1e-8));
  assert.ok(route.slice(0, -1).every((point) => point.star.mag <= 5 && point.alt >= 10));
  console.log(id + ': ' + route.map((point) => point.star.id).join(' → '));
}

const target = asHopStar(findStaticTarget('M31'));
const time = meridian(target, beijing);
const urban = makeHopField(target, stars, beijing, defaultHopMagnitude(9), time);
const dark = makeHopField(target, stars, { ...beijing, bortle: 1 }, defaultHopMagnitude(1), time);
assert.ok(dark.candidates.length > urban.candidates.length);
assert.ok(urban.candidates.every((p) => p.star.mag <= 2.5));
assert.equal(makeHopField(target, stars, { ...beijing, horizon: [90] }, 5, time).limit, HopLimit.TargetObstructed);
assert.equal(makeHopField(target, [], beijing, 5, time).limit, HopLimit.StarsTooFaint);
assert.equal(makeHopField(target, stars, { ...beijing, lat: 0 }, 5,
  meridian(target, { ...beijing, lat: 0 }, 180)).limit, HopLimit.TargetBelow);
assert.equal(makeHopField(target, stars, { ...beijing, lat: 0 }, 5,
  meridian(target, { ...beijing, lat: 0 }, 87)).limit, HopLimit.TargetLow);
const far = urban.candidates.find((p) => p.distanceToTarget > 20);
const disconnected = makeHopField(target, [far.star], beijing, 2.5, time);
assert.equal(disconnected.limit, HopLimit.Ready);
assert.deepEqual(planStarHop(disconnected, far.star.id), []);
assert.deepEqual(planStarHop(urban, 'not-in-catalog'), []);
const blockedStart = makeHopField(target, [far.star], { ...beijing, horizon: Array(36).fill(0).map((_, i) =>
  Math.abs(i * 10 - far.az) < 20 && Math.abs(i * 10 - urban.target.az) > 15 ? 90 : 0) }, 2.5, time);
assert.equal(blockedStart.limit, HopLimit.StarsObstructed);
console.log(`${stars.length} reference stars. RA wrap, pole, horizon, faintness, disconnected graph and Bortle OK.`);
