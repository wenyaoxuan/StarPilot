import { Equatorial } from './Astro';

const DEG: number = Math.PI / 180;

export interface FramePoint {
  x: number;
  y: number;
  inside: boolean;
}

/** Move on the equatorial tangent plane. Offsets are tangent distances, with east and north positive. */
export function offsetFrameCenter(center: Equatorial, east: number, north: number): Equatorial {
  const dec: number = center.decDeg * DEG;
  const radial: number = Math.cos(dec) - north * Math.sin(dec);
  const height: number = Math.sin(dec) + north * Math.cos(dec);
  const raHours: number = (center.raHours + Math.atan2(east, radial) / (15 * DEG) + 24) % 24;
  return { raHours: raHours, decDeg: Math.atan2(height, Math.sqrt(radial * radial + east * east)) / DEG };
}

/** Ideal rectilinear camera in a single equatorial epoch. Positive rotation turns frame-up toward east. */
export class FramingFrame {
  private center: Equatorial;
  private halfX: number;
  private halfY: number;
  private sinDec: number;
  private cosDec: number;
  private sinAngle: number;
  private cosAngle: number;
  readonly widthDeg: number;
  readonly heightDeg: number;

  constructor(center: Equatorial, widthMm: number, heightMm: number, focalMm: number, angleDeg: number) {
    this.center = center;
    this.halfX = widthMm / (2 * focalMm);
    this.halfY = heightMm / (2 * focalMm);
    this.widthDeg = 2 * Math.atan(this.halfX) / DEG;
    this.heightDeg = 2 * Math.atan(this.halfY) / DEG;
    this.sinDec = Math.sin(center.decDeg * DEG);
    this.cosDec = Math.cos(center.decDeg * DEG);
    this.sinAngle = Math.sin(angleDeg * DEG);
    this.cosAngle = Math.cos(angleDeg * DEG);
  }

  project(object: Equatorial): FramePoint | null {
    const raDiff: number = (object.raHours - this.center.raHours) * 15 * DEG;
    const dec: number = object.decDeg * DEG;
    const cosDec: number = Math.cos(dec);
    const inPlane: number = cosDec * Math.cos(raDiff);
    const depth: number = this.sinDec * Math.sin(dec) + this.cosDec * inPlane;
    if (depth <= 1e-6) {
      return null;
    }
    const east: number = cosDec * Math.sin(raDiff) / depth;
    const north: number = (this.cosDec * Math.sin(dec) - this.sinDec * inPlane) / depth;
    const x: number = (east * this.cosAngle - north * this.sinAngle) / this.halfX;
    const y: number = (east * this.sinAngle + north * this.cosAngle) / this.halfY;
    return { x: x, y: y, inside: Math.abs(x) <= 1 + 1e-10 && Math.abs(y) <= 1 + 1e-10 };
  }

  move(x: number, y: number): Equatorial {
    const frameX: number = x * this.halfX;
    const frameY: number = y * this.halfY;
    return offsetFrameCenter(this.center, frameX * this.cosAngle + frameY * this.sinAngle,
      -frameX * this.sinAngle + frameY * this.cosAngle);
  }
}

export function angularRadiusOnPlane(diameterArcmin: number): number {
  return Math.tan(diameterArcmin * DEG / 120);
}
