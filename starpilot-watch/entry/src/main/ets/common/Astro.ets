/**
 * StarPilot astronomy core.
 *
 * Pure math, no HarmonyOS imports: the same file is compiled into the watch
 * app and transpiled for the Node cross-validation harness.
 *
 * Coordinates:
 * - RA in hours (0..24), Dec in degrees (-90..+90)
 * - Azimuth from true north, clockwise (0..360)
 * - Altitude geometric, degrees
 * - Time: Unix ms (UTC) at the API boundary, Julian Date internally
 */

const DEG: number = Math.PI / 180;
const RAD: number = 180 / Math.PI;
const J2000: number = 2451545.0;
const SYNODIC_MONTH: number = 29.530588853;

export interface Equatorial {
  raHours: number;
  decDeg: number;
}

export interface Horizontal {
  azDeg: number;
  altDeg: number;
}

export interface MoonPosition extends Equatorial {
  distanceKm: number;
}

export interface LunarEcliptic {
  lambdaDeg: number;
  betaDeg: number;
  distanceKm: number;
}

export interface MoonPhase {
  illumination: number;
  elongationDeg: number;
  ageDays: number;
  phaseName: string;
  waxing: boolean;
}

export interface Twilight {
  eveningEndMs: number;
  morningStartMs: number;
}

export interface VisibleWindow {
  startMs: number;
  endMs: number;
  peakMs: number;
  peakAltDeg: number;
}

export interface RiseSet {
  riseMs: number;
  setMs: number;
  transitMs: number;
  maxAltDeg: number;
}

export function clamp(v: number, lo: number, hi: number): number {
  return v < lo ? lo : (v > hi ? hi : v);
}

export function norm360(deg: number): number {
  const r: number = deg % 360;
  return r < 0 ? r + 360 : r;
}

export function norm180(deg: number): number {
  const r: number = norm360(deg);
  return r > 180 ? r - 360 : r;
}

export function jdFromUnixMs(ms: number): number {
  return ms / 86400000 + 2440587.5;
}

export function unixMsFromJd(jd: number): number {
  return (jd - 2440587.5) * 86400000;
}

export function civilToUtcMs(year: number, month: number, day: number,
                            hour: number, minute: number, tzOffsetMinutes: number): number {
  return Date.UTC(year, month - 1, day, hour, minute) - tzOffsetMinutes * 60000;
}

/** Greenwich mean sidereal time, degrees. */
export function gmstDeg(jd: number): number {
  const T: number = (jd - J2000) / 36525;
  const gmst: number = 280.46061837 + 360.98564736629 * (jd - J2000)
    + 0.000387933 * T * T - T * T * T / 38710000;
  return norm360(gmst);
}

/** Local sidereal time, degrees (east longitude positive). */
export function lstDeg(jd: number, lonDeg: number): number {
  return norm360(gmstDeg(jd) + lonDeg);
}

/** Mean obliquity of the ecliptic, degrees. */
export function obliquityDeg(jd: number): number {
  const T: number = (jd - J2000) / 36525;
  return 23.439291 - 0.0130042 * T - 1.64e-7 * T * T + 5.04e-7 * T * T * T;
}

export function eclipticToEquatorial(lambdaDeg: number, betaDeg: number, jd: number): Equatorial {
  const eps: number = obliquityDeg(jd) * DEG;
  const l: number = lambdaDeg * DEG;
  const b: number = betaDeg * DEG;
  const x: number = Math.cos(b) * Math.cos(l);
  const y: number = Math.cos(b) * Math.sin(l) * Math.cos(eps) - Math.sin(b) * Math.sin(eps);
  const z: number = Math.cos(b) * Math.sin(l) * Math.sin(eps) + Math.sin(b) * Math.cos(eps);
  const out: Equatorial = {
    raHours: norm360(Math.atan2(y, x) * RAD) / 15,
    decDeg: Math.asin(clamp(z, -1, 1)) * RAD
  };
  return out;
}

/** Low-precision solar longitude (Meeus ch. 25), ~0.01 deg. */
export function sunEclipticLongitude(jd: number): number {
  const n: number = jd - J2000;
  const L: number = 280.460 + 0.9856474 * n;
  const g: number = (357.528 + 0.9856003 * n) * DEG;
  return norm360(L + 1.915 * Math.sin(g) + 0.020 * Math.sin(2 * g));
}

