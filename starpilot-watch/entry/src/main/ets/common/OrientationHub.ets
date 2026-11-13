import { sensor } from '@kit.SensorServiceKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { audit } from './AuditLog';
import {
  OrientationSample,
  OrientationSampleHandler,
  SensorStats,
  copyStats,
  finiteNumber,
  newSensorStats
} from './SensorData';

export type OrientationHandler = (alpha: number, beta: number, gamma: number) => void;

const STOP_GRACE_MS: number = 600;
const INTERVAL_NS: number = 100000000; // 100 ms = 10 Hz

/**
 * Shared ORIENTATION subscription.
 *
 * Numeric handlers remain the legacy interface. Sample handlers receive the full
 * envelope: hardware timestamp, accuracy, receive time, validation state.
 * Invalid/unreliable samples are counted and withheld from numeric handlers.
 */
class OrientationHub {
  private handlers: OrientationHandler[] = [];
  private sampleHandlers: OrientationSampleHandler[] = [];
  private active: boolean = false;
  private offTimer: number = -1;
  private stats: SensorStats = newSensorStats();
  private lastInvalidLogMs: number = 0;

  private readonly callback: (data: sensor.OrientationResponse) => void =
    (data: sensor.OrientationResponse): void => {
      const receivedAt: number = Date.now();
      const timestamp: number = finiteNumber(data.timestamp) ? data.timestamp : 0;
      const accuracy: number = finiteNumber(data.accuracy) ? data.accuracy : -1;
      const accuracyKnown: boolean = accuracy >= 0;
      let valid: boolean = true;
      let reason: string = '';

      this.stats.samples++;
      if (this.stats.lastReceivedAt > 0 && receivedAt - this.stats.lastReceivedAt > 1000) {
        this.stats.stale++;
      }
      if (accuracyKnown && accuracy !== this.stats.lastAccuracy) {
        audit('ORI_ACC', `${this.stats.lastAccuracy}->${accuracy}`);
      }
      if (!finiteNumber(data.alpha) || !finiteNumber(data.beta) || !finiteNumber(data.gamma)) {
        valid = false;
        reason = 'non-finite-value';
      } else if (!finiteNumber(timestamp) || timestamp <= 0) {
        valid = false;
        reason = 'invalid-timestamp';
      } else if (this.stats.lastTimestamp > 0 && timestamp < this.stats.lastTimestamp) {
        valid = false;
        reason = 'timestamp-regression';
        this.stats.regressions++;
      } else if (this.stats.lastTimestamp > 0 && timestamp === this.stats.lastTimestamp) {
        this.stats.duplicates++;
        reason = 'duplicate-timestamp';
      }
      if (valid && accuracyKnown && accuracy === 0) {
        valid = false;
        reason = 'accuracy-UNRELIABLE';
      }
      if (valid && accuracyKnown && accuracy === 1) {
        reason = reason === '' ? 'accuracy-LOW' : reason;
      }

      const sample: OrientationSample = {
        alpha: data.alpha,
        beta: data.beta,
        gamma: data.gamma,
        timestamp,
        accuracy,
        accuracyKnown,
        receivedAt,
        valid,
        reason
      };
      // Diagnostics see every sample, including rejected ones.
      const samples: OrientationSampleHandler[] = this.sampleHandlers;
      for (let i = 0; i < samples.length; i++) {
        samples[i](sample);
      }
      if (!valid) {
        this.stats.invalid++;
        this.stats.lastReason = reason;
        this.logInvalid(reason);
        return;
      }
      this.stats.valid++;
      this.stats.lastTimestamp = timestamp;
      this.stats.lastReceivedAt = receivedAt;
      this.stats.lastAccuracy = accuracy;
      this.stats.lastReason = reason;

      const list: OrientationHandler[] = this.handlers;
      for (let i = 0; i < list.length; i++) {
        list[i](data.alpha, data.beta, data.gamma);
      }
    };

  subscribe(handler: OrientationHandler): void {
    this.handlers.push(handler);
    this.activate();
  }

  subscribeSample(handler: OrientationSampleHandler): void {
    this.sampleHandlers.push(handler);
    this.activate();
  }

  unsubscribe(handler: OrientationHandler): void {
    this.handlers = this.handlers.filter((h: OrientationHandler) => h !== handler);
    this.deactivateIfIdle();
  }

  unsubscribeSample(handler: OrientationSampleHandler): void {
    this.sampleHandlers = this.sampleHandlers.filter((h: OrientationSampleHandler) => h !== handler);
    this.deactivateIfIdle();
  }

  statsSnapshot(): SensorStats {
    return copyStats(this.stats);
  }

  private activate(): void {
    this.cancelStop();
    if (this.active) {
      return;
    }
    try {
      sensor.on(sensor.SensorId.ORIENTATION, this.callback, { interval: INTERVAL_NS });
      this.active = true;
      audit('ORI_HUB', 'on ok 100ms');
    } catch (err) {
      const e: BusinessError = err as BusinessError;
      audit('ORI_HUB_ERR', `on ${e.code} ${e.message}`);
    }
  }

  private deactivateIfIdle(): void {
    if (this.handlers.length > 0 || this.sampleHandlers.length > 0 || !this.active
      || this.offTimer !== -1) {
      return;
    }
    this.offTimer = setTimeout(() => {
      this.offTimer = -1;
      if (this.handlers.length > 0 || this.sampleHandlers.length > 0 || !this.active) {
        return;
      }
      try {
        sensor.off(sensor.SensorId.ORIENTATION, this.callback);
        audit('ORI_HUB', 'off ok');
      } catch (err) {
        const e: BusinessError = err as BusinessError;
        audit('ORI_HUB_ERR', `off ${e.code} ${e.message}`);
      }
      this.active = false;
    }, STOP_GRACE_MS);
  }

  private cancelStop(): void {
    if (this.offTimer !== -1) {
      clearTimeout(this.offTimer);
      this.offTimer = -1;
    }
  }

  private logInvalid(reason: string): void {
    const now: number = Date.now();
    if (now - this.lastInvalidLogMs < 1000) {
      return;
    }
    this.lastInvalidLogMs = now;
    audit('ORI_INVALID', `${reason};invalid=${this.stats.invalid}`);
  }
}

export const orientationHub: OrientationHub = new OrientationHub();
