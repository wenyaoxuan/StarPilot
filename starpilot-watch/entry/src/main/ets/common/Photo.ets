/**
 * Photography math for StarPilot.
 *
 * Pure math, no HarmonyOS imports: compiled into the watch app and transpiled
 * for the Node test harness.
 *
 * Units: focal length mm, pixel pitch µm, angles degrees, time seconds.
 */

const DEG: number = Math.PI / 180;
const RAD: number = 180 / Math.PI;
const ARCSEC_PER_RAD: number = 206264.80624709636;
const SIDEREAL_RATE_ARCSEC: number = 15.041;

export interface CameraSpec {
  name: string;
  brand: string;
  format: string;
  cropFactor: number;
  sensorW: number;
  sensorH: number;
  pixelPitchUm: number;
  pixelsX: number;
  pixelsY: number;
  effectiveMp?: number;
  note?: string;
}

export interface LensSpec {
  name: string;
  focalMm: number;
  maxAperture: number;
}

export interface FovResult {
  hDeg: number;
  vDeg: number;
  diagDeg: number;
  pixelScaleArcsec: number;
}

export interface ExposureResult {
  npfSec: number;
  rule500Sec: number;
  pixelDragSec: number;
}

export interface StackPlan {
  count: number;
  actualTotalSec: number;
}

/**
 * Common interchangeable-lens and fixed-lens bodies. Sensor size and pixel
 * pitch decide FOV and NPF, so APS-C/M43/medium format are not treated as
 * "the same 85mm". Specs are rounded public figures, not calibration data.
 */
