import { sensor } from '@kit.SensorServiceKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { audit } from './AuditLog';
import { GyroSample, GyroSampleHandler, RotationSample, RotationSampleHandler, SensorStats, copyStats, finiteNumber, newSensorStats } from './SensorData';

export type AccHandler = (x: number, y: number, z: number) => void;
export type GyroHandler = (x: number, y: number, z: number) => void;
export type MagHandler = (x: number, y: number, z: number) => void;
export type RotHandler = (x: number, y: number, z: number, w: number) => void;

const STOP_GRACE_MS: number = 600;

/**
 * One hardware subscription per sensor, shared by all pages.
 *
 * Two real-watch problems this solves:
 * 1. Page-level on/off raced during Swiper transitions and one page removed
 *    the other page's subscription.
 * 2. The rotation-vector sensor returns a zero quaternion after a rapid
 *    off/on during a page swipe. Stopping is therefore deferred by 600 ms so
 *    a page-to-page handover never interrupts the stream.
 */
class SensorHub {
  private accHandlers: AccHandler[] = [];
  private gyroHandlers: GyroHandler[] = [];
  private magHandlers: MagHandler[] = [];
  private rotHandlers: RotHandler[] = [];
  private gyroSampleHandlers: GyroSampleHandler[] = [];
  private rotSampleHandlers: RotationSampleHandler[] = [];

  private accActive: boolean = false;
  private gyroActive: boolean = false;
  private magActive: boolean = false;
  private rotActive: boolean = false;

  private accOffTimer: number = -1;
  private gyroOffTimer: number = -1;
  private magOffTimer: number = -1;
  private rotOffTimer: number = -1;
  private gyroStats: SensorStats = newSensorStats();
  private rotStats: SensorStats = newSensorStats();
  private lastGyroInvalidLogMs: number = 0;
  private lastRotInvalidLogMs: number = 0;

  private readonly accCallback: (data: sensor.AccelerometerResponse) => void =
    (data: sensor.AccelerometerResponse): void => {
      const list: AccHandler[] = this.accHandlers;
      for (let i = 0; i < list.length; i++) {
        list[i](data.x, data.y, data.z);
      }
    };

  private readonly gyroCallback: (data: sensor.GyroscopeResponse) => void =
    (data: sensor.GyroscopeResponse): void => {
      const receivedAt: number = Date.now();
      const timestamp: number = finiteNumber(data.timestamp) ? data.timestamp : 0;
      const accuracy: number = finiteNumber(data.accuracy) ? data.accuracy : -1;
      const accuracyKnown: boolean = accuracy >= 0;
      let valid: boolean = true;
      let reason: string = '';
      this.gyroStats.samples++;
      if (this.gyroStats.lastReceivedAt > 0 && receivedAt - this.gyroStats.lastReceivedAt > 1000) {
        this.gyroStats.stale++;
      }
      if (accuracyKnown && accuracy !== this.gyroStats.lastAccuracy) {
        audit('GYRO_ACC', `${this.gyroStats.lastAccuracy}->${accuracy}`);
      }
      if (!finiteNumber(data.x) || !finiteNumber(data.y) || !finiteNumber(data.z)) {
        valid = false;
        reason = 'non-finite-value';
      } else if (timestamp <= 0) {
        valid = false;
        reason = 'invalid-timestamp';
      } else if (this.gyroStats.lastTimestamp > 0 && timestamp < this.gyroStats.lastTimestamp) {
        valid = false;
        reason = 'timestamp-regression';
        this.gyroStats.regressions++;
      } else if (this.gyroStats.lastTimestamp > 0 && timestamp === this.gyroStats.lastTimestamp) {
        this.gyroStats.duplicates++;
        reason = 'duplicate-timestamp';
      }
      if (valid && accuracyKnown && accuracy === 0) {
        valid = false;
        reason = 'accuracy-UNRELIABLE';
      }
      if (valid && accuracyKnown && accuracy === 1 && reason === '') {
        reason = 'accuracy-LOW';
      }
      const sample: GyroSample = {
        x: data.x, y: data.y, z: data.z, timestamp, accuracy, accuracyKnown,
        receivedAt, valid, reason
      };
      const sampleList: GyroSampleHandler[] = this.gyroSampleHandlers;
      for (let i = 0; i < sampleList.length; i++) {
        sampleList[i](sample);
      }
      if (!valid) {
        this.gyroStats.invalid++;
        this.gyroStats.lastReason = reason;
        const now: number = Date.now();
        if (now - this.lastGyroInvalidLogMs > 1000) {
          this.lastGyroInvalidLogMs = now;
          audit('GYRO_INVALID', `${reason};invalid=${this.gyroStats.invalid}`);
        }
        return;
      }
      this.gyroStats.valid++;
      this.gyroStats.lastTimestamp = timestamp;
      this.gyroStats.lastReceivedAt = receivedAt;
      this.gyroStats.lastAccuracy = accuracy;
      this.gyroStats.lastReason = reason;
      const list: GyroHandler[] = this.gyroHandlers;
      for (let i = 0; i < list.length; i++) {
        list[i](data.x, data.y, data.z);
      }
    };

