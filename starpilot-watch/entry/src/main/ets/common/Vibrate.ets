import { vibrator } from '@kit.SensorServiceKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { audit } from './AuditLog';

/**
 * Watch 5 does not support the usual preset ids (haptic.notice.success).
 * A timed vibration is the only reliable alert path we verified on hardware.
 */
export function vibrateAlert(ms: number): void {
  try {
    vibrator.startVibration({ type: 'time', duration: ms }, { usage: 'notification' },
      (e: BusinessError) => {
        if (e) {
          audit('VIBRATE', `time ${ms} err ${e.code}`);
        } else {
          audit('VIBRATE', `time ${ms} ok`);
        }
      });
  } catch (err) {
    audit('VIBRATE', `time ${ms} throw ${JSON.stringify(err)}`);
  }
}