export const CAMERAS: CameraSpec[] = [
  { name: 'A7R IV', brand: 'Sony', format: '全画幅', cropFactor: 1.0,
    sensorW: 35.7, sensorH: 23.8, pixelPitchUm: 3.76, pixelsX: 9504, pixelsY: 6336 },
  { name: 'A7 IV', brand: 'Sony', format: '全画幅', cropFactor: 1.0,
    sensorW: 35.9, sensorH: 23.9, pixelPitchUm: 5.12, pixelsX: 7008, pixelsY: 4672 },
  { name: 'A7S III', brand: 'Sony', format: '全画幅', cropFactor: 1.0,
    sensorW: 35.6, sensorH: 23.8, pixelPitchUm: 8.40, pixelsX: 4240, pixelsY: 2832 },
  { name: 'A1 II', brand: 'Sony', format: '全画幅', cropFactor: 1.0,
    sensorW: 35.9, sensorH: 23.9, pixelPitchUm: 4.16, pixelsX: 8640, pixelsY: 5760 },
  { name: 'A6700', brand: 'Sony', format: 'APS-C', cropFactor: 1.5,
    sensorW: 23.5, sensorH: 15.6, pixelPitchUm: 3.80, pixelsX: 6192, pixelsY: 4128 },
  { name: 'EOS R5', brand: 'Canon', format: '全画幅', cropFactor: 1.0,
    sensorW: 36.0, sensorH: 24.0, pixelPitchUm: 4.39, pixelsX: 8192, pixelsY: 5464 },
  { name: 'EOS R6 Mark II', brand: 'Canon', format: '全画幅', cropFactor: 1.0,
    sensorW: 35.9, sensorH: 23.9, pixelPitchUm: 5.98, pixelsX: 6000, pixelsY: 4000 },
  { name: 'EOS R7', brand: 'Canon', format: 'APS-C', cropFactor: 1.6,
    sensorW: 22.3, sensorH: 14.9, pixelPitchUm: 3.20, pixelsX: 6960, pixelsY: 4640 },
  { name: 'Z8', brand: 'Nikon', format: '全画幅', cropFactor: 1.0,
    sensorW: 35.9, sensorH: 23.9, pixelPitchUm: 4.35, pixelsX: 8256, pixelsY: 5504 },
  { name: 'Z6 III', brand: 'Nikon', format: '全画幅', cropFactor: 1.0,
    sensorW: 35.9, sensorH: 23.9, pixelPitchUm: 5.94, pixelsX: 6048, pixelsY: 4032 },
  { name: 'Z50 II', brand: 'Nikon', format: 'APS-C', cropFactor: 1.5,
    sensorW: 23.5, sensorH: 15.7, pixelPitchUm: 4.22, pixelsX: 5568, pixelsY: 3712 },
  { name: 'X-T5', brand: 'Fujifilm', format: 'APS-C', cropFactor: 1.5,
    sensorW: 23.5, sensorH: 15.6, pixelPitchUm: 3.04, pixelsX: 7728, pixelsY: 5152 },
  { name: 'X-H2S', brand: 'Fujifilm', format: 'APS-C', cropFactor: 1.5,
    sensorW: 23.5, sensorH: 15.6, pixelPitchUm: 3.77, pixelsX: 6240, pixelsY: 4160 },
  { name: 'GFX 100S', brand: 'Fujifilm', format: '中画幅', cropFactor: 0.79,
    sensorW: 43.8, sensorH: 32.9, pixelPitchUm: 3.76, pixelsX: 11648, pixelsY: 8736 },
  { name: 'Lumix S5 II', brand: 'Panasonic', format: '全画幅', cropFactor: 1.0,
    sensorW: 35.6, sensorH: 23.8, pixelPitchUm: 5.93, pixelsX: 6000, pixelsY: 4000 },
  { name: 'Lumix GH6', brand: 'Panasonic', format: 'M4/3', cropFactor: 2.0,
    sensorW: 17.3, sensorH: 13.0, pixelPitchUm: 3.00, pixelsX: 5776, pixelsY: 4336 },
  { name: 'OM-1', brand: 'OM System', format: 'M4/3', cropFactor: 2.0,
    sensorW: 17.4, sensorH: 13.0, pixelPitchUm: 3.36, pixelsX: 5184, pixelsY: 3888 },
  { name: 'Q3', brand: 'Leica', format: '全画幅', cropFactor: 1.0,
    sensorW: 35.8, sensorH: 23.9, pixelPitchUm: 3.76, pixelsX: 9520, pixelsY: 6336 },
  { name: 'SL3', brand: 'Leica', format: '全画幅', cropFactor: 1.0,
    sensorW: 35.8, sensorH: 23.9, pixelPitchUm: 3.76, pixelsX: 9520, pixelsY: 6336 },
  { name: 'X2D 100C', brand: 'Hasselblad', format: '中画幅', cropFactor: 0.79,
    sensorW: 43.8, sensorH: 32.9, pixelPitchUm: 3.76, pixelsX: 11656, pixelsY: 8742 },
  { name: 'iPhone 15 Pro', brand: 'Apple', format: '1/1.28"', cropFactor: 3.54,
    sensorW: 9.8, sensorH: 7.3, pixelPitchUm: 1.22, pixelsX: 8064, pixelsY: 6048 },
  { name: 'A9 III', brand: 'Sony', format: '全画幅', cropFactor: 1.0,
    sensorW: 35.9, sensorH: 23.9, pixelPitchUm: 5.98, pixelsX: 6000, pixelsY: 4000 },
  { name: 'A7C II', brand: 'Sony', format: '全画幅', cropFactor: 1.0,
    sensorW: 35.9, sensorH: 23.9, pixelPitchUm: 5.12, pixelsX: 7008, pixelsY: 4672 },
  { name: 'A7CR', brand: 'Sony', format: '全画幅', cropFactor: 1.0,
    sensorW: 35.7, sensorH: 23.8, pixelPitchUm: 3.76, pixelsX: 9504, pixelsY: 6336 },
  { name: 'EOS R1', brand: 'Canon', format: '全画幅', cropFactor: 1.0,
    sensorW: 35.9, sensorH: 23.9, pixelPitchUm: 5.98, pixelsX: 6000, pixelsY: 4000 },
  { name: 'EOS R5 Mark II', brand: 'Canon', format: '全画幅', cropFactor: 1.0,
    sensorW: 36.0, sensorH: 24.0, pixelPitchUm: 4.39, pixelsX: 8192, pixelsY: 5464 },
  { name: 'EOS R50 V', brand: 'Canon', format: 'APS-C', cropFactor: 1.6,
    sensorW: 22.3, sensorH: 14.9, pixelPitchUm: 3.72, pixelsX: 6000, pixelsY: 4000 },
  { name: 'Z9', brand: 'Nikon', format: '全画幅', cropFactor: 1.0,
    sensorW: 35.9, sensorH: 23.9, pixelPitchUm: 4.35, pixelsX: 8256, pixelsY: 5504 },
  { name: 'Z5 II', brand: 'Nikon', format: '全画幅', cropFactor: 1.0,
    sensorW: 35.9, sensorH: 23.9, pixelPitchUm: 5.94, pixelsX: 6048, pixelsY: 4032 },
  { name: 'X-T50', brand: 'Fujifilm', format: 'APS-C', cropFactor: 1.5,
    sensorW: 23.5, sensorH: 15.6, pixelPitchUm: 3.04, pixelsX: 7728, pixelsY: 5152 },
  { name: 'X-M5', brand: 'Fujifilm', format: 'APS-C', cropFactor: 1.5,
    sensorW: 23.5, sensorH: 15.6, pixelPitchUm: 3.77, pixelsX: 6240, pixelsY: 4160 },
  { name: 'X100VI', brand: 'Fujifilm', format: 'APS-C', cropFactor: 1.5,
    sensorW: 23.5, sensorH: 15.6, pixelPitchUm: 3.04, pixelsX: 7728, pixelsY: 5152 },
  { name: 'GFX 100 II', brand: 'Fujifilm', format: '中画幅', cropFactor: 0.79,
    sensorW: 43.8, sensorH: 32.9, pixelPitchUm: 3.76, pixelsX: 11648, pixelsY: 8736 },
  { name: 'Lumix S1 II', brand: 'Panasonic', format: '全画幅', cropFactor: 1.0,
    sensorW: 35.6, sensorH: 23.8, pixelPitchUm: 5.93, pixelsX: 6000, pixelsY: 4000 },
  { name: 'Lumix S1R II', brand: 'Panasonic', format: '全画幅', cropFactor: 1.0,
    sensorW: 35.8, sensorH: 23.9, pixelPitchUm: 4.40, pixelsX: 8144, pixelsY: 5424,
    effectiveMp: 44.3 },
  { name: 'Lumix GH7', brand: 'Panasonic', format: 'M4/3', cropFactor: 2.0,
    sensorW: 17.3, sensorH: 13.0, pixelPitchUm: 3.00, pixelsX: 5776, pixelsY: 4336 },
  { name: 'OM-3', brand: 'OM System', format: 'M4/3', cropFactor: 2.0,
    sensorW: 17.4, sensorH: 13.0, pixelPitchUm: 3.36, pixelsX: 5184, pixelsY: 3888 },
  { name: 'OM-1 II', brand: 'OM System', format: 'M4/3', cropFactor: 2.0,
    sensorW: 17.4, sensorH: 13.0, pixelPitchUm: 3.36, pixelsX: 5184, pixelsY: 3888 },
  { name: 'SL3-S', brand: 'Leica', format: '全画幅', cropFactor: 1.0,
    sensorW: 35.8, sensorH: 23.9, pixelPitchUm: 5.97, pixelsX: 6000, pixelsY: 4000 },
  { name: 'Q3 43', brand: 'Leica', format: '全画幅', cropFactor: 1.0,
    sensorW: 35.8, sensorH: 23.9, pixelPitchUm: 3.76, pixelsX: 9520, pixelsY: 6336 },
  { name: 'X2D II 100C', brand: 'Hasselblad', format: '中画幅', cropFactor: 0.79,
    sensorW: 43.8, sensorH: 32.9, pixelPitchUm: 3.76, pixelsX: 11656, pixelsY: 8742 },
  { name: 'K-3 III', brand: 'Pentax', format: 'APS-C', cropFactor: 1.5,
    sensorW: 23.3, sensorH: 15.5, pixelPitchUm: 3.76, pixelsX: 6192, pixelsY: 4128,
    effectiveMp: 25.7 },
  { name: 'K-3 III Monochrome', brand: 'Pentax', format: 'APS-C', cropFactor: 1.5,
    sensorW: 23.3, sensorH: 15.5, pixelPitchUm: 3.76, pixelsX: 6192, pixelsY: 4128,
    effectiveMp: 25.7 },
  { name: 'K-1 II', brand: 'Pentax', format: '全画幅', cropFactor: 1.0,
    sensorW: 35.9, sensorH: 24.0, pixelPitchUm: 4.88, pixelsX: 7360, pixelsY: 4912 },
  { name: '645Z', brand: 'Pentax', format: '中画幅', cropFactor: 0.79,
    sensorW: 43.8, sensorH: 32.8, pixelPitchUm: 5.31, pixelsX: 8256, pixelsY: 6192 },
  { name: 'A7R V', brand: 'Sony', format: '全画幅', cropFactor: 1.0,
    sensorW: 35.7, sensorH: 23.8, pixelPitchUm: 3.76, pixelsX: 9504, pixelsY: 6336 },
  { name: 'A7 V', brand: 'Sony', format: '全画幅', cropFactor: 1.0,
    sensorW: 35.9, sensorH: 23.9, pixelPitchUm: 5.12, pixelsX: 7008, pixelsY: 4672,
    effectiveMp: 33.0 },
  { name: 'A7R VI', brand: 'Sony', format: '全画幅', cropFactor: 1.0,
    sensorW: 35.9, sensorH: 24.0, pixelPitchUm: 3.60, pixelsX: 9984, pixelsY: 6656,
    effectiveMp: 66.8 },
  { name: 'EOS R6 Mark III', brand: 'Canon', format: '全画幅', cropFactor: 1.0,
    sensorW: 35.9, sensorH: 23.9, pixelPitchUm: 5.16, pixelsX: 6960, pixelsY: 4640,
    effectiveMp: 32.5 }
];

