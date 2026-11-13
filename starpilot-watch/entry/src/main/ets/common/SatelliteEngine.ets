import { clamp, Equatorial, gmstDeg, jdFromUnixMs, norm360, sunAltitude, sunEquatorial } from './Astro';
import { NearEarthSgp4, OrbitVector, TemeState } from './Sgp4NearEarth';
import { MAX_ISS_AGE_MS } from './SatelliteOrbit';

const DEG: number = Math.PI / 180;
const EARTH_KM: number = 6378.137;
const WGS84_E2: number = 0.00669437999014;
const SEARCH_STEP: number = 20000;
const HALF_HOUR: number = 1800000;
const DAY: number = 86400000;

export interface PassSite {
  readonly lat: number;
  readonly lon: number;
  readonly altitudeM: number;
}

export interface LookAngle {
  readonly alt: number;
  readonly az: number;
  readonly rangeKm: number;
}

export interface IssPass {
  readonly aos: number;
  readonly peak: number;
  readonly los: number;
  readonly riseAz: number;
  readonly maxAlt: number;
  readonly peakAz: number;
  readonly setAz: number;
  readonly possiblyVisible: boolean;
}

export function satelliteLook(position: OrbitVector, ms: number, site: PassSite): LookAngle {
  const theta: number = gmstDeg(jdFromUnixMs(ms)) * DEG;
  const x: number = Math.cos(theta) * position.x + Math.sin(theta) * position.y;
  const y: number = -Math.sin(theta) * position.x + Math.cos(theta) * position.y;
  const lat: number = site.lat * DEG;
  const lon: number = site.lon * DEG;
  const sinLat: number = Math.sin(lat);
  const cosLat: number = Math.cos(lat);
  const sinLon: number = Math.sin(lon);
  const cosLon: number = Math.cos(lon);
  const n: number = EARTH_KM / Math.sqrt(1 - WGS84_E2 * sinLat * sinLat);
  const height: number = site.altitudeM / 1000;
  const dx: number = x - (n + height) * cosLat * cosLon;
  const dy: number = y - (n + height) * cosLat * sinLon;
  const dz: number = position.z - (n * (1 - WGS84_E2) + height) * sinLat;
  const meridian: number = dx * cosLon + dy * sinLon;
  const east: number = -dx * sinLon + dy * cosLon;
  const north: number = -sinLat * meridian + cosLat * dz;
  const up: number = cosLat * meridian + sinLat * dz;
  return {
    az: norm360(Math.atan2(east, north) / DEG),
    alt: Math.atan2(up, Math.sqrt(east * east + north * north)) / DEG,
    rangeKm: Math.sqrt(east * east + north * north + up * up)
  };
}

export function sunlit(position: OrbitVector, jd: number): boolean {
  const sun: Equatorial = sunEquatorial(jd);
  const ra: number = sun.raHours * 15 * DEG;
  const dec: number = sun.decDeg * DEG;
  // Mean-of-date Sun as a TEME approximation. Reject partial shadow as well as umbra.
  const au: number = 149597870.7;
  const x: number = au * Math.cos(dec) * Math.cos(ra) - position.x;
  const y: number = au * Math.cos(dec) * Math.sin(ra) - position.y;
  const z: number = au * Math.sin(dec) - position.z;
  const sunDistance: number = Math.sqrt(x * x + y * y + z * z);
  const r: number = Math.sqrt(position.x * position.x + position.y * position.y + position.z * position.z);
  const cosSep: number = -(position.x * x + position.y * y + position.z * z) / (r * sunDistance);
  return Math.acos(clamp(cosSep, -1, 1)) >
    Math.asin(clamp(EARTH_KM / r, 0, 1)) + Math.asin(695700 / sunDistance);
}

function lookAt(model: NearEarthSgp4, time: number, site: PassSite): LookAngle {
  const state: TemeState | null = model.at(time);
  if (state === null) {
    throw new Error('SGP4 无法传播该轨道');
  }
  return satelliteLook(state.position, time, site);
}

function visibleDuring(model: NearEarthSgp4, from: number, until: number, site: PassSite): boolean {
  for (let time = from; time <= until; time += 15000) {
    const jd: number = jdFromUnixMs(time);
    if (sunAltitude(jd, site.lat, site.lon) <= -6) {
      const state: TemeState | null = model.at(time);
      if (state !== null && sunlit(state.position, jd)) {
        return true;
      }
    }
  }
  return false;
}

function refinePeak(model: NearEarthSgp4, left: number, right: number, site: PassSite): number {
  while (right - left > 500) {
    const a: number = left + (right - left) / 3;
    const b: number = right - (right - left) / 3;
    if (lookAt(model, a, site).alt < lookAt(model, b, site).alt) {
      left = a;
    } else {
      right = b;
    }
  }
  return (left + right) / 2;
}

function crossThreshold(model: NearEarthSgp4, peak: number, limit: number, threshold: number,
                        site: PassSite): number | null {
  const sign: number = limit < peak ? -1 : 1;
  let inside: number = peak;
  let outside: number = peak;
  while (outside !== limit) {
    outside = sign < 0 ? Math.max(limit, inside - SEARCH_STEP) : Math.min(limit, inside + SEARCH_STEP);
    if (lookAt(model, outside, site).alt <= threshold) {
      while (Math.abs(outside - inside) > 500) {
        const mid: number = (outside + inside) / 2;
        if (lookAt(model, mid, site).alt > threshold) {
          inside = mid;
        } else {
          outside = mid;
        }
      }
      return (outside + inside) / 2;
    }
    inside = outside;
  }
  return null;
}

/** Scan local maxima even if both coarse neighbors are below the chosen threshold. */
export function nextIssPass(model: NearEarthSgp4, now: number, site: PassSite, threshold: number): IssPass | null {
  const start: number = now - HALF_HOUR;
  const end: number = Math.min(now + DAY, model.epochMs + MAX_ISS_AGE_MS);
  if (end <= now) {
    return null;
  }
  let leftTime: number = start;
  let centerTime: number = start + SEARCH_STEP;
  let left: number = lookAt(model, leftTime, site).alt;
  let center: number = lookAt(model, centerTime, site).alt;
  while (centerTime < end) {
    const rightTime: number = Math.min(end, centerTime + SEARCH_STEP);
    const right: number = lookAt(model, rightTime, site).alt;
    if (center >= left && center >= right) {
      const peak: number = refinePeak(model, leftTime, rightTime, site);
      const atPeak: LookAngle = lookAt(model, peak, site);
      if (atPeak.alt > threshold + 1e-6) {
        const aos: number | null = crossThreshold(model, peak, start, threshold, site);
        const los: number | null = crossThreshold(model, peak, end, threshold, site);
        if (aos !== null && los !== null && los > now) {
          return {
            aos: aos, peak: peak, los: los, riseAz: lookAt(model, aos, site).az,
            maxAlt: atPeak.alt, peakAz: atPeak.az, setAz: lookAt(model, los, site).az,
            possiblyVisible: visibleDuring(model, Math.max(now, aos), los, site)
          };
        }
      }
    }
    left = center;
    center = right;
    leftTime = centerTime;
    centerTime = rightTime;
  }
  return null;
}