export function sunEquatorial(jd: number): Equatorial {
  return eclipticToEquatorial(sunEclipticLongitude(jd), 0, jd);
}

interface LunarLonTerm {
  d: number;
  m: number;
  mp: number;
  f: number;
  l: number;
  r: number;
}

interface LunarLatTerm {
  d: number;
  m: number;
  mp: number;
  f: number;
  b: number;
}

const LUNAR_LON: LunarLonTerm[] = [
  { d: 0, m: 0, mp: 1, f: 0, l: 6288774, r: -20905355 },
  { d: 2, m: 0, mp: -1, f: 0, l: 1274027, r: -3699111 },
  { d: 2, m: 0, mp: 0, f: 0, l: 658314, r: -2955968 },
  { d: 0, m: 0, mp: 2, f: 0, l: 213618, r: -569925 },
  { d: 0, m: 1, mp: 0, f: 0, l: -185116, r: 48888 },
  { d: 0, m: 0, mp: 0, f: 2, l: -114332, r: -3149 },
  { d: 2, m: 0, mp: -2, f: 0, l: 58793, r: 246158 },
  { d: 2, m: -1, mp: -1, f: 0, l: 57066, r: -152138 },
  { d: 2, m: 0, mp: 1, f: 0, l: 53322, r: -170733 },
  { d: 2, m: -1, mp: 0, f: 0, l: 45758, r: -204586 },
  { d: 0, m: 1, mp: -1, f: 0, l: -40923, r: -129620 },
  { d: 1, m: 0, mp: 0, f: 0, l: -34720, r: 108743 },
  { d: 0, m: 1, mp: 1, f: 0, l: -30383, r: 104755 },
  { d: 2, m: 0, mp: 0, f: -2, l: 15327, r: 10321 },
  { d: 0, m: 0, mp: 1, f: 2, l: -12528, r: 0 },
  { d: 0, m: 0, mp: 1, f: -2, l: 10980, r: 79661 },
  { d: 4, m: 0, mp: -1, f: 0, l: 10675, r: -34782 },
  { d: 0, m: 0, mp: 3, f: 0, l: 10034, r: -23210 },
  { d: 4, m: 0, mp: -2, f: 0, l: 8548, r: -21636 },
  { d: 2, m: 1, mp: -1, f: 0, l: -7888, r: 24208 },
  { d: 2, m: 1, mp: 0, f: 0, l: -6766, r: 30824 },
  { d: 1, m: 0, mp: -1, f: 0, l: -5163, r: -8379 },
  { d: 1, m: 1, mp: 0, f: 0, l: 4987, r: -16675 },
  { d: 2, m: -1, mp: 1, f: 0, l: 4036, r: -12831 },
  { d: 2, m: 0, mp: 2, f: 0, l: 3994, r: -10445 }
];

const LUNAR_LAT: LunarLatTerm[] = [
  { d: 0, m: 0, mp: 0, f: 1, b: 5128122 },
  { d: 0, m: 0, mp: 1, f: 1, b: 280602 },
  { d: 0, m: 0, mp: 1, f: -1, b: 277693 },
  { d: 2, m: 0, mp: 0, f: -1, b: 173237 },
  { d: 2, m: 0, mp: -1, f: 1, b: 55413 },
  { d: 2, m: 0, mp: -1, f: -1, b: 46271 },
  { d: 2, m: 0, mp: 0, f: 1, b: 32573 },
  { d: 0, m: 0, mp: 2, f: 1, b: 17198 },
  { d: 2, m: 0, mp: 1, f: -1, b: 9266 },
  { d: 0, m: 0, mp: 2, f: -1, b: 8822 },
  { d: 2, m: -1, mp: 0, f: -1, b: 8216 },
  { d: 2, m: 0, mp: -2, f: -1, b: 4324 },
  { d: 2, m: 0, mp: 1, f: 1, b: 4200 },
  { d: 2, m: 1, mp: 0, f: -1, b: -3359 },
  { d: 2, m: -1, mp: -1, f: 1, b: 2463 },
  { d: 2, m: -1, mp: 0, f: 1, b: 2211 },
  { d: 2, m: -1, mp: -1, f: -1, b: 2065 },
  { d: 0, m: 1, mp: -1, f: -1, b: -1870 },
  { d: 4, m: 0, mp: -1, f: -1, b: 1828 },
  { d: 0, m: 1, mp: 0, f: 1, b: -1794 },
  { d: 0, m: 0, mp: 0, f: 3, b: -1749 },
  { d: 0, m: 1, mp: -1, f: 1, b: -1565 },
  { d: 1, m: 0, mp: 0, f: 1, b: -1491 },
  { d: 0, m: 1, mp: 1, f: 1, b: -1475 }
];