export const A7R4: CameraSpec = CAMERAS[0];

/** Common focal lengths; max aperture is a lens-class reference, not a mount spec. */
export const FOCALS: LensSpec[] = [
  { name: '14mm F2.8', focalMm: 14, maxAperture: 2.8 },
  { name: '20mm F1.8', focalMm: 20, maxAperture: 1.8 },
  { name: '24mm F1.4', focalMm: 24, maxAperture: 1.4 },
  { name: '28mm F1.8', focalMm: 28, maxAperture: 1.8 },
  { name: '35mm F1.4', focalMm: 35, maxAperture: 1.4 },
  { name: '50mm F1.8', focalMm: 50, maxAperture: 1.8 },
  { name: '85mm F1.8', focalMm: 85, maxAperture: 1.8 },
  { name: '105mm F2.8', focalMm: 105, maxAperture: 2.8 },
  { name: '135mm F1.8', focalMm: 135, maxAperture: 1.8 },
  { name: '180mm F2.8', focalMm: 180, maxAperture: 2.8 },
  { name: '200mm F2.8', focalMm: 200, maxAperture: 2.8 },
  { name: '300mm F4', focalMm: 300, maxAperture: 4.0 },
  { name: '400mm F5.6', focalMm: 400, maxAperture: 5.6 },
  { name: '600mm F6.3', focalMm: 600, maxAperture: 6.3 },
  { name: '800mm F8', focalMm: 800, maxAperture: 8.0 }
];

