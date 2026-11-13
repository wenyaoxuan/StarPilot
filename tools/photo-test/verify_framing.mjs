import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { transformSync } from 'esbuild';

const file = new URL('../../starpilot-watch/entry/src/main/ets/common/FramingEngine.ets', import.meta.url);
const { code } = transformSync(readFileSync(file, 'utf8'), { loader: 'ts', format: 'esm' });
const { FramingFrame, angularRadiusOnPlane, offsetFrameCenter } =
  await import('data:text/javascript;base64,' + Buffer.from(code).toString('base64'));

function near(actual, expected, tolerance = 1e-9) {
  assert.ok(Math.abs(actual - expected) < tolerance, `expected ${expected}, got ${actual}`);
}

const center = { raHours: 23.99, decDeg: 0 };
for (const [focal, width, height] of [[85, 23.72, 15.94], [135, 15.06, 10.07], [200, 10.20, 6.81]]) {
  const landscape = new FramingFrame(center, 35.7, 23.8, focal, 0);
  const portrait = new FramingFrame(center, 23.8, 35.7, focal, 0);
  near(landscape.widthDeg, width, 0.01);
  near(landscape.heightDeg, height, 0.01);
  near(portrait.widthDeg, landscape.heightDeg);
  near(portrait.heightDeg, landscape.widthDeg);
}
const frame = new FramingFrame(center, 36, 18, 100.5, 0);
near(frame.widthDeg, 20.308, 0.01);
assert.deepEqual(frame.project(center), { x: 0, y: 0, inside: true });
assert.ok(frame.project({ raHours: 0.01, decDeg: 0 }).x > 0);
assert.ok(frame.project({ raHours: 23.97, decDeg: 0 }).x < 0);
assert.equal(frame.project({ raHours: 11.99, decDeg: 0 }), null);
assert.equal(frame.project({ raHours: 5.99, decDeg: 0 }), null);
assert.ok(frame.project(frame.move(1, 0)).inside);
assert.ok(!frame.project(frame.move(1.01, 0)).inside);

const high = { raHours: 23.99, decDeg: 89.98 };
const polar = new FramingFrame(high, 35.7, 23.8, 200, 105);
const moved = polar.move(0.55, -0.8);
assert.ok(moved.raHours >= 0 && moved.raHours < 24);
assert.ok(moved.decDeg <= 90);
const projected = polar.project(moved);
assert.ok(projected.inside);
near(projected.x, 0.55);
near(projected.y, -0.8);

const rotated = new FramingFrame(center, 36, 24, 100, 90);
const radius = angularRadiusOnPlane(120);
const east = offsetFrameCenter(center, radius, 0);
near(east.raHours, (center.raHours + 1 / 15) % 24);
near(rotated.project(east).x, 0);
near(rotated.project(east).y, radius / 0.12);
console.log('Framing: focal lengths, aspect ratio, RA wrap, poles, clipping, rotation and angular extent OK');
