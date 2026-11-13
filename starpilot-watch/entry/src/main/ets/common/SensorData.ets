/**
 * F1 sensor envelope: value + hardware metadata + validation state.
 *
 * The SDK Response fields are the authority:
 *   timestamp: nanoseconds since boot
 *   accuracy:  SensorAccuracy (0 unreliable, 1 low, 2 medium, 3 high)
 * A sensor that does not expose accuracy is marked accuracyKnown=false, not faked.
 */

export interface SensorStats {
  samples: number;
  valid: number;
  invalid: number;
  duplicates: number;
  regressions: number;
  stale: number;
  lastTimestamp: number;
  lastReceivedAt: number;
  lastAccuracy: number;
  lastReason: string;
}

export interface OrientationSample {
  alpha: number;
  beta: number;
  gamma: number;
  timestamp: number;
  accuracy: number;
  accuracyKnown: boolean;
  receivedAt: number;
  valid: boolean;
  reason: string;
}

export interface RotationSample {
  x: number;
  y: number;
  z: number;
  w: number;
  rawX: number;
  rawY: number;
  rawZ: number;
  rawW: number;
  rawNorm: number;
  norm: number;
  timestamp: number;
  accuracy: number;
  accuracyKnown: boolean;
  receivedAt: number;
  valid: boolean;
  reason: string;
}

export interface GyroSample {
  x: number;
  y: number;
  z: number;
  timestamp: number;
  accuracy: number;
  accuracyKnown: boolean;
  receivedAt: number;
  valid: boolean;
  reason: string;
}

export type OrientationSampleHandler = (sample: OrientationSample) => void;
export type RotationSampleHandler = (sample: RotationSample) => void;
export type GyroSampleHandler = (sample: GyroSample) => void;

export function newSensorStats(): SensorStats {
  return {
    samples: 0,
    valid: 0,
    invalid: 0,
    duplicates: 0,
    regressions: 0,
    stale: 0,
    lastTimestamp: 0,
    lastReceivedAt: 0,
    lastAccuracy: -1,
    lastReason: ''
  };
}

export function finiteNumber(v: number): boolean {
  return typeof v === 'number' && v === v && v !== Infinity && v !== -Infinity;
}

export function copyStats(s: SensorStats): SensorStats {
  return {
    samples: s.samples,
    valid: s.valid,
    invalid: s.invalid,
    duplicates: s.duplicates,
    regressions: s.regressions,
    stale: s.stale,
    lastTimestamp: s.lastTimestamp,
    lastReceivedAt: s.lastReceivedAt,
    lastAccuracy: s.lastAccuracy,
    lastReason: s.lastReason
  };
}

export function accuracyLabel(a: number, known: boolean): string {
  if (!known) {
    return '不可用';
  }
  if (a === 0) {
    return 'UNRELIABLE';
  }
  if (a === 1) {
    return 'LOW';
  }
  if (a === 2) {
    return 'MEDIUM';
  }
  if (a === 3) {
    return 'HIGH';
  }
  return `未知(${a})`;
}
