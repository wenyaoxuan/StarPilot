import { shortestDelta } from './Fusion';

export const FILTER_OFF: number = 0;
export const FILTER_SLERP: number = 1;
export const FILTER_ONE_EURO: number = 2;

export interface Quat {
  x: number;
  y: number;
  z: number;
  w: number;
}

export interface FilterResult {
  x: number;
  y: number;
  z: number;
  w: number;
  valid: boolean;
  mode: number;
  dtMs: number;
  cutoffHz: number;
  speedDeg: number;
  reset: boolean;
  reason: string;
}

/** Smooth the heading and tilt references at their own sample rates. */
export class PointingAngleFilter {
  private previous: number = 0;
  private filtered: number = 0;
  private speed: number = 0;
  private lastMs: number = 0;

  update(value: number, nowMs: number): number {
    const dt: number = (nowMs - this.lastMs) / 1000;
    this.lastMs = nowMs;
    if (dt <= 0 || dt > 1) {
      this.previous = value;
      this.filtered = value;
      this.speed = 0;
      return value;
    }
    const velocity: number = shortestDelta(this.previous, value) / dt;
    this.speed += (1 - Math.exp(-2 * Math.PI * 1.5 * dt)) * (velocity - this.speed);
    const cutoff: number = Math.min(12, 1.15 + 0.16 * Math.max(0, Math.abs(this.speed) - 4));
    const alpha: number = 1 - Math.exp(-2 * Math.PI * cutoff * dt);
    this.filtered += alpha * shortestDelta(this.filtered, value);
    this.previous = value;
    return this.filtered;
  }
}

function finite(v: number): boolean {
  return typeof v === 'number' && v === v && v !== Infinity && v !== -Infinity;
}

function dot(a: Quat, b: Quat): number {
  return a.x * b.x + a.y * b.y + a.z * b.z + a.w * b.w;
}

function normalize(q: Quat): Quat | null {
  if (!finite(q.x) || !finite(q.y) || !finite(q.z) || !finite(q.w)) {
    return null;
  }
  const n: number = Math.sqrt(dot(q, q));
  if (n < 0.5 || n > 2.0) {
    return null;
  }
  return { x: q.x / n, y: q.y / n, z: q.z / n, w: q.w / n };
}

function negate(q: Quat): Quat {
  return { x: -q.x, y: -q.y, z: -q.z, w: -q.w };
}

function slerp(a: Quat, b: Quat, t: number): Quat {
  let bb: Quat = b;
  if (dot(a, b) < 0) {
    bb = negate(b);
  }
  const c: number = Math.max(-1, Math.min(1, dot(a, bb)));
  const theta: number = Math.acos(c);
  if (theta < 1e-6) {
    return normalize({ x: a.x + (bb.x - a.x) * t, y: a.y + (bb.y - a.y) * t,
      z: a.z + (bb.z - a.z) * t, w: a.w + (bb.w - a.w) * t }) as Quat;
  }
  const s: number = Math.sin(theta);
  const ka: number = Math.sin((1 - t) * theta) / s;
  const kb: number = Math.sin(t * theta) / s;
  return normalize({ x: a.x * ka + bb.x * kb, y: a.y * ka + bb.y * kb,
    z: a.z * ka + bb.z * kb, w: a.w * ka + bb.w * kb }) as Quat;
}

function angleDeg(a: Quat, b: Quat): number {
  const d: number = Math.min(1, Math.abs(dot(a, b)));
  return 2 * Math.acos(d) * 180 / Math.PI;
}

/**
 * F4 attitude filter over a single ROT quaternion.
 *
 * - OFF: normalized raw.
 * - SLERP: fixed time-constant exponential SLERP (tau=80 ms).
 * - ONE_EURO: cutoff rises with low-passed angular speed; real dt.
 *
 * Invalid samples never enter the filter state. A gap >1 s or a non-advancing
 * timestamp restarts from the new sample. q and -q are unified before SLERP.
 */
export class AttitudeFilter {
  private mode: number = FILTER_OFF;
  private current: Quat | null = null;
  private previousRaw: Quat | null = null;
  private lastTimestamp: number = 0;
  private lastDtSec: number = 0;
  private speedDegPerSec: number = 0;
  private lastResult: FilterResult | null = null;

