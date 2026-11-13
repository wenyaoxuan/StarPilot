import { AzAlt, Vec3, rotateByQuat, wrap360 } from './Fusion';

const RAD2DEG: number = 180 / Math.PI;

export interface CameraPose {
  forward: Vec3;
  up: Vec3;
  right: Vec3;
}

function normalize(v: Vec3): Vec3 {
  const len: number = Math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z);
  if (len < 1e-9) {
    return new Vec3(0, 0, 0);
  }
  return new Vec3(v.x / len, v.y / len, v.z / len);
}

function cross(a: Vec3, b: Vec3): Vec3 {
  return new Vec3(
    a.y * b.z - a.z * b.y,
    a.z * b.x - a.x * b.z,
    a.x * b.y - a.y * b.x
  );
}

/**
 * F2/F5 camera pose:
 *   forward = device +Z (back of watch)
 *   upRaw   = device +Y (12 o'clock)
 *   right   = normalize(forward × upRaw)
 *   up      = normalize(right × forward)
 *
 * World is ENU (+X east, +Y north, +Z up). The quaternion is the Watch 5
 * WORLD -> DEVICE rotation, so the conjugate maps device axes to world.
 *
 * The sensor's physical +X is mirrored on this hardware (the old compass code
 * used atan2(-x, y) for the 3 o'clock bearing). We therefore do not use raw
 * device +X as screen right; the orthonormal right vector is derived from
 * forward × up, which is physically right-handed in ENU.
 *
 * F5 follow-up: ROT +Z is the back normal on this watch; -Z is the screen
 * normal. Screen-up field test: ACC reads (0, 0.96, 9.85) while ROT +Z maps
 * to DOWN after the X mirror, so the ROT frame's Z is opposite the ACC Z.
 * The camera forward therefore uses ROT +Z.
 */
export function cameraPoseFromQuat(qx: number, qy: number, qz: number, qw: number): CameraPose {
  const fwdRaw: Vec3 = rotateByQuat(-qx, -qy, -qz, qw, new Vec3(0, 0, 1));
  const upRaw: Vec3 = rotateByQuat(-qx, -qy, -qz, qw, new Vec3(0, 1, 0));
  // Watch 5 ROT world X is mirrored relative to ORIENTATION/astronomy ENU.
  // F5 field test: +Y raw atan2(x,y)=86.9 deg, ORIENTATION alpha=273.4 deg;
  // flipping world X gives 273.1 deg, matching ORIENTATION. Do this once here.
  const forward: Vec3 = normalize(new Vec3(-fwdRaw.x, fwdRaw.y, fwdRaw.z));
  const up0: Vec3 = normalize(new Vec3(-upRaw.x, upRaw.y, upRaw.z));
  const right: Vec3 = normalize(cross(forward, up0));
  const up: Vec3 = normalize(cross(right, forward));
  return { forward, up, right };
}

/**
 * 12 o'clock pointing mode: camera forward is device +Y (the top edge).
 *
 * The screen "up" is gravity-leveled (world +Z projected onto the plane
 * perpendicular to forward), so wrist roll does not rotate the horizon.
 * This is the natural way to point a watch: hold the screen toward yourself
 * and aim the 12 o'clock edge at the target, like a sight.
 */
export function cameraPoseFromQuatTwelve(qx: number, qy: number, qz: number, qw: number): CameraPose {
  const fwdRaw: Vec3 = rotateByQuat(-qx, -qy, -qz, qw, new Vec3(0, 1, 0));
  const forward: Vec3 = normalize(new Vec3(-fwdRaw.x, fwdRaw.y, fwdRaw.z));
  const dotUp: number = forward.z;
  let up: Vec3 = normalize(new Vec3(-forward.x * dotUp, -forward.y * dotUp, 1 - forward.z * dotUp));
  if (Math.sqrt(up.x * up.x + up.y * up.y + up.z * up.z) < 0.1) {
    // Forward is near the zenith; fall back to the device screen normal
    // projected onto the camera plane.
    const upRaw: Vec3 = rotateByQuat(-qx, -qy, -qz, qw, new Vec3(0, 0, 1));
    const upM: Vec3 = normalize(new Vec3(-upRaw.x, upRaw.y, upRaw.z));
    const d: number = upM.x * forward.x + upM.y * forward.y + upM.z * forward.z;
    up = normalize(new Vec3(upM.x - forward.x * d, upM.y - forward.y * d, upM.z - forward.z * d));
  }
  const right: Vec3 = normalize(cross(forward, up));
  const upOrtho: Vec3 = normalize(cross(right, forward));
  return { forward, up: upOrtho, right };
}

