// F2 camera pose tests — constructed device->world rotations, no sensors.
const D2R = Math.PI / 180;
const R2D = 180 / Math.PI;

function cross(a, b) { return { x: a.y * b.z - a.z * b.y, y: a.z * b.x - a.x * b.z, z: a.x * b.y - a.y * b.x }; }
function dot(a, b) { return a.x * b.x + a.y * b.y + a.z * b.z; }
function norm(a) { const l = Math.hypot(a.x, a.y, a.z); return { x: a.x / l, y: a.y / l, z: a.z / l }; }
function ang(a, b) { return Math.acos(Math.max(-1, Math.min(1, dot(norm(a), norm(b))))) * R2D; }
function wrap360(x) { const r = x % 360; return r < 0 ? r + 360 : r; }
function azAlt(v) {
  const l = Math.hypot(v.x, v.y, v.z);
  return { az: wrap360(Math.atan2(v.x / l, v.y / l) * R2D), alt: Math.asin(Math.max(-1, Math.min(1, v.z / l))) * R2D };
}

// Quaternion for a 3x3 device->world rotation (columns = device axes in ENU).
function quatFromMatrix(m) {
  // m[r][c], row-major
  const tr = m[0][0] + m[1][1] + m[2][2];
  let x, y, z, w;
  if (tr > 0) {
    const s = Math.sqrt(tr + 1) * 2;
    w = s / 4; x = (m[2][1] - m[1][2]) / s; y = (m[0][2] - m[2][0]) / s; z = (m[1][0] - m[0][1]) / s;
  } else if (m[0][0] > m[1][1] && m[0][0] > m[2][2]) {
    const s = Math.sqrt(1 + m[0][0] - m[1][1] - m[2][2]) * 2;
    w = (m[2][1] - m[1][2]) / s; x = s / 4; y = (m[0][1] + m[1][0]) / s; z = (m[0][2] + m[2][0]) / s;
  } else if (m[1][1] > m[2][2]) {
    const s = Math.sqrt(1 + m[1][1] - m[0][0] - m[2][2]) * 2;
    w = (m[0][2] - m[2][0]) / s; x = (m[0][1] + m[1][0]) / s; y = s / 4; z = (m[1][2] + m[2][1]) / s;
  } else {
    const s = Math.sqrt(1 + m[2][2] - m[0][0] - m[1][1]) * 2;
    w = (m[1][0] - m[0][1]) / s; x = (m[0][2] + m[2][0]) / s; y = (m[1][2] + m[2][1]) / s; z = s / 4;
  }
  return { x, y, z, w };
}
function conj(q) { return { x: -q.x, y: -q.y, z: -q.z, w: q.w }; }
function rot(q, v) {
  const qv = { x: q.x, y: q.y, z: q.z };
  const t = cross(qv, v); const t2 = cross(qv, t);
  return { x: v.x + 2 * (q.w * t.x + t2.x), y: v.y + 2 * (q.w * t.y + t2.y), z: v.z + 2 * (q.w * t.z + t2.z) };
}

// Camera pose exactly mirrors CameraPose.ets, including the F5 world-X mirror.
function cameraPose(qWorldToDev) {
  const c = conj(qWorldToDev);
  const fwdRaw = norm(rot(c, { x: 0, y: 0, z: 1 }));
  const upRaw = norm(rot(c, { x: 0, y: 1, z: 0 }));
  const fwd = norm({ x: -fwdRaw.x, y: fwdRaw.y, z: fwdRaw.z });
  const up0 = norm({ x: -upRaw.x, y: upRaw.y, z: upRaw.z });
  const right = norm(cross(fwd, up0));
  const up = norm(cross(right, fwd));
  return { fwd, up, right };
}

function mirrorX(v) { return { x: -v.x, y: v.y, z: v.z }; }

// Device->world basis from three column vectors.
function matFromCols(x, y, z) {
  return [[x.x, y.x, z.x], [x.y, y.y, z.y], [x.z, y.z, z.z]];
}

