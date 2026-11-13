// AR math audit — no sensors, pure projection/orientation checks.
const D2R = Math.PI / 180;
const R2D = 180 / Math.PI;
const W = 466;
const FOV = 60;

function wrap360(x) { const r = x % 360; return r < 0 ? r + 360 : r; }
function shortestDelta(from, to) {
  let d = wrap360(to) - wrap360(from);
  if (d > 180) d -= 360;
  if (d < -180) d += 360;
  return d;
}
function vec(az, alt) {
  const a = alt * D2R, z = az * D2R;
  return { x: Math.cos(a) * Math.sin(z), y: Math.cos(a) * Math.cos(z), z: Math.sin(a) };
}
function dot(a, b) { return a.x * b.x + a.y * b.y + a.z * b.z; }
function cross(a, b) { return { x: a.y * b.z - a.z * b.y, y: a.z * b.x - a.x * b.z, z: a.x * b.y - a.y * b.x }; }
function norm(a) { const l = Math.hypot(a.x, a.y, a.z); return { x: a.x / l, y: a.y / l, z: a.z / l }; }
function angBetween(a, b) { return Math.acos(Math.max(-1, Math.min(1, dot(norm(a), norm(b))))) * R2D; }

// Current ArPage formula (equirectangular, no roll, no behind check).
function projectSimple(cAz, cAlt, az, alt) {
  const dAz = shortestDelta(cAz, az);
  const dAlt = alt - cAlt;
  const scale = W / FOV;
  return { x: W / 2 + dAz * scale, y: W / 2 - dAlt * scale, dAz, dAlt, behind: false };
}

// Reference: pinhole perspective, ENU world, screen y down, roll optional.
function projectPerspective(cAz, cAlt, az, alt, rollDeg = 0) {
  const fwd = vec(cAz, cAlt);
  const up0 = { x: 0, y: 0, z: 1 };
  let right = norm(cross(fwd, up0));
  let up = norm(cross(right, fwd));
  const r = rollDeg * D2R;
  const rr = { x: right.x * Math.cos(r) + up.x * Math.sin(r),
               y: right.y * Math.cos(r) + up.y * Math.sin(r),
               z: right.z * Math.cos(r) + up.z * Math.sin(r) };
  const uu = { x: -right.x * Math.sin(r) + up.x * Math.cos(r),
               y: -right.y * Math.sin(r) + up.y * Math.cos(r),
               z: -right.z * Math.sin(r) + up.z * Math.cos(r) };
  right = rr; up = uu;
  const v = vec(az, alt);
  const xc = dot(v, right), yc = dot(v, up), zc = dot(v, fwd);
  const behind = zc <= 1e-9;
  const f = (W / 2) / Math.tan(FOV / 2 * D2R);
  return { x: W / 2 + f * xc / zc, y: W / 2 - f * yc / zc, behind, xc, yc, zc };
}

function inRect(p) { return p.x >= 0 && p.x <= W && p.y >= 0 && p.y <= W; }
function dist(a, b) { return Math.hypot(a.x - b.x, a.y - b.y); }

console.log('AR MATH AUDIT');
console.log('FOV', FOV, 'canvas', W);
console.log('\n1) Simple vs perspective pixel error (visible reference points)');
for (const cAlt of [0, 30, 60, 80]) {
  let max = 0, sum = 0, n = 0, worst = null;
  for (let da = -40; da <= 40; da += 5) {
    for (let alt = 0; alt <= 85; alt += 5) {
      const az = wrap360(90 + da);
      const ref = projectPerspective(90, cAlt, az, alt);
      if (ref.behind || !inRect(ref)) continue;
      const sim = projectSimple(90, cAlt, az, alt);
      const e = dist(sim, ref);
      sum += e * e; n++;
      if (e > max) { max = e; worst = { da, alt, sim, ref }; }
    }
  }
  console.log(`centerAlt=${String(cAlt).padStart(2)}  n=${String(n).padStart(3)}  RMS=${Math.sqrt(sum / n).toFixed(1)}px  max=${max.toFixed(1)}px`,
    worst ? `worst dAz=${worst.da} alt=${worst.alt}` : '');
}

