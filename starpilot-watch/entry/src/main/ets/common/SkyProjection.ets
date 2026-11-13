import { Vec3 } from './Fusion';
import { CameraPose } from './CameraPose';

const D2R: number = Math.PI / 180;

export interface ProjectedPoint {
  x: number;
  y: number;
  z: number;
  visible: boolean;
  insideCircle: boolean;
}

export interface SkySegment {
  start: Vec3;
  end: Vec3;
}

export function enuVector(azDeg: number, altDeg: number): Vec3 {
  const a: number = altDeg * D2R;
  const z: number = azDeg * D2R;
  return new Vec3(Math.cos(a) * Math.sin(z), Math.cos(a) * Math.cos(z), Math.sin(a));
}

export function dotVec(a: Vec3, b: Vec3): number {
  return a.x * b.x + a.y * b.y + a.z * b.z;
}

function alongSegment(a: Vec3, b: Vec3, t: number): Vec3 {
  return new Vec3(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t, a.z + (b.z - a.z) * t);
}

/** Clip a constellation edge against the horizon and the camera's near plane. */
export function visibleSkySegment(a: Vec3, b: Vec3, forward: Vec3): SkySegment | null {
  const near: number = 0.01;
  const startDepth: number = dotVec(a, forward) - near;
  const endDepth: number = dotVec(b, forward) - near;
  if ((a.z < 0 && b.z < 0) || (startDepth < 0 && endDepth < 0)) {
    return null;
  }
  let start: number = a.z < 0 ? a.z / (a.z - b.z) : 0;
  let end: number = b.z < 0 ? a.z / (a.z - b.z) : 1;
  if (startDepth < 0) {
    start = Math.max(start, startDepth / (startDepth - endDepth));
  } else if (endDepth < 0) {
    end = Math.min(end, startDepth / (startDepth - endDepth));
  }
  if (start >= end) {
    return null;
  }
  return { start: start === 0 ? a : alongSegment(a, b, start), end: end === 1 ? b : alongSegment(a, b, end) };
}

export function angularSepVec(a: Vec3, b: Vec3): number {
  const la: number = Math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z);
  const lb: number = Math.sqrt(b.x * b.x + b.y * b.y + b.z * b.z);
  if (la < 1e-9 || lb < 1e-9) {
    return 0;
  }
  const c: number = dotVec(a, b) / (la * lb);
  return Math.acos(Math.max(-1, Math.min(1, c))) * 180 / Math.PI;
}

function finite(v: number): boolean {
  return typeof v === 'number' && v === v && v !== Infinity && v !== -Infinity;
}

/**
 * F3 perspective projection.
 *
 * Input direction is an ENU unit vector. Camera coordinates:
 *   x = dot(v, right)
 *   y = dot(v, up)
 *   z = dot(v, forward)
 *
 * Only z > EPS is a front-facing point. Screen uses top-left origin, so y is
 * negated after the perspective divide. The circular safe area is applied here
 * so callers never draw a star outside the watch bezel.
 */
export function projectPoint(pose: CameraPose, fovDeg: number,
                             width: number, height: number, v: Vec3): ProjectedPoint {
  const eps: number = 1e-4;
  const xc: number = dotVec(v, pose.right);
  const yc: number = dotVec(v, pose.up);
  const zc: number = dotVec(v, pose.forward);
  const visible: boolean = finite(xc) && finite(yc) && finite(zc) && zc > eps;
  const f: number = (width / 2) / Math.tan(fovDeg * D2R / 2);
  const x: number = visible ? width / 2 + f * xc / zc : 0;
  const y: number = visible ? height / 2 - f * yc / zc : 0;
  const cx: number = width / 2;
  const cy: number = height / 2;
  const safeR: number = Math.min(width, height) / 2 - 16;
  const insideCircle: boolean = visible
    && (x - cx) * (x - cx) + (y - cy) * (y - cy) <= safeR * safeR;
  return { x, y, z: zc, visible, insideCircle };
}

/** Unit direction of an off-screen projected point, used only for the edge arrow. */
export function screenDirection(p: ProjectedPoint, width: number, height: number): Vec3 {
  const dx: number = p.x - width / 2;
  const dy: number = p.y - height / 2;
  const l: number = Math.sqrt(dx * dx + dy * dy);
  if (l < 1e-9) {
    return new Vec3(0, -1, 0);
  }
  return new Vec3(dx / l, dy / l, 0);
}