/**
 * 12 o'clock mode from physical references:
 *   azimuth = ORIENTATION alpha (12 o'clock heading)
 *   altitude = accelerometer Y / |ACC| (vertical component of device +Y)
 *
 * This avoids the ROT q / -q ambiguity for the pointing axis. If ORI or ACC
 * is stale/invalid, fall back to the quaternion construction above.
 */
export function cameraPoseFromTwelveReference(alphaDeg: number, ax: number, ay: number, az: number,
                                              oriFresh: boolean, qx: number, qy: number,
                                              qz: number, qw: number): CameraPose {
  const fallback: CameraPose = cameraPoseFromQuatTwelve(qx, qy, qz, qw);
  const tilt: number | null = twelveTiltFromAcceleration(ax, ay, az);
  if (!oriFresh || tilt === null) {
    return fallback;
  }
  return cameraPoseFromTwelveAngles(alphaDeg, tilt, fallback.up);
}

export function twelveTiltFromAcceleration(ax: number, ay: number, az: number): number | null {
  const alen: number = Math.sqrt(ax * ax + ay * ay + az * az);
  if (!Number.isFinite(alen) || alen < 7 || alen > 12) {
    return null;
  }
  return Math.asin(Math.max(-1, Math.min(1, ay / alen))) * RAD2DEG;
}

export function cameraPoseFromTwelveAngles(alphaDeg: number, altDeg: number, fallbackUp: Vec3): CameraPose {
  const tilt: number = altDeg / RAD2DEG;
  const tz: number = Math.sin(tilt);
  const h: number = Math.cos(tilt);
  const a: number = alphaDeg * Math.PI / 180;
  const forward: Vec3 = normalize(new Vec3(Math.sin(a) * h, Math.cos(a) * h, tz));
  const up: Vec3 = Math.abs(h) < 1e-6 ? fallbackUp :
    new Vec3(-Math.sin(a) * tz, -Math.cos(a) * tz, h);
  const right: Vec3 = normalize(cross(forward, up));
  const upOrtho: Vec3 = normalize(cross(right, forward));
  return { forward, up: upOrtho, right };
}

/** ENU vector -> true-north azimuth (0=N, clockwise) and geometric altitude. */
export function vectorAzAlt(v: Vec3): AzAlt {
  const len: number = Math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z);
  if (len < 1e-9) {
    return { az: 0, alt: 0 };
  }
  const x: number = v.x / len;
  const y: number = v.y / len;
  const z: number = v.z / len;
  return {
    az: wrap360(Math.atan2(x, y) * RAD2DEG),
    alt: Math.asin(Math.max(-1, Math.min(1, z))) * RAD2DEG
  };
}

export function axisAngleDeg(a: Vec3, b: Vec3): number {
  const la: number = Math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z);
  const lb: number = Math.sqrt(b.x * b.x + b.y * b.y + b.z * b.z);
  if (la < 1e-9 || lb < 1e-9) {
    return 0;
  }
  const dot: number = (a.x * b.x + a.y * b.y + a.z * b.z) / (la * lb);
  return Math.acos(Math.max(-1, Math.min(1, dot))) * RAD2DEG;
}

/** Rotate the complete ENU pose by an observed, session-only azimuth correction. */
export function rotatePoseHeading(pose: CameraPose, angleDeg: number): CameraPose {
  const angle: number = angleDeg * Math.PI / 180;
  const sine: number = Math.sin(angle);
  const cosine: number = Math.cos(angle);
  const rotate = (v: Vec3): Vec3 =>
    new Vec3(v.x * cosine + v.y * sine, v.y * cosine - v.x * sine, v.z);
  return { forward: rotate(pose.forward), up: rotate(pose.up), right: rotate(pose.right) };
}