/** Lunar ecliptic position (Meeus ch. 47 main periodic terms, ~0.1 deg). */
export function moonEcliptic(jd: number): LunarEcliptic {
  const T: number = (jd - J2000) / 36525;
  const Lp: number = norm360(218.3164477 + 481267.88123421 * T - 0.0015786 * T * T
    + T * T * T / 538841 - T * T * T * T / 65194000);
  const D: number = norm360(297.8501921 + 445267.1114034 * T - 0.0018819 * T * T
    + T * T * T / 545868 - T * T * T * T / 113065000);
  const M: number = norm360(357.5291092 + 35999.0502909 * T - 0.0001536 * T * T
    + T * T * T / 24490000);
  const Mp: number = norm360(134.9633964 + 477198.8675055 * T + 0.0087414 * T * T
    + T * T * T / 69699 - T * T * T * T / 14712000);
  const F: number = norm360(93.2720950 + 483202.0175233 * T - 0.0036539 * T * T
    - T * T * T / 3526000 + T * T * T * T / 863310000);

  const A1: number = (119.75 + 131.849 * T) * DEG;
  const A2: number = (53.09 + 479264.290 * T) * DEG;
  const A3: number = (313.45 + 481266.484 * T) * DEG;
  const E: number = 1 - 0.002516 * T - 0.0000074 * T * T;

  let sumL: number = 0;
  let sumR: number = 0;
  let sumB: number = 0;

  for (let i = 0; i < LUNAR_LON.length; i++) {
    const t: LunarLonTerm = LUNAR_LON[i];
    const arg: number = (t.d * D + t.m * M + t.mp * Mp + t.f * F) * DEG;
    const e: number = t.m === 0 ? 1 : (Math.abs(t.m) === 1 ? E : E * E);
    sumL += t.l * e * Math.sin(arg);
    sumR += t.r * e * Math.cos(arg);
  }
  for (let i = 0; i < LUNAR_LAT.length; i++) {
    const t: LunarLatTerm = LUNAR_LAT[i];
    const arg: number = (t.d * D + t.m * M + t.mp * Mp + t.f * F) * DEG;
    const e: number = t.m === 0 ? 1 : (Math.abs(t.m) === 1 ? E : E * E);
    sumB += t.b * e * Math.sin(arg);
  }

  sumL += 3958 * Math.sin(A1) + 1962 * Math.sin((Lp - F) * DEG) + 318 * Math.sin(A2);
  sumB += -2235 * Math.sin(Lp * DEG) + 382 * Math.sin(A3)
    + 175 * Math.sin((A1 - F) * DEG) + 175 * Math.sin((A1 + F) * DEG)
    + 127 * Math.sin((Lp - Mp) * DEG) - 115 * Math.sin((Lp + Mp) * DEG);

  const out: LunarEcliptic = {
    lambdaDeg: norm360(Lp + sumL / 1000000),
    betaDeg: sumB / 1000000,
    distanceKm: 385000.56 + sumR / 1000
  };
  return out;
}

export function moonEquatorial(jd: number): MoonPosition {
  const e: LunarEcliptic = moonEcliptic(jd);
  const eq: Equatorial = eclipticToEquatorial(e.lambdaDeg, e.betaDeg, jd);
  const out: MoonPosition = { raHours: eq.raHours, decDeg: eq.decDeg, distanceKm: e.distanceKm };
  return out;
}