console.log('\n2) Horizon y offset: simple vs perspective');
for (const cAlt of [0, 10, 30, 45, 60, 80]) {
  const simple = W / 2 + cAlt * (W / FOV);
  const f = (W / 2) / Math.tan(FOV / 2 * D2R);
  const ref = W / 2 + f * Math.tan(cAlt * D2R);
  console.log(`centerAlt=${String(cAlt).padStart(2)}  simple=${simple.toFixed(1)}  perspective=${ref.toFixed(1)}  delta=${(simple - ref).toFixed(1)}px`);
}

console.log('\n3) Corner false-positive of "target in FOV"');
const cornerRef = projectPerspective(0, 0, 30, 30);
const cornerAng = angBetween(vec(0, 0), vec(30, 30));
console.log(`target az=30 alt=30: dAz=30 dAlt=30 => current rule inFOV=${30 <= FOV / 2 && 30 <= FOV / 2}`,
  `but true separation=${cornerAng.toFixed(1)}deg, ref screen=${cornerRef.x.toFixed(0)},${cornerRef.y.toFixed(0)}, behind=${cornerRef.behind}`);

console.log('\n4) Behind-target handling');
const behind = projectPerspective(0, 0, 180, 0);
const behindSimple = projectSimple(0, 0, 180, 0);
console.log(`target az=180 alt=0: perspective behind=${behind.behind} zc=${behind.zc.toFixed(3)};`,
  `simple x=${behindSimple.x.toFixed(0)} (far off-screen, no behind flag)`);

console.log('\n5) Roll sensitivity');
for (const roll of [0, 15, 30, 45, 90]) {
  const p = projectPerspective(0, 0, 0, 30, roll);
  console.log(`roll=${String(roll).padStart(2)}  target az=0 alt=30 -> screen ${p.x.toFixed(0)},${p.y.toFixed(0)}  behind=${p.behind}`);
}

console.log('\n6) Quaternion altitude monotonicity (world ENU, q = rotation about +X)');
function qAxis(axis, deg) {
  const h = deg * D2R / 2;
  return { x: axis.x * Math.sin(h), y: axis.y * Math.sin(h), z: axis.z * Math.sin(h), w: Math.cos(h) };
}
function rotateByQuat(q, v) {
  const qv = { x: q.x, y: q.y, z: q.z };
  const t = cross(qv, v);
  const t2 = cross(qv, t);
  return { x: v.x + 2 * (q.w * t.x + t2.x), y: v.y + 2 * (q.w * t.y + t2.y), z: v.z + 2 * (q.w * t.z + t2.z) };
}
function qConj(q) { return { x: -q.x, y: -q.y, z: -q.z, w: q.w }; }
for (const ang of [0, 15, 30, 45, 60, 75, 90]) {
  const q = qAxis({ x: 1, y: 0, z: 0 }, ang);
  const w = rotateByQuat(qConj(q), { x: 0, y: 1, z: 0 });
  const alt = Math.asin(Math.max(-1, Math.min(1, w.z))) * R2D;
  const qNeg = { x: -q.x, y: -q.y, z: -q.z, w: -q.w };
  const altNeg = rotateByQuat(qConj(qNeg), { x: 0, y: 1, z: 0 });
  console.log(`tilt=${String(ang).padStart(2)}deg  +Y alt=${alt.toFixed(1)}  q/-q same=${Math.abs(alt - Math.asin(Math.max(-1, Math.min(1, altNeg.z))) * R2D) < 1e-9}`);
}

