import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { transformSync } from '../photo-test/node_modules/esbuild/lib/main.js';

const ets = new URL('../../starpilot-watch/entry/src/main/ets/', import.meta.url);
function moduleSource(path) {
  return transformSync(readFileSync(new URL(path, ets), 'utf8'), { loader: 'ts', format: 'esm' }).code;
}
const asModule = (code) => 'data:text/javascript;base64,' + Buffer.from(code).toString('base64');
const astro = asModule(moduleSource('common/Astro.ets'));
const catalog = asModule(moduleSource('data/MeteorShowers.ets'));
const engine = moduleSource('common/MeteorEngine.ets')
  .replace('"./Astro"', JSON.stringify(astro))
  .replace('"../data/MeteorShowers"', JSON.stringify(catalog));
const { METEOR_SHOWERS } = await import(catalog);
const { meteorActive, meteorSeasonYear, meteorPeakDay, meteorNextPeakDay,
  meteorSample, meteorCurve, meteorWindows } = await import(asModule(engine));

const byCode = (code) => METEOR_SHOWERS.find((shower) => shower.code === code);
const quadrantids = byCode('QUA');
const perseids = byCode('PER');
const taurids = byCode('NTA');
const site = (lat, lon = 0, mask = []) => ({ lat, lon, mask });
const HOUR = 3600000;
assert.equal(METEOR_SHOWERS.length, 10);
assert.equal(new Set(METEOR_SHOWERS.map((shower) => shower.code)).size, 10);
assert.equal(meteorActive(quadrantids, Date.UTC(2026, 11, 28) - 1), false);
assert.equal(meteorActive(quadrantids, Date.UTC(2026, 11, 28)), true);
assert.equal(meteorActive(quadrantids, Date.UTC(2027, 0, 12, 23, 59)), true);
assert.equal(meteorActive(quadrantids, Date.UTC(2027, 0, 13)), false);
assert.equal(meteorSeasonYear(quadrantids, Date.UTC(2026, 11, 30)), 2027);
assert.equal(meteorNextPeakDay(quadrantids, Date.UTC(2026, 11, 30)), Date.UTC(2027, 0, 4));
assert.equal(meteorNextPeakDay(quadrantids, Date.UTC(2026, 0, 6)), Date.UTC(2026, 0, 3));
assert.equal(meteorNextPeakDay(quadrantids, Date.UTC(2027, 11, 30)), null);
assert.equal(meteorPeakDay(perseids, 2028), null);
assert.equal(meteorNextPeakDay(taurids, Date.UTC(2026, 11, 11)), Date.UTC(2027, 10, 13));
for (const shower of METEOR_SHOWERS) {
  for (const year of [2026, 2027]) {
    assert.ok(meteorActive(shower, meteorPeakDay(shower, year)));
  }
}

const polarNight = meteorCurve(quadrantids, Date.UTC(2027, 0, 4), site(90));
assert.equal(polarNight.length, 49);
assert.equal(polarNight.at(-1).ms - polarNight[0].ms, 24 * HOUR);
assert.ok(polarNight.every((point) => point.sunAlt < -18 && point.radiant.altDeg > 45 && point.driftApplied));
assert.deepEqual(meteorWindows(polarNight), [{ from: polarNight[0].ms, until: polarNight.at(-1).ms }]);
const south = meteorCurve(quadrantids, Date.UTC(2027, 0, 4), site(-90));
assert.ok(south.every((point) => point.radiant.altDeg < 0 && !point.clearsMask));
assert.deepEqual(meteorWindows(south), []);
const polarDay = meteorCurve(perseids, Date.UTC(2027, 7, 13), site(90));
assert.ok(polarDay.every((point) => point.sunAlt > 0));
assert.deepEqual(meteorWindows(polarDay), []);
const blocked = meteorCurve(quadrantids, Date.UTC(2027, 0, 4), site(90, 0, [70]));
assert.deepEqual(meteorWindows(blocked), []);

const start = Date.UTC(2026, 10, 9, 18);
const curve = meteorCurve(taurids, start, site(40, 116));
assert.ok(curve[0].illumination < 0.015, 'near the 2026-11-09 new moon');
assert.ok(curve.some((p, i) => i > 0 && curve[i - 1].moonAlt <= 0 && p.moonAlt > 0), 'moonrise');
assert.ok(curve.some((p, i) => i > 0 && curve[i - 1].moonAlt >= 0 && p.moonAlt < 0), 'moonset');
assert.ok(curve.every((p) => p.moonSeparation >= 0 && p.moonSeparation <= 180));
const windows = meteorWindows(curve);
assert.ok(windows.length > 0 && windows.every((w) => w.until - w.from >= HOUR / 2));
assert.ok(meteorSample(byCode('URS'), Date.UTC(2026, 11, 24, 1), site(40)).illumination > 0.98);
assert.equal(meteorSample(perseids, start, site(40)).driftApplied, false);
console.log('Meteor: 10 showers, UTC boundaries, year expiry, drift, both hemispheres, polar light, mask and Moon OK');