export function angularSeparationDeg(a: Equatorial, b: Equatorial): number {
  const dRa: number = (a.raHours - b.raHours) * 15 * DEG;
  const d1: number = a.decDeg * DEG;
  const d2: number = b.decDeg * DEG;
  const cosSep: number = Math.sin(d1) * Math.sin(d2) + Math.cos(d1) * Math.cos(d2) * Math.cos(dRa);
  return Math.acos(clamp(cosSep, -1, 1)) * RAD;
}

export function moonPhase(jd: number): MoonPhase {
  const sun: Equatorial = sunEquatorial(jd);
  const moon: MoonPosition = moonEquatorial(jd);
  const elong: number = angularSeparationDeg(sun, moon);
  const illum: number = (1 - Math.cos(elong * DEG)) / 2;
  const age: number = elong / 360 * SYNODIC_MONTH;
  const out: MoonPhase = {
    illumination: illum,
    elongationDeg: elong,
    ageDays: age,
    phaseName: phaseName(elong),
    waxing: elong < 180
  };
  return out;
}

function phaseName(elongDeg: number): string {
  if (elongDeg < 22.5 || elongDeg >= 337.5) {
    return '新月';
  }
  if (elongDeg < 67.5) {
    return '娥眉月';
  }
  if (elongDeg < 112.5) {
    return '上弦月';
  }
  if (elongDeg < 157.5) {
    return '盈凸月';
  }
  if (elongDeg < 202.5) {
    return '满月';
  }
  if (elongDeg < 247.5) {
    return '亏凸月';
  }
  if (elongDeg < 292.5) {
    return '下弦月';
  }
  return '残月';
}

/** Precess a J2000 position to the date of `jd` (IAU 1976). */
export function precessFromJ2000(raHours: number, decDeg: number, jd: number): Equatorial {
  const T: number = (jd - J2000) / 36525;
  const zeta: number = (2306.2181 * T + 0.30188 * T * T + 0.017998 * T * T * T) / 3600;
  const z: number = (2306.2181 * T + 1.09468 * T * T + 0.018203 * T * T * T) / 3600;
  const theta: number = (2004.3109 * T - 0.42665 * T * T - 0.041833 * T * T * T) / 3600;

  const ra: number = raHours * 15 * DEG;
  const dec: number = decDeg * DEG;
  const A: number = Math.cos(dec) * Math.sin(ra + zeta * DEG);
  const B: number = Math.cos(theta * DEG) * Math.cos(dec) * Math.cos(ra + zeta * DEG)
    - Math.sin(theta * DEG) * Math.sin(dec);
  const C: number = Math.sin(theta * DEG) * Math.cos(dec) * Math.cos(ra + zeta * DEG)
    + Math.cos(theta * DEG) * Math.sin(dec);

  const out: Equatorial = {
    raHours: norm360(Math.atan2(A, B) * RAD + z) / 15,
    decDeg: Math.asin(clamp(C, -1, 1)) * RAD
  };
  return out;
}

export function equatorialToHorizontal(eq: Equatorial, jd: number,
                                       latDeg: number, lonDeg: number): Horizontal {
  const H: number = norm180(lstDeg(jd, lonDeg) - eq.raHours * 15) * DEG;
  const dec: number = eq.decDeg * DEG;
  const lat: number = latDeg * DEG;

  const east: number = -Math.cos(dec) * Math.sin(H);
  const north: number = Math.sin(dec) * Math.cos(lat) - Math.cos(dec) * Math.sin(lat) * Math.cos(H);
  const up: number = Math.sin(dec) * Math.sin(lat) + Math.cos(dec) * Math.cos(lat) * Math.cos(H);

  const out: Horizontal = {
    azDeg: norm360(Math.atan2(east, north) * RAD),
    altDeg: Math.asin(clamp(up, -1, 1)) * RAD
  };
  return out;
}

/** Bennett refraction, degrees; negligible above 10 deg. */
export function refractionDeg(altDeg: number): number {
  if (altDeg < -1 || altDeg > 89.9) {
    return 0;
  }
  const r: number = 1.02 / Math.tan((altDeg + 10.3 / (altDeg + 5.11)) * DEG) / 60;
  return r > 0 ? r : 0;
}

export function sunAltitude(jd: number, latDeg: number, lonDeg: number): number {
  return equatorialToHorizontal(sunEquatorial(jd), jd, latDeg, lonDeg).altDeg;
}