/** Backward-compatible alias for tests/tools written before FOCALS existed. */
export const LENSES: LensSpec[] = FOCALS;

export function cameraMegapixels(c: CameraSpec): number {
  if (c.effectiveMp !== undefined) {
    return c.effectiveMp;
  }
  return c.pixelsX * c.pixelsY / 1e6;
}

export function equivalentFocalMm(c: CameraSpec, focalMm: number): number {
  return focalMm * c.cropFactor;
}

export function clampAperture(v: number): number {
  const r: number = Math.round(v * 10) / 10;
  return Math.max(0.7, Math.min(22, r));
}

export const APERTURES: number[] = [1.8, 2.0, 2.8, 3.5, 4.0, 4.5, 5.6, 6.3, 7.1, 8.0, 11.0, 16.0];
export const ISOS: number[] = [100, 200, 400, 800, 1600, 3200, 6400, 12800];
export const SUB_SECONDS: number[] = [30, 60, 120, 180, 300];
export const COUNTS: number[] = [10, 20, 30, 60, 90];
export const TARGET_MINUTES: number[] = [15, 30, 60, 120, 240];

export function fovFor(camera: CameraSpec, focalMm: number): FovResult {
  const h: number = 2 * Math.atan(camera.sensorW / (2 * focalMm)) * RAD;
  const v: number = 2 * Math.atan(camera.sensorH / (2 * focalMm)) * RAD;
  const diagMm: number = Math.sqrt(camera.sensorW * camera.sensorW + camera.sensorH * camera.sensorH);
  const d: number = 2 * Math.atan(diagMm / (2 * focalMm)) * RAD;
  const out: FovResult = {
    hDeg: h,
    vDeg: v,
    diagDeg: d,
    pixelScaleArcsec: ARCSEC_PER_RAD * camera.pixelPitchUm / 1000 / focalMm
  };
  return out;
}

