/**
 * Fusion.ets — S0 attitude math.
 *
 * All functions take the HarmonyOS sensor frame (x right, y up, z out of screen)
 * and the rotation-vector world frame convention documented as East-North-Up.
 * The convention is NOT taken on faith: the S0 compass page shows both the
 * 12-o'clock (+Y) and 3-o'clock (+X) axes so it can be checked on the wrist.
 */

export interface AzAlt {
  az: number;
  alt: number;
}

export class Vec3 {
  x: number = 0;
  y: number = 0;
  z: number = 0;

  constructor(x: number, y: number, z: number) {
    this.x = x;
    this.y = y;
    this.z = z;
  }
}

const RAD2DEG: number = 180 / Math.PI;

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

/** Rotate a device-frame vector into the world frame using quaternion (x,y,z,w). */
export function rotateByQuat(qx: number, qy: number, qz: number, qw: number, v: Vec3): Vec3 {
  const qv: Vec3 = new Vec3(qx, qy, qz);
  const t: Vec3 = cross(qv, v);
  const t2: Vec3 = cross(qv, t);
  // v' = v + 2 * (qw * t + t2)
  return new Vec3(
    v.x + 2 * (qw * t.x + t2.x),
    v.y + 2 * (qw * t.y + t2.y),
    v.z + 2 * (qw * t.z + t2.z)
  );
}

/**
 * Azimuth/elevation of a device axis expressed in the ENU world frame.
 * axis 'y' = watch 12 o'clock, axis 'x' = watch 3 o'clock.
 *
 * Watch 5 reports the rotation vector as WORLD -> DEVICE; the conjugate
 * restores DEVICE -> WORLD. The sensor's x axis is mirrored relative to the
 * compass convention (with 12 o'clock north, 3 o'clock read 269.8 instead of
 * 90), so the bearing is atan2(-x, y). Verified on the wrist:
 * table north 0.3 -> table east 283.2 before the sign fix.
 */
export function azAltOfAxis(qx: number, qy: number, qz: number, qw: number, axis: string): AzAlt {
  const v: Vec3 = axis === 'x' ? new Vec3(1, 0, 0) : new Vec3(0, 1, 0);
  const w: Vec3 = rotateByQuat(-qx, -qy, -qz, qw, v);
  let az: number = Math.atan2(-w.x, w.y) * RAD2DEG;
  az = (az + 360) % 360;
  const alt: number = Math.asin(Math.max(-1, Math.min(1, w.z))) * RAD2DEG;
  return { az: az, alt: alt };
}

/**
 * Fallback when ROTATION_VECTOR is unavailable: tilt-compensated magnetic heading.
 * Returns the heading of the +Y axis and the residual tilt (degrees).
 */
export function magHeading(ax: number, ay: number, az: number,
                           mx: number, my: number, mz: number): AzAlt {
  const roll: number = Math.atan2(ay, az);
  const pitch: number = Math.atan2(-ax, Math.sqrt(ay * ay + az * az));

  const xh: number = mx * Math.cos(pitch) + mz * Math.sin(pitch);
  const yh: number = mx * Math.sin(roll) * Math.sin(pitch) + my * Math.cos(roll)
    - mz * Math.sin(roll) * Math.cos(pitch);

  let heading: number = Math.atan2(-yh, xh) * RAD2DEG;
  heading = (heading + 360) % 360;

  const tilt: number = Math.sqrt(roll * roll + pitch * pitch) * RAD2DEG;
  return { az: heading, alt: tilt };
}

/** Magnetic field magnitude in microtesla; 25–65 µT is a healthy outdoor range. */
export function magMagnitude(mx: number, my: number, mz: number): number {
  return Math.sqrt(mx * mx + my * my + mz * mz);
}

export function wrap360(deg: number): number {
  return (deg % 360 + 360) % 360;
}

export function shortestDelta(from: number, to: number): number {
  let d: number = wrap360(to) - wrap360(from);
  if (d > 180) {
    d -= 360;
  }
  if (d < -180) {
    d += 360;
  }
  return d;
}