export function moonAltitude(jd: number, latDeg: number, lonDeg: number): number {
  return equatorialToHorizontal(moonEquatorial(jd), jd, latDeg, lonDeg).altDeg;
}

export function targetHorizontal(targetJ2000: Equatorial, jd: number,
                                 latDeg: number, lonDeg: number): Horizontal {
  const eq: Equatorial = precessFromJ2000(targetJ2000.raHours, targetJ2000.decDeg, jd);
  return equatorialToHorizontal(eq, jd, latDeg, lonDeg);
}

function findCrossings(startMs: number, endMs: number, stepMs: number,
                       fn: (ms: number) => number): number[] {
  const out: number[] = [];
  let prevT: number = startMs;
  let prevV: number = fn(prevT);
  for (let t = startMs + stepMs; t <= endMs; t += stepMs) {
    const v: number = fn(t);
    if (prevV === 0) {
      out.push(prevT);
    } else if ((prevV < 0 && v > 0) || (prevV > 0 && v < 0)) {
      let lo: number = prevT;
      let hi: number = t;
      const loSign: number = prevV < 0 ? -1 : 1;
      for (let i = 0; i < 40; i++) {
        const mid: number = (lo + hi) / 2;
        const mv: number = fn(mid);
        if ((mv < 0 ? -1 : 1) === loSign) {
          lo = mid;
        } else {
          hi = mid;
        }
      }
      out.push((lo + hi) / 2);
    }
    prevT = t;
    prevV = v;
  }
  return out;
}

/**
 * Astronomical twilight for the night that starts at the given local midnight.
 * Returns zeros if the sun never reaches -18 deg (polar day/night).
 */
export function astronomicalTwilight(localMidnightMs: number, latDeg: number,
                                     lonDeg: number): Twilight {
  const noon: number = localMidnightMs + 12 * 3600000;
  const crossings: number[] = findCrossings(noon, noon + 24 * 3600000, 5 * 60000,
    (ms: number) => sunAltitude(jdFromUnixMs(ms), latDeg, lonDeg) + 18);

  let evening: number = 0;
  let morning: number = 0;
  for (let i = 0; i < crossings.length; i++) {
    const t: number = crossings[i];
    const alt: number = sunAltitude(jdFromUnixMs(t), latDeg, lonDeg);
    const before: number = sunAltitude(jdFromUnixMs(t - 5 * 60000), latDeg, lonDeg);
    const goingDown: boolean = alt < before;
    if (goingDown && evening === 0 && t > localMidnightMs - 12 * 3600000) {
      evening = t;
    } else if (!goingDown && evening !== 0 && morning === 0) {
      morning = t;
    }
  }
  const out: Twilight = { eveningEndMs: evening, morningStartMs: morning };
  return out;
}

export function sunRiseSet(localMidnightMs: number, latDeg: number,
                           lonDeg: number): RiseSet {
  return bodyRiseSet('sun', localMidnightMs, latDeg, lonDeg, 0);
}

export function moonRiseSet(localMidnightMs: number, latDeg: number,
                            lonDeg: number): RiseSet {
  return bodyRiseSet('moon', localMidnightMs, latDeg, lonDeg, 0);
}

function bodyRiseSet(body: string, localMidnightMs: number, latDeg: number,
                     lonDeg: number, minAlt: number): RiseSet {
  const start: number = localMidnightMs;
  const end: number = localMidnightMs + 30 * 3600000;
  const step: number = 2 * 60000;
  let rise: number = 0;
  let set: number = 0;
  let transit: number = start;
  let maxAlt: number = -90;

  let prevT: number = start;
  let prevAlt: number = bodyAltitude(body, prevT, latDeg, lonDeg) - minAlt;
  for (let t = start + step; t <= end; t += step) {
    const alt: number = bodyAltitude(body, t, latDeg, lonDeg);
    const v: number = alt - minAlt;
    if (alt > maxAlt) {
      maxAlt = alt;
      transit = t;
    }
    if (prevAlt < 0 && v >= 0 && rise === 0) {
      rise = bisectAltitude(body, prevT, t, latDeg, lonDeg, minAlt);
    }
    if (prevAlt > 0 && v <= 0 && set === 0 && rise !== 0) {
      set = bisectAltitude(body, prevT, t, latDeg, lonDeg, minAlt);
    }
    prevT = t;
    prevAlt = v;
  }
  const out: RiseSet = { riseMs: rise, setMs: set, transitMs: transit, maxAltDeg: maxAlt };
  return out;
}