/** NPF rule. Declination shortens star motion near the poles. */
export function npfSeconds(focalMm: number, aperture: number, pixelPitchUm: number,
                           decDeg: number): number {
  const cosDec: number = Math.max(0.2, Math.abs(Math.cos(decDeg * DEG)));
  return (35 * aperture + 30 * pixelPitchUm) / (focalMm * cosDec);
}

export function rule500Seconds(focalMm: number): number {
  return 500 / focalMm;
}

/** Time for a star to trail `maxTrailPx` pixels at the given declination. */
export function pixelDragSeconds(focalMm: number, pixelPitchUm: number,
                                 maxTrailPx: number, decDeg: number): number {
  const cosDec: number = Math.max(0.2, Math.abs(Math.cos(decDeg * DEG)));
  const scale: number = ARCSEC_PER_RAD * pixelPitchUm / 1000 / focalMm;
  return scale * maxTrailPx / (SIDEREAL_RATE_ARCSEC * cosDec);
}

export function exposureFor(camera: CameraSpec, focalMm: number, aperture: number,
                            decDeg: number): ExposureResult {
  const out: ExposureResult = {
    npfSec: npfSeconds(focalMm, aperture, camera.pixelPitchUm, decDeg),
    rule500Sec: rule500Seconds(focalMm),
    pixelDragSec: pixelDragSeconds(focalMm, camera.pixelPitchUm, 1, decDeg)
  };
  return out;
}

export function stackPlan(targetTotalSec: number, subSec: number): StackPlan {
  if (subSec <= 0) {
    const zero: StackPlan = { count: 0, actualTotalSec: 0 };
    return zero;
  }
  const count: number = Math.ceil(targetTotalSec / subSec);
  const out: StackPlan = { count: count, actualTotalSec: count * subSec };
  return out;
}

export function formatDuration(sec: number): string {
  if (sec < 60) {
    return `${sec.toFixed(1)}s`;
  }
  if (sec < 3600) {
    return `${(sec / 60).toFixed(1)}min`;
  }
  return `${(sec / 3600).toFixed(1)}h`;
}