  private readonly magCallback: (data: sensor.MagneticFieldResponse) => void =
    (data: sensor.MagneticFieldResponse): void => {
      const list: MagHandler[] = this.magHandlers;
      for (let i = 0; i < list.length; i++) {
        list[i](data.x, data.y, data.z);
      }
    };

  private readonly rotCallback: (data: sensor.RotationVectorResponse) => void =
    (data: sensor.RotationVectorResponse): void => {
      const receivedAt: number = Date.now();
      const timestamp: number = finiteNumber(data.timestamp) ? data.timestamp : 0;
      const accuracy: number = finiteNumber(data.accuracy) ? data.accuracy : -1;
      const accuracyKnown: boolean = accuracy >= 0;
      const rawNorm: number = Math.sqrt(data.x * data.x + data.y * data.y
        + data.z * data.z + data.w * data.w);
      let valid: boolean = true;
      let reason: string = '';
      this.rotStats.samples++;
      if (this.rotStats.lastReceivedAt > 0 && receivedAt - this.rotStats.lastReceivedAt > 1000) {
        this.rotStats.stale++;
      }
      if (accuracyKnown && accuracy !== this.rotStats.lastAccuracy) {
        audit('ROT_ACC', `${this.rotStats.lastAccuracy}->${accuracy}`);
      }
      if (!finiteNumber(data.x) || !finiteNumber(data.y) || !finiteNumber(data.z)
        || !finiteNumber(data.w)) {
        valid = false;
        reason = 'non-finite-value';
      } else if (rawNorm < 0.5 || rawNorm > 2.0) {
        valid = false;
        reason = `quaternion-norm=${rawNorm.toFixed(3)}`;
      } else if (timestamp <= 0) {
        valid = false;
        reason = 'invalid-timestamp';
      } else if (this.rotStats.lastTimestamp > 0 && timestamp < this.rotStats.lastTimestamp) {
        valid = false;
        reason = 'timestamp-regression';
        this.rotStats.regressions++;
      } else if (this.rotStats.lastTimestamp > 0 && timestamp === this.rotStats.lastTimestamp) {
        this.rotStats.duplicates++;
        reason = 'duplicate-timestamp';
      }
      if (valid && accuracyKnown && accuracy === 0) {
        valid = false;
        reason = 'accuracy-UNRELIABLE';
      }
      if (valid && accuracyKnown && accuracy === 1 && reason === '') {
        reason = 'accuracy-LOW';
      }
      const norm: number = rawNorm > 1e-9 ? rawNorm : 1;
      const nx: number = data.x / norm;
      const ny: number = data.y / norm;
      const nz: number = data.z / norm;
      const nw: number = data.w / norm;
      const sample: RotationSample = {
        x: nx, y: ny, z: nz, w: nw,
        rawX: data.x, rawY: data.y, rawZ: data.z, rawW: data.w,
        rawNorm, norm, timestamp, accuracy, accuracyKnown,
        receivedAt, valid, reason
      };
      const sampleList: RotationSampleHandler[] = this.rotSampleHandlers;
      for (let i = 0; i < sampleList.length; i++) {
        sampleList[i](sample);
      }
      if (!valid) {
        this.rotStats.invalid++;
        this.rotStats.lastReason = reason;
        const now: number = Date.now();
        if (now - this.lastRotInvalidLogMs > 1000) {
          this.lastRotInvalidLogMs = now;
          audit('ROT_INVALID', `${reason};invalid=${this.rotStats.invalid}`);
        }
        return;
      }
      this.rotStats.valid++;
      this.rotStats.lastTimestamp = timestamp;
      this.rotStats.lastReceivedAt = receivedAt;
      this.rotStats.lastAccuracy = accuracy;
      this.rotStats.lastReason = reason;
      const list: RotHandler[] = this.rotHandlers;
      for (let i = 0; i < list.length; i++) {
        list[i](nx, ny, nz, nw);
      }
    };