function bodyAltitude(body: string, ms: number, latDeg: number, lonDeg: number): number {
  const jd: number = jdFromUnixMs(ms);
  if (body === 'sun') {
    return sunAltitude(jd, latDeg, lonDeg);
  }
  if (body === 'moon') {
    return moonAltitude(jd, latDeg, lonDeg);
  }
  return 0;
}

function bisectAltitude(body: string, lo: number, hi: number, latDeg: number,
                        lonDeg: number, minAlt: number): number {
  const loUp: boolean = bodyAltitude(body, lo, latDeg, lonDeg) >= minAlt;
  for (let i = 0; i < 40; i++) {
    const mid: number = (lo + hi) / 2;
    const up: boolean = bodyAltitude(body, mid, latDeg, lonDeg) >= minAlt;
    if (up === loUp) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return (lo + hi) / 2;
}

/** Build a 1-degree mask from evenly spaced sector heights. */
export function maskFromSectors(sectors: number[]): number[] {
  const out: number[] = [];
  if (sectors.length === 0) {
    return out;
  }
  const width: number = 360 / sectors.length;
  for (let az = 0; az < 360; az++) {
    const idx: number = Math.floor(az / width) % sectors.length;
    out.push(sectors[idx]);
  }
  return out;
}

export function horizonMaskAt(mask: number[], azDeg: number): number {
  if (mask.length === 0) {
    return 0;
  }
  const n: number = mask.length;
  const pos: number = norm360(azDeg) / 360 * n;
  const i0: number = Math.floor(pos) % n;
  const i1: number = (i0 + 1) % n;
  const f: number = pos - Math.floor(pos);
  return mask[i0] * (1 - f) + mask[i1] * f;
}

/**
 * All intervals in the next 24 h where the target clears the horizon mask and
 * the sun is below -18 deg. Empty mask = flat horizon.
 */
export function targetVisibleWindows(targetJ2000: Equatorial, localMidnightMs: number,
                                     latDeg: number, lonDeg: number, mask: number[],
                                     minAltDeg: number): VisibleWindow[] {
  // Cover the observing night: local noon -> next local noon.
  const start: number = localMidnightMs - 12 * 3600000;
  const end: number = start + 24 * 3600000;
  const step: number = 2 * 60000;
  const out: VisibleWindow[] = [];

  let inWindow: boolean = false;
  let winStart: number = 0;
  let peakMs: number = 0;
  let peakAlt: number = -90;

  for (let t = start; t <= end; t += step) {
    const jd: number = jdFromUnixMs(t);
    const sunAlt: number = sunAltitude(jd, latDeg, lonDeg);
    const h: Horizontal = targetHorizontal(targetJ2000, jd, latDeg, lonDeg);
    const needed: number = Math.max(minAltDeg, horizonMaskAt(mask, h.azDeg));
    const visible: boolean = sunAlt <= -18 && h.altDeg >= needed;

    if (visible && !inWindow) {
      inWindow = true;
      winStart = t;
      peakMs = t;
      peakAlt = h.altDeg;
    } else if (visible && inWindow) {
      if (h.altDeg > peakAlt) {
        peakAlt = h.altDeg;
        peakMs = t;
      }
    } else if (!visible && inWindow) {
      const w: VisibleWindow = { startMs: winStart, endMs: t, peakMs: peakMs, peakAltDeg: peakAlt };
      out.push(w);
      inWindow = false;
    }
  }
  if (inWindow) {
    const w: VisibleWindow = { startMs: winStart, endMs: end, peakMs: peakMs, peakAltDeg: peakAlt };
    out.push(w);
  }
  return out;
}

export function longestWindow(windows: VisibleWindow[]): VisibleWindow | null {
  if (windows.length === 0) {
    return null;
  }
  let best: VisibleWindow = windows[0];
  for (let i = 1; i < windows.length; i++) {
    if (windows[i].endMs - windows[i].startMs > best.endMs - best.startMs) {
      best = windows[i];
    }
  }
  return best;
}
