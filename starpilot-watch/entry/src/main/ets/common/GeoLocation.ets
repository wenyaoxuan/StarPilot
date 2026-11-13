import { abilityAccessCtrl, common, PermissionRequestResult, Permissions } from '@kit.AbilityKit';
import { geoLocationManager } from '@kit.LocationKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { audit } from './AuditLog';

export interface GpsFix {
  latitude: number;
  longitude: number;
  altitude: number;
  accuracy: number;
  timestamp: number;
}

const PERM_APPROX: Permissions = 'ohos.permission.APPROXIMATELY_LOCATION';
const PERM_PRECISE: Permissions = 'ohos.permission.LOCATION';
const MAX_ACCURACY_M: number = 100;
const MAX_CACHED_AGE_MS: number = 15000;

function finite(v: number): boolean {
  return typeof v === 'number' && v === v && v !== Infinity && v !== -Infinity;
}

/**
 * Check the two grants independently. HarmonyOS needs both for precise location.
 */
async function ensurePermission(context: common.UIAbilityContext): Promise<void> {
  const atManager = abilityAccessCtrl.createAtManager();
  let result: PermissionRequestResult;
  try {
    result = await atManager.requestPermissionsFromUser(context, [PERM_APPROX, PERM_PRECISE]);
  } catch (err) {
    result = await atManager.requestPermissionsFromUser(context, [PERM_APPROX]);
  }
  const approximate: boolean = result.authResults[result.permissions.indexOf(PERM_APPROX)] === 0;
  const precise: boolean = result.authResults[result.permissions.indexOf(PERM_PRECISE)] === 0;
  audit('GPS_PERMISSION', `approx=${approximate};precise=${precise}`);
  if (!approximate) {
    throw new Error('定位权限未开启，请在手表设置中允许 StarPilot 使用位置');
  }
  if (!precise) {
    throw new Error('请在手表设置中允许精确位置，或手动选城市');
  }
}

/**
 * One-shot location fix. This is deliberately not a continuous GPS
 * subscription: the user taps "GPS 定位", we get one fix and reuse it.
 */
export async function getGpsFix(context: common.UIAbilityContext, onStatus: (text: string) => void): Promise<GpsFix> {
  await ensurePermission(context);
  if (!geoLocationManager.isLocationEnabled()) {
    throw new Error('系统定位已关闭，请在手表设置中开启');
  }
  onStatus('正在定位，室外开阔处更易搜星');
  const startedAt: number = Date.now();
  const request: geoLocationManager.CurrentLocationRequest = {
    priority: geoLocationManager.LocationRequestPriority.ACCURACY,
    scenario: geoLocationManager.LocationRequestScenario.UNSET,
    maxAccuracy: MAX_ACCURACY_M,
    timeoutMs: 45000
  };
  audit('GPS_REQUEST', 'accuracy');
  let loc: geoLocationManager.Location;
  try {
    loc = await geoLocationManager.getCurrentLocation(request);
  } catch (err) {
    const code: number = (err as BusinessError).code;
    audit('GPS_SERVICE_ERR', 'code=' + code);
    if (code === 201) {
      throw new Error('定位权限未开启，请在手表设置中检查');
    }
    if (code === 3301100) {
      throw new Error('系统定位已关闭，请在手表设置中开启');
    }
    if (code === 3301200) {
      throw new Error('未取得精确位置，请到室外重试或手动选城市');
    }
    throw new Error('定位服务暂不可用，可手动选城市');
  }
  if (!finite(loc.latitude) || !finite(loc.longitude)
    || loc.latitude < -90 || loc.latitude > 90
    || loc.longitude < -180 || loc.longitude > 180) {
    throw new Error('定位结果无效');
  }
  if (!finite(loc.timeStamp) || loc.timeStamp < startedAt - MAX_CACHED_AGE_MS ||
      loc.timeStamp > Date.now() + MAX_CACHED_AGE_MS) {
    audit('GPS_REJECT', 'stale or invalid timestamp');
    throw new Error('系统返回旧位置，请重试或手动选城市');
  }
  if (!finite(loc.accuracy) || loc.accuracy <= 0 || loc.accuracy > MAX_ACCURACY_M) {
    audit('GPS_REJECT', 'insufficient accuracy');
    throw new Error('定位精度不足，请到室外重试或手动选城市');
  }
  return {
    latitude: loc.latitude,
    longitude: loc.longitude,
    altitude: finite(loc.altitude) ? loc.altitude : -10000,
    accuracy: loc.accuracy,
    timestamp: loc.timeStamp
  };
}