console.log('\n7) Perspective project/unproject consistency');
function unprojectPerspective(cAz, cAlt, p, rollDeg = 0) {
  const fwd = vec(cAz, cAlt);
  let right = norm(cross(fwd, { x: 0, y: 0, z: 1 }));
  let up = norm(cross(right, fwd));
  const r = rollDeg * D2R;
  const rr = { x: right.x * Math.cos(r) + up.x * Math.sin(r), y: right.y * Math.cos(r) + up.y * Math.sin(r), z: right.z * Math.cos(r) + up.z * Math.sin(r) };
  const uu = { x: -right.x * Math.sin(r) + up.x * Math.cos(r), y: -right.y * Math.sin(r) + up.y * Math.cos(r), z: -right.z * Math.sin(r) + up.z * Math.cos(r) };
  right = rr; up = uu;
  const f = (W / 2) / Math.tan(FOV / 2 * D2R);
  const xc = (p.x - W / 2) / f, yc = -(p.y - W / 2) / f, zc = 1;
  const v = { x: right.x * xc + up.x * yc + fwd.x * zc,
              y: right.y * xc + up.y * yc + fwd.y * zc,
              z: right.z * xc + up.z * yc + fwd.z * zc };
  return { az: wrap360(Math.atan2(v.x, v.y) * R2D), alt: Math.asin(v.z / Math.hypot(v.x, v.y, v.z)) * R2D };
}
for (const [az, alt] of [[0, 0], [30, 20], [90, 40], [180, 0], [270, -10]]) {
  const p = projectPerspective(10, 20, az, alt);
  if (p.behind) { console.log(`az=${az} alt=${alt} behind`); continue; }
  const u = unprojectPerspective(10, 20, p);
  console.log(`az=${String(az).padStart(3)} alt=${String(alt).padStart(3)} -> roundtrip az=${u.az.toFixed(2)} alt=${u.alt.toFixed(2)} err=${angBetween(vec(az, alt), vec(u.az, u.alt)).toFixed(4)}deg`);
}

console.log('\n8) Five virtual targets at center az=0 alt=0');
for (const [name, az, alt] of [['N',0,0],['E',90,0],['S',180,0],['W',270,0],['Zenith',0,90]]) {
  const s = projectSimple(0, 0, az, alt);
  const p = projectPerspective(0, 0, az, alt);
  console.log(`${name.padEnd(6)} simple=(${s.x.toFixed(0)},${s.y.toFixed(0)}) dAz=${s.dAz.toFixed(0)} dAlt=${s.dAlt.toFixed(0)} | perspective=(${p.x.toFixed(0)},${p.y.toFixed(0)}) behind=${p.behind} zc=${p.zc.toFixed(2)}`);
}

console.log('\n9) Camera basis orthogonality (perspective reference)');
function basis(cAz, cAlt, roll) {
  const fwd = vec(cAz, cAlt);
  let right = norm(cross(fwd, { x: 0, y: 0, z: 1 }));
  let up = norm(cross(right, fwd));
  const r = roll * D2R;
  const rr = { x: right.x * Math.cos(r) + up.x * Math.sin(r), y: right.y * Math.cos(r) + up.y * Math.sin(r), z: right.z * Math.cos(r) + up.z * Math.sin(r) };
  const uu = { x: -right.x * Math.sin(r) + up.x * Math.cos(r), y: -right.y * Math.sin(r) + up.y * Math.cos(r), z: -right.z * Math.sin(r) + up.z * Math.cos(r) };
  return { fwd, right: rr, up: uu };
}
for (const [az, alt, roll] of [[0,0,0],[45,30,15],[200,60,45]]) {
  const b = basis(az, alt, roll);
  console.log(`az=${az} alt=${alt} roll=${roll}: |fwd|=${Math.hypot(b.fwd.x,b.fwd.y,b.fwd.z).toFixed(6)} fwd·right=${dot(b.fwd,b.right).toExponential(2)} fwd·up=${dot(b.fwd,b.up).toExponential(2)} right·up=${dot(b.right,b.up).toExponential(2)}`);
}
