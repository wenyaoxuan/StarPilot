import { CameraSpec } from './Photo';

export interface SkyModel {
  bortle: number;
  sqm: number;
  skyRate: number;
  readNoiseE: number;
  skyLimitedSec: number;
  saturationSec: number;
  recommendedSubSec: number;
}

const SQM_BY_BORTLE: number[] = [21.90, 21.70, 21.45, 20.80, 19.80, 18.90, 18.25, 17.80, 17.30];

/**
 * Bortle class -> approximate SQM (mag/arcsec^2).
 * Bortle is visual/subjective; these are the common published ranges.
 */
export function bortleToSqm(bortle: number): number {
  const b: number = Math.max(1, Math.min(9, bortle));
  const lo: number = Math.floor(b);
  const hi: number = Math.ceil(b);
  if (lo === hi) {
    return SQM_BY_BORTLE[lo - 1];
  }
  const t: number = b - lo;
  return SQM_BY_BORTLE[lo - 1] * (1 - t) + SQM_BY_BORTLE[hi - 1] * t;
}

/**
 * Sky electron rate per pixel, calibrated to the published SharpCap example
 * (14.5 e-/px/s at f/4.2, 3.75 um, Bortle 8.2). It scales as
 * (pixel pitch / f-number)^2 and 10^(-0.4*(SQM-21)).
 */
export function skyElectronRate(camera: CameraSpec, fNumber: number, bortle: number): number {
  const n: number = Math.max(0.7, fNumber);
  const sqm: number = bortleToSqm(bortle);
  const pitchFactor: number = Math.pow(camera.pixelPitchUm / 3.75, 2);
  const fFactor: number = Math.pow(4.2 / n, 2);
  const skyFactor: number = Math.pow(10, -0.4 * (sqm - 17.7));
  return Math.max(1e-6, 14.5 * pitchFactor * fFactor * skyFactor);
}

/** Approximate read noise vs ISO for a modern CMOS; only a planning estimate. */
export function readNoiseAtIso(iso: number): number {
  const stops: number = Math.log(Math.max(50, iso) / 100) / Math.LN2;
  return Math.max(1.5, Math.min(4.5, 4.5 - 0.55 * stops));
}

/**
 * Sky-limited exposure for a 5% camera-noise budget:
 *   t = rn^2 / (skyRate * ((1.05)^2 - 1))
 * and a highlight/saturation limit at half full well.
 *
 * Full well is approximated from pixel area; ISO scales the ADC clipping
 * point (base ISO 100). This is deliberately a planning model, not a
 * per-sensor calibration.
 */
export function skyModel(camera: CameraSpec, fNumber: number, bortle: number, iso: number): SkyModel {
  const sqm: number = bortleToSqm(bortle);
  const rate: number = skyElectronRate(camera, fNumber, bortle);
  const rn: number = readNoiseAtIso(iso);
  let fullWell: number = 50000 * Math.pow(camera.pixelPitchUm / 3.76, 2);
  fullWell = Math.max(20000, Math.min(200000, fullWell));
  const satE: number = Math.max(1, fullWell * 100 / Math.max(50, iso));
  const tSky: number = rn * rn / (rate * ((1.05 * 1.05) - 1));
  const tSat: number = 0.5 * satE / rate;
  return {
    bortle: bortle,
    sqm: sqm,
    skyRate: rate,
    readNoiseE: rn,
    skyLimitedSec: tSky,
    saturationSec: tSat,
    recommendedSubSec: Math.min(tSky, tSat)
  };
}