  subscribeAcc(handler: AccHandler): void {
    this.accHandlers.push(handler);
    this.cancelAccStop();
    if (this.accActive) {
      return;
    }
    this.startAcc();
  }

  unsubscribeAcc(handler: AccHandler): void {
    this.accHandlers = this.accHandlers.filter((h: AccHandler) => h !== handler);
    if (this.accHandlers.length > 0 || !this.accActive || this.accOffTimer !== -1) {
      return;
    }
    this.accOffTimer = setTimeout(() => {
      this.accOffTimer = -1;
      if (this.accHandlers.length > 0 || !this.accActive) {
        return;
      }
      try {
        sensor.off(sensor.SensorId.ACCELEROMETER, this.accCallback);
      } catch (err) {
        const e = err as BusinessError;
        audit('HUB_ERR', `off acc ${e.code} ${e.message}`);
      }
      this.accActive = false;
      audit('HUB', 'acc off');
    }, STOP_GRACE_MS);
  }

  subscribeGyro(handler: GyroHandler): void {
    this.gyroHandlers.push(handler);
    this.cancelGyroStop();
    if (this.gyroActive) {
      return;
    }
    this.startGyro();
  }

  subscribeGyroSample(handler: GyroSampleHandler): void {
    this.gyroSampleHandlers.push(handler);
    this.cancelGyroStop();
    if (this.gyroActive) {
      return;
    }
    this.startGyro();
  }

  unsubscribeGyroSample(handler: GyroSampleHandler): void {
    this.gyroSampleHandlers = this.gyroSampleHandlers.filter((h: GyroSampleHandler) => h !== handler);
    if (this.gyroHandlers.length > 0 || this.gyroSampleHandlers.length > 0
      || !this.gyroActive || this.gyroOffTimer !== -1) {
      return;
    }
    this.gyroOffTimer = setTimeout(() => {
      this.gyroOffTimer = -1;
      if (this.gyroHandlers.length > 0 || this.gyroSampleHandlers.length > 0 || !this.gyroActive) {
        return;
      }
      try {
        sensor.off(sensor.SensorId.GYROSCOPE, this.gyroCallback);
      } catch (err) {
        const e = err as BusinessError;
        audit('HUB_ERR', `off gyro ${e.code} ${e.message}`);
      }
      this.gyroActive = false;
      audit('HUB', 'gyro off');
    }, STOP_GRACE_MS);
  }

  unsubscribeGyro(handler: GyroHandler): void {
    this.gyroHandlers = this.gyroHandlers.filter((h: GyroHandler) => h !== handler);
    if (this.gyroHandlers.length > 0 || this.gyroSampleHandlers.length > 0
      || !this.gyroActive || this.gyroOffTimer !== -1) {
      return;
    }
    this.gyroOffTimer = setTimeout(() => {
      this.gyroOffTimer = -1;
      if (this.gyroHandlers.length > 0 || this.gyroSampleHandlers.length > 0 || !this.gyroActive) {
        return;
      }
      try {
        sensor.off(sensor.SensorId.GYROSCOPE, this.gyroCallback);
      } catch (err) {
        const e = err as BusinessError;
        audit('HUB_ERR', `off gyro ${e.code} ${e.message}`);
      }
      this.gyroActive = false;
      audit('HUB', 'gyro off');
    }, STOP_GRACE_MS);
  }

  subscribeMag(handler: MagHandler): void {
    this.magHandlers.push(handler);
    this.cancelMagStop();
    if (this.magActive) {
      return;
    }
    this.startMag();
  }

  unsubscribeMag(handler: MagHandler): void {
    this.magHandlers = this.magHandlers.filter((h: MagHandler) => h !== handler);
    if (this.magHandlers.length > 0 || !this.magActive || this.magOffTimer !== -1) {
      return;
    }
    this.magOffTimer = setTimeout(() => {
      this.magOffTimer = -1;
      if (this.magHandlers.length > 0 || !this.magActive) {
        return;
      }
      try {
        sensor.off(sensor.SensorId.MAGNETIC_FIELD, this.magCallback);
      } catch (err) {
        const e = err as BusinessError;
        audit('HUB_ERR', `off mag ${e.code} ${e.message}`);
      }
      this.magActive = false;
      audit('HUB', 'mag off');
    }, STOP_GRACE_MS);
  }

  subscribeRot(handler: RotHandler): void {
    this.rotHandlers.push(handler);
    this.cancelRotStop();
    if (this.rotActive) {
      return;
    }
    this.startRot();
  }

  subscribeRotSample(handler: RotationSampleHandler): void {
    this.rotSampleHandlers.push(handler);
    this.cancelRotStop();
    if (this.rotActive) {
      return;
    }
    this.startRot();
  }