const poses = [
  { name: 'flat, screen up, 12N', x: { x: 1, y: 0, z: 0 }, y: { x: 0, y: 1, z: 0 }, z: { x: 0, y: 0, z: -1 },
    want: { az: 0, alt: -90 } },
  { name: 'vertical, back N horizon', x: { x: 1, y: 0, z: 0 }, y: { x: 0, y: 0, z: 1 }, z: { x: 0, y: 1, z: 0 },
    want: { az: 0, alt: 0 } },
  { name: 'vertical, back E horizon', x: { x: 0, y: -1, z: 0 }, y: { x: 0, y: 0, z: 1 }, z: { x: 1, y: 0, z: 0 },
    want: { az: 90, alt: 0 } },
  { name: 'back zenith, screen down', x: { x: -1, y: 0, z: 0 }, y: { x: 0, y: 1, z: 0 }, z: { x: 0, y: 0, z: 1 },
    want: { az: 0, alt: 90 } },
  // Asymmetric pose so the world-X mirror actually changes both raw vectors.
  { name: 'back NE, alt 20', x: { x: 0.70710678, y: -0.70710678, z: 0 },
    y: { x: -0.24184476, y: -0.24184476, z: 0.93969262 },
    z: { x: 0.66446302, y: 0.66446302, z: 0.34202014 },
    want: { az: 45, alt: 20 } }
];

console.log('F5 CAMERA POSE TESTS (physical pose -> world-X-mirrored ROT input)');
for (const p of poses) {
  // Physical camera basis: forward = device +Z (back), up = device Y.
  const fwdPhys = { x: p.z.x, y: p.z.y, z: p.z.z };
  const upPhys = { x: p.y.x, y: p.y.y, z: p.y.z };
  // Watch 5 ROT reports world X mirrored. Feed the function that mirrored raw
  // pair; the F5 x-flip must recover the physical pose.
  const fwdRaw = mirrorX(fwdPhys);
  const upRaw = mirrorX(upPhys);
  // Proper rotation columns corresponding to those raw camera vectors.
  const sensorX = cross(upRaw, fwdRaw);
  const sensorY = upRaw;
  const sensorZ = { x: fwdRaw.x, y: fwdRaw.y, z: fwdRaw.z };
  const m = matFromCols(sensorX, sensorY, sensorZ);
  const qDevToWorld = quatFromMatrix(m);
  const qWorldToDev = conj(qDevToWorld); // cameraPose expects WORLD->DEVICE
  const pose = cameraPose(qWorldToDev);
  const view = azAlt(pose.fwd);
  const ortho = Math.max(Math.abs(dot(pose.fwd, pose.up)), Math.abs(dot(pose.fwd, pose.right)), Math.abs(dot(pose.up, pose.right)));
  const rightErr = ang(p.x, pose.right);
  console.log(`${p.name.padEnd(26)} fwd=${view.az.toFixed(1)}/${view.alt.toFixed(1)} want=${p.want.az}/${p.want.alt}`,
    `orthoErr=${ortho.toExponential(2)}`, `rightErr=${rightErr.toFixed(2)}deg`);
}

console.log('\nKnown vector az/alt:');
for (const v of [{x:0,y:1,z:0},{x:1,y:0,z:0},{x:0,y:-1,z:0},{x:-1,y:0,z:0},{x:0,y:0,z:1}]) {
  const a = azAlt(v); console.log(v, '->', a.az.toFixed(1), a.alt.toFixed(1));
}

console.log('\nq/-q equivalence:');
const q = { x: 0.2, y: 0.3, z: 0.4, w: 0.84261498 };
const a = cameraPose(q), b = cameraPose({ x: -q.x, y: -q.y, z: -q.z, w: -q.w });
console.log('forward angle', ang(a.fwd, b.fwd).toExponential(2), 'up angle', ang(a.up, b.up).toExponential(2));