  constructor(mode: number = FILTER_OFF) {
    this.mode = mode;
  }

  setMode(mode: number): void {
    this.mode = mode;
    this.reset();
  }

  getMode(): number {
    return this.mode;
  }

  reset(): void {
    this.current = null;
    this.previousRaw = null;
    this.lastTimestamp = 0;
    this.lastDtSec = 0;
    this.speedDegPerSec = 0;
  }

  last(): FilterResult | null {
    return this.lastResult;
  }

  update(qx: number, qy: number, qz: number, qw: number,
         timestampNanos: number, receivedAt: number): FilterResult {
    const raw: Quat | null = normalize({ x: qx, y: qy, z: qz, w: qw });
    if (raw === null) {
      const err: FilterResult = {
        x: this.current === null ? 0 : this.current.x,
        y: this.current === null ? 0 : this.current.y,
        z: this.current === null ? 0 : this.current.z,
        w: this.current === null ? 1 : this.current.w,
        valid: false, mode: this.mode, dtMs: 0, cutoffHz: 0, speedDeg: 0,
        reset: false, reason: 'invalid-quaternion'
      };
      this.lastResult = err;
      return err;
    }
    const ts: number = finite(timestampNanos) ? timestampNanos : 0;
    if (ts <= 0) {
      const err: FilterResult = {
        x: raw.x, y: raw.y, z: raw.z, w: raw.w,
        valid: false, mode: this.mode, dtMs: 0, cutoffHz: 0, speedDeg: 0,
        reset: false, reason: 'invalid-timestamp'
      };
      this.lastResult = err;
      return err;
    }
    if (this.current === null || this.lastTimestamp === 0) {
      return this.restart(raw, ts, 'first-sample');
    }
    const dtSec: number = (ts - this.lastTimestamp) / 1e9;
    if (!finite(dtSec) || dtSec <= 0) {
      return this.restart(raw, ts, 'timestamp-not-advancing');
    }
    if (dtSec > 1.0) {
      return this.restart(raw, ts, 'gap>1s');
    }
    this.lastDtSec = dtSec;
    const target: Quat = dot(this.current, raw) < 0 ? negate(raw) : raw;

    if (this.mode === FILTER_OFF) {
      this.current = target;
      this.previousRaw = raw;
      this.lastTimestamp = ts;
      return this.makeResult(target, true, 0, 0, false, 'off');
    }

    let cutoff: number = 0;
    if (this.mode === FILTER_SLERP) {
      cutoff = 2.0;
    } else {
      const instDeg: number = angleDeg(this.previousRaw === null ? raw : this.previousRaw, raw);
      const instSpeed: number = instDeg / dtSec;
      const speedAlpha: number = 1 - Math.exp(-2 * Math.PI * 1.0 * dtSec);
      this.speedDegPerSec += speedAlpha * (instSpeed - this.speedDegPerSec);
      cutoff = 1.0 + 0.12 * Math.max(0, this.speedDegPerSec - 20.0);
      cutoff = Math.min(cutoff, 30.0);
    }
    const alpha: number = 1 - Math.exp(-2 * Math.PI * cutoff * dtSec);
    const out: Quat = slerp(this.current, target, Math.max(0, Math.min(1, alpha)));
    this.current = out;
    this.previousRaw = raw;
    this.lastTimestamp = ts;
    return this.makeResult(out, true, cutoff, this.speedDegPerSec, false, '');
  }

  private restart(raw: Quat, ts: number, reason: string): FilterResult {
    this.current = raw;
    this.previousRaw = raw;
    this.lastTimestamp = ts;
    this.lastDtSec = 0;
    this.speedDegPerSec = 0;
    return this.makeResult(raw, true, 0, 0, true, reason);
  }

  private makeResult(q: Quat, valid: boolean, cutoff: number, speed: number,
                     reset: boolean, reason: string): FilterResult {
    const r: FilterResult = {
      x: q.x, y: q.y, z: q.z, w: q.w, valid, mode: this.mode,
      dtMs: this.lastDtSec * 1000, cutoffHz: cutoff, speedDeg: speed,
      reset, reason
    };
    this.lastResult = r;
    return r;
  }
}