  unsubscribeRotSample(handler: RotationSampleHandler): void {
    this.rotSampleHandlers = this.rotSampleHandlers.filter((h: RotationSampleHandler) => h !== handler);
    if (this.rotHandlers.length > 0 || this.rotSampleHandlers.length > 0
      || !this.rotActive || this.rotOffTimer !== -1) {
      return;
    }
    this.rotOffTimer = setTimeout(() => {
      this.rotOffTimer = -1;
      if (this.rotHandlers.length > 0 || this.rotSampleHandlers.length > 0 || !this.rotActive) {
        return;
      }
      try {
        sensor.off(sensor.SensorId.ROTATION_VECTOR, this.rotCallback);
      } catch (err) {
        const e = err as BusinessError;
        audit('HUB_ERR', `off rot ${e.code} ${e.message}`);
      }
      this.rotActive = false;
      audit('HUB', 'rot off');
    }, STOP_GRACE_MS);
  }

  unsubscribeRot(handler: RotHandler): void {
    this.rotHandlers = this.rotHandlers.filter((h: RotHandler) => h !== handler);
    if (this.rotHandlers.length > 0 || this.rotSampleHandlers.length > 0
      || !this.rotActive || this.rotOffTimer !== -1) {
      return;
    }
    this.rotOffTimer = setTimeout(() => {
      this.rotOffTimer = -1;
      if (this.rotHandlers.length > 0 || this.rotSampleHandlers.length > 0 || !this.rotActive) {
        return;
      }
      try {
        sensor.off(sensor.SensorId.ROTATION_VECTOR, this.rotCallback);
      } catch (err) {
        const e = err as BusinessError;
        audit('HUB_ERR', `off rot ${e.code} ${e.message}`);
      }
      this.rotActive = false;
      audit('HUB', 'rot off');
    }, STOP_GRACE_MS);
  }

  private cancelAccStop(): void {
    if (this.accOffTimer !== -1) {
      clearTimeout(this.accOffTimer);
      this.accOffTimer = -1;
      audit('HUB', 'acc stop cancelled');
    }
  }

  private cancelGyroStop(): void {
    if (this.gyroOffTimer !== -1) {
      clearTimeout(this.gyroOffTimer);
      this.gyroOffTimer = -1;
      audit('HUB', 'gyro stop cancelled');
    }
  }

  private cancelMagStop(): void {
    if (this.magOffTimer !== -1) {
      clearTimeout(this.magOffTimer);
      this.magOffTimer = -1;
      audit('HUB', 'mag stop cancelled');
    }
  }

  private cancelRotStop(): void {
    if (this.rotOffTimer !== -1) {
      clearTimeout(this.rotOffTimer);
      this.rotOffTimer = -1;
      audit('HUB', 'rot stop cancelled');
    }
  }

  private startAcc(): void {
    try {
      sensor.on(sensor.SensorId.ACCELEROMETER, this.accCallback, { interval: 100000000 });
      this.accActive = true;
      audit('HUB', 'acc on');
    } catch (err) {
      const e = err as BusinessError;
      audit('HUB_ERR', `acc ${e.code} ${e.message}`);
    }
  }

  private startGyro(): void {
    try {
      sensor.on(sensor.SensorId.GYROSCOPE, this.gyroCallback, { interval: 100000000 });
      this.gyroActive = true;
      audit('HUB', 'gyro on');
    } catch (err) {
      const e = err as BusinessError;
      audit('HUB_ERR', `gyro ${e.code} ${e.message}`);
    }
  }

  private startMag(): void {
    try {
      sensor.on(sensor.SensorId.MAGNETIC_FIELD, this.magCallback, { interval: 100000000 });
      this.magActive = true;
      audit('HUB', 'mag on');
    } catch (err) {
      const e = err as BusinessError;
      audit('HUB_ERR', `mag ${e.code} ${e.message}`);
    }
  }

  gyroStatsSnapshot(): SensorStats {
    return copyStats(this.gyroStats);
  }

  rotStatsSnapshot(): SensorStats {
    return copyStats(this.rotStats);
  }

  private startRot(): void {
    try {
      sensor.on(sensor.SensorId.ROTATION_VECTOR, this.rotCallback, { interval: 100000000 });
      this.rotActive = true;
      audit('HUB', 'rot on');
    } catch (err) {
      const e = err as BusinessError;
      audit('HUB_ERR', `rot ${e.code} ${e.message}`);
    }
  }
}

export const sensorHub: SensorHub = new SensorHub();
