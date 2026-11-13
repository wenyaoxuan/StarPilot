import {
  angularSeparationDeg, clamp, eclipticToEquatorial, Equatorial, equatorialToHorizontal,
  horizonMaskAt, Horizontal, jdFromUnixMs, moonEquatorial, norm180, norm360, precessFromJ2000,
  sunEclipticLongitude, sunEquatorial
} from './Astro';
import { METEOR_FIRST_YEAR, METEOR_LAST_YEAR, MeteorShower } from '../data/MeteorShowers';

const HOUR: number = 3600000;
const DAY: number = 24 * HOUR;
const DEG: number = Math.PI / 180;
const HALF_HOUR: number = HOUR / 2;

export interface MeteorSite {
  readonly lat: number;
  readonly lon: number;
  readonly mask: number[];
}

export interface MeteorSample {
  readonly ms: number;
  readonly active: boolean;
  readonly radiant: Horizontal;
  readonly sunAlt: number;
  readonly moonAlt: number;
  readonly illumination: number;
  readonly moonSeparation: number;
  readonly clearsMask: boolean;
  readonly driftApplied: boolean;
  readonly darkWindow: boolean;
}

export interface MeteorWindow {
  readonly from: number;
  readonly until: number;
}

export function meteorActive(shower: MeteorShower, ms: number): boolean {
  const date: Date = new Date(ms);
  const mmdd: number = (date.getUTCMonth() + 1) * 100 + date.getUTCDate();
  if (shower.start <= shower.end) {
    return mmdd >= shower.start && mmdd <= shower.end;
  }
  return mmdd >= shower.start || mmdd <= shower.end;
}

export function meteorSeasonYear(shower: MeteorShower, ms: number): number {
  const date: Date = new Date(ms);
  const mmdd: number = (date.getUTCMonth() + 1) * 100 + date.getUTCDate();
  return date.getUTCFullYear() + (shower.start > shower.end && mmdd >= shower.start ? 1 : 0);
}

export function meteorPeakDay(shower: MeteorShower, year: number): number | null {
  if (year < METEOR_FIRST_YEAR || year > METEOR_LAST_YEAR) {
    return null;
  }
  const day: number = year === METEOR_FIRST_YEAR ? shower.peak2026 : shower.peak2027;
  return Date.UTC(year, shower.peakMonth - 1, day);
}

export function meteorNextPeakDay(shower: MeteorShower, now: number): number | null {
  const year: number = meteorSeasonYear(shower, now);
  const peak: number | null = meteorPeakDay(shower, year);
  if (peak === null || now < peak + DAY || meteorActive(shower, now)) {
    return peak;
  }
  return meteorPeakDay(shower, year + 1);
}

export function meteorSample(shower: MeteorShower, ms: number, site: MeteorSite): MeteorSample {
  const jd: number = jdFromUnixMs(ms);
  // IMO longitudes are J2000. Approximate the general precession in longitude for these seasons.
  const longitudeJ2000: number = sunEclipticLongitude(jd) - (jd - 2451545) / 365.25 * 0.01397;
  const offset: number = norm180(longitudeJ2000 - shower.longitude);
  const active: boolean = meteorActive(shower, ms);
  const drift: boolean = active && offset >= shower.driftStart && offset <= shower.driftEnd;
  const correction: number = active ? clamp(offset, shower.driftStart, shower.driftEnd) : 0;
  const eq: Equatorial = precessFromJ2000(norm360(shower.raDeg + correction * shower.driftRa) / 15,
    clamp(shower.decDeg + correction * shower.driftDec, -90, 90), jd);
  const sun: Equatorial = sunEquatorial(jd);
  const moon: Equatorial = moonEquatorial(jd);
  const radiant: Horizontal = equatorialToHorizontal(eq, jd, site.lat, site.lon);
  const sunAlt: number = equatorialToHorizontal(sun, jd, site.lat, site.lon).altDeg;
  const moonAlt: number = equatorialToHorizontal(moon, jd, site.lat, site.lon).altDeg;
  const illumination: number = (1 - Math.cos(angularSeparationDeg(sun, moon) * DEG)) / 2;
  const clears: boolean = radiant.altDeg > Math.max(0, horizonMaskAt(site.mask, radiant.azDeg));
  return {
    ms: ms, active: active, radiant: radiant, sunAlt: sunAlt, moonAlt: moonAlt, illumination: illumination,
    moonSeparation: angularSeparationDeg(eq, moon), clearsMask: clears, driftApplied: drift,
    darkWindow: active && sunAlt <= -18 && clears
  };
}

export function meteorCurve(shower: MeteorShower, from: number, site: MeteorSite): MeteorSample[] {
  const samples: MeteorSample[] = [];
  for (let i = 0; i <= 48; i++) {
    samples.push(meteorSample(shower, from + i * HALF_HOUR, site));
  }
  return samples;
}

// Report only intervals bracketed by qualifying samples. A sub-30-minute window may be missed.
export function meteorWindows(samples: MeteorSample[]): MeteorWindow[] {
  const windows: MeteorWindow[] = [];
  let start: number = -1;
  for (let i = 1; i < samples.length; i++) {
    if (samples[i - 1].darkWindow && samples[i].darkWindow) {
      if (start < 0) {
        start = i - 1;
      }
    } else if (start >= 0) {
      windows.push({ from: samples[start].ms, until: samples[i - 1].ms });
      start = -1;
    }
  }
  if (start >= 0) {
    windows.push({ from: samples[start].ms, until: samples[samples.length - 1].ms });
  }
  return windows;
}
