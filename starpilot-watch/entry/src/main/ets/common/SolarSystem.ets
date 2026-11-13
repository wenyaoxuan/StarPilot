import {
  Equatorial,
  Horizontal,
  VisibleWindow,
  eclipticToEquatorial,
  equatorialToHorizontal,
  horizonMaskAt,
  lstDeg,
  moonEquatorial,
  MoonPosition,
  moonPhase,
  norm360,
  sunAltitude,
  sunEclipticLongitude,
  sunEquatorial
} from './Astro';

const DEG: number = Math.PI / 180;
const RAD: number = 180 / Math.PI;
const AU_KM: number = 149597870.7;
const EARTH_RADIUS_KM: number = 6378.14;
const LIGHT_TIME_DAYS_PER_AU: number = 0.0057755183;

export interface SolarBody {
  id: string;
  name: string;
  nameEn: string;
  type: string;
  aliases: string[];
  desc: string;
}

export interface SolarPosition extends Equatorial {
  distanceAu: number;
  distanceKm: number;
  angularSizeArcmin: number;
  illumination: number;
  phaseAngleDeg: number;
  phaseName: string;
  magnitude: number;
  magKnown: boolean;
}

export const SOLAR_BODIES: SolarBody[] = [
  {
    id: 'SUN',
    name: '太阳',
    nameEn: 'Sun',
    type: '恒星',
    aliases: ['太阳', '日', 'Sun', 'SUN'],
    desc: '太阳。严禁直视或直接拍摄未加巴德膜的太阳；观测/拍摄必须使用合格太阳滤镜。'
  },
  {
    id: 'MOON',
    name: '月球',
    nameEn: 'Moon',
    type: '天然卫星',
    aliases: ['月球', '月亮', '月', 'Moon', 'Luna', 'MOON'],
    desc: '地球唯一天然卫星；相位和距离变化明显。'
  },
  {
    id: 'MERCURY',
    name: '水星',
    nameEn: 'Mercury',
    type: '行星',
    aliases: ['水星', 'Mercury', 'MERCURY', '辰星'],
    desc: '离太阳最近，常淹没在暮光中。'
  },
  {
    id: 'VENUS',
    name: '金星',
    nameEn: 'Venus',
    type: '行星',
    aliases: ['金星', 'Venus', 'VENUS', '太白', '启明星', '长庚星'],
    desc: '最亮的行星，常在日出前或日落后可见。'
  },
  {
    id: 'MARS',
    name: '火星',
    nameEn: 'Mars',
    type: '行星',
    aliases: ['火星', 'Mars', 'MARS', '荧惑'],
    desc: '红色行星，冲日前后最适合拍摄。'
  },
  {
    id: 'JUPITER',
    name: '木星',
    nameEn: 'Jupiter',
    type: '行星',
    aliases: ['木星', 'Jupiter', 'JUPITER', '岁星'],
    desc: '最大的行星，四颗伽利略卫星可用长焦分辨。'
  },
  {
    id: 'SATURN',
    name: '土星',
    nameEn: 'Saturn',
    type: '行星',
    aliases: ['土星', 'Saturn', 'SATURN', '镇星'],
    desc: '环系行星，长焦下可见光环。'
  },
  {
    id: 'URANUS',
    name: '天王星',
    nameEn: 'Uranus',
    type: '行星',
    aliases: ['天王星', 'Uranus', 'URANUS'],
    desc: '暗弱的冰巨星，需要星图辅助定位。'
  },
  {
    id: 'NEPTUNE',
    name: '海王星',
    nameEn: 'Neptune',
    type: '行星',
    aliases: ['海王星', 'Neptune', 'NEPTUNE'],
    desc: '最远的行星，肉眼不可见。'
  }
];

interface Vec3 {
  x: number;
  y: number;
  z: number;
}

interface Elements {
  n: number;
  i: number;
  w: number;
  a: number;
  e: number;
  m: number;
}

interface Helio {
  lonDeg: number;
  latDeg: number;
  rAu: number;
}

interface Geo {
  lonDeg: number;
  latDeg: number;
  distanceAu: number;
}

function bodyById(id: string): SolarBody | null {
  for (let i = 0; i < SOLAR_BODIES.length; i++) {
    if (SOLAR_BODIES[i].id === id) {
      return SOLAR_BODIES[i];
    }
  }
  return null;
}

export function isSolarId(id: string): boolean {
  return bodyById(id) !== null;
}

export function solarBody(id: string): SolarBody | null {
  return bodyById(id);
}

function elementsOf(id: string, jd: number): Elements | null {
  // Paul Schlyter low-precision elements, referenced to 2000 Jan 0.0.
  const d: number = jd - 2451543.5;
  if (id === 'MERCURY') {
    return {
      n: 48.3313 + 3.24587e-5 * d,
      i: 7.0047 + 5.00e-8 * d,
      w: 29.1241 + 1.01444e-5 * d,
      a: 0.387098,
      e: 0.205635 + 5.59e-10 * d,
      m: 168.6562 + 4.0923344368 * d
    };
  }
  if (id === 'VENUS') {
    return {
      n: 76.6799 + 2.46590e-5 * d,
      i: 3.3946 + 2.75e-8 * d,
      w: 54.8910 + 1.38374e-5 * d,
      a: 0.723330,
      e: 0.006773 - 1.302e-9 * d,
      m: 48.0052 + 1.6021302244 * d
    };
  }
  if (id === 'MARS') {
    return {
      n: 49.5574 + 2.11081e-5 * d,
      i: 1.8497 - 1.78e-8 * d,
      w: 286.5016 + 2.92961e-5 * d,
      a: 1.523688,
      e: 0.093405 + 2.516e-9 * d,
      m: 18.6021 + 0.5240207766 * d
    };
  }
  if (id === 'JUPITER') {
    return {
      n: 100.4542 + 2.76854e-5 * d,
      i: 1.3030 - 1.557e-7 * d,
      w: 273.8777 + 1.64505e-5 * d,
      a: 5.20256,
      e: 0.048498 + 4.469e-9 * d,
      m: 19.8950 + 0.0830853001 * d
    };
  }
  if (id === 'SATURN') {
    return {
      n: 113.6634 + 2.38980e-5 * d,
      i: 2.4886 - 1.081e-7 * d,
      w: 339.3939 + 2.97661e-5 * d,
      a: 9.55475,
      e: 0.055546 - 9.499e-9 * d,
      m: 316.9670 + 0.0334442282 * d
    };
  }
  if (id === 'URANUS') {
    return {
      n: 74.0005 + 1.3978e-5 * d,
      i: 0.7733 + 1.9e-8 * d,
      w: 96.6612 + 3.0565e-5 * d,
      a: 19.18171 - 1.55e-8 * d,
      e: 0.047318 + 7.45e-9 * d,
      m: 142.5905 + 0.011725806 * d
    };
  }
  if (id === 'NEPTUNE') {
    return {
      n: 131.7806 + 3.0173e-5 * d,
      i: 1.7700 - 2.55e-7 * d,
      w: 272.8461 - 6.027e-6 * d,
      a: 30.05826 + 3.313e-8 * d,
      e: 0.008606 + 2.15e-9 * d,
      m: 260.2471 + 0.005995147 * d
    };
  }
  return null;
}

function solveKepler(mDeg: number, e: number): number {
  const m: number = norm360(mDeg) * DEG;
  let E: number = m + e * Math.sin(m) * (1 + e * Math.cos(m));
  for (let k = 0; k < 12; k++) {
    const dE: number = (E - e * Math.sin(E) - m) / (1 - e * Math.cos(E));
    E -= dE;
    if (Math.abs(dE) < 1e-10) {
      break;
    }
  }
  return E;
}

function helioOf(id: string, jd: number): Helio | null {
  const el: Elements | null = elementsOf(id, jd);
  if (el === null) {
    return null;
  }
  const E: number = solveKepler(el.m, el.e);
  const v: number = Math.atan2(Math.sqrt(1 - el.e * el.e) * Math.sin(E), Math.cos(E) - el.e);
  const r: number = el.a * (1 - el.e * Math.cos(E));
  const n: number = el.n * DEG;
  const inc: number = el.i * DEG;
  const u: number = v + el.w * DEG;
  const xh: number = r * (Math.cos(n) * Math.cos(u) - Math.sin(n) * Math.sin(u) * Math.cos(inc));
  const yh: number = r * (Math.sin(n) * Math.cos(u) + Math.cos(n) * Math.sin(u) * Math.cos(inc));
  const zh: number = r * Math.sin(u) * Math.sin(inc);
  let lon: number = norm360(Math.atan2(yh, xh) * RAD);
  let lat: number = Math.atan2(zh, Math.sqrt(xh * xh + yh * yh)) * RAD;

  // Main mutual perturbations for the outer planets (Schlyter).
  const d: number = jd - 2451543.5;
  const mj: number = (19.8950 + 0.0830853001 * d) * DEG;
  const ms: number = (316.9670 + 0.0334442282 * d) * DEG;
  const mu: number = (142.5905 + 0.011725806 * d) * DEG;
  if (id === 'JUPITER') {
    lon += -0.332 * Math.sin(2 * mj - 5 * ms - 67.6 * DEG)
      - 0.056 * Math.sin(2 * mj - 2 * ms + 21 * DEG)
      + 0.042 * Math.sin(3 * mj - 5 * ms + 21 * DEG)
      - 0.036 * Math.sin(mj - 2 * ms)
      + 0.022 * Math.cos(mj - ms)
      + 0.023 * Math.sin(2 * mj - 3 * ms + 52 * DEG)
      - 0.016 * Math.sin(mj - 5 * ms - 69 * DEG);
  } else if (id === 'SATURN') {
    lon += 0.812 * Math.sin(2 * mj - 5 * ms - 67.6 * DEG)
      - 0.229 * Math.cos(2 * mj - 4 * ms - 2 * DEG)
      + 0.119 * Math.sin(mj - 2 * ms - 3 * DEG)
      + 0.046 * Math.sin(2 * mj - 6 * ms - 69 * DEG)
      + 0.014 * Math.sin(mj - 3 * ms + 32 * DEG);
    lat += -0.020 * Math.cos(2 * mj - 4 * ms - 2 * DEG)
      + 0.018 * Math.sin(2 * mj - 6 * ms - 49 * DEG);
  } else if (id === 'URANUS') {
    lon += 0.040 * Math.sin(ms - 2 * mu + 6 * DEG)
      + 0.035 * Math.sin(ms - 3 * mu + 33 * DEG)
      - 0.015 * Math.sin(mj - mu + 20 * DEG);
  }
  return { lonDeg: norm360(lon), latDeg: lat, rAu: r };
}

function sunDistanceAu(jd: number): number {
  const n: number = jd - 2451545.0;
  const g: number = (357.528 + 0.9856003 * n) * DEG;
  return 1.00014 - 0.01671 * Math.cos(g) - 0.00014 * Math.cos(2 * g);
}

function planetGeo(id: string, jd: number): Geo | null {
  const helio: Helio | null = helioOf(id, jd);
  if (helio === null) {
    return null;
  }
  const sunLon: number = sunEclipticLongitude(jd) * DEG;
  const sunR: number = sunDistanceAu(jd);
  const earthX: number = -sunR * Math.cos(sunLon);
  const earthY: number = -sunR * Math.sin(sunLon);
  const planetX: number = helio.rAu * Math.cos(helio.latDeg * DEG) * Math.cos(helio.lonDeg * DEG);
  const planetY: number = helio.rAu * Math.cos(helio.latDeg * DEG) * Math.sin(helio.lonDeg * DEG);
  const planetZ: number = helio.rAu * Math.sin(helio.latDeg * DEG);
  const gx: number = planetX - earthX;
  const gy: number = planetY - earthY;
  const gz: number = planetZ;
  return {
    lonDeg: norm360(Math.atan2(gy, gx) * RAD),
    latDeg: Math.atan2(gz, Math.sqrt(gx * gx + gy * gy)) * RAD,
    distanceAu: Math.sqrt(gx * gx + gy * gy + gz * gz)
  };
}

function planetGeoLightTime(id: string, jd: number): Geo | null {
  const g1: Geo | null = planetGeo(id, jd);
  if (g1 === null) {
    return null;
  }
  const g2: Geo | null = planetGeo(id, jd - g1.distanceAu * LIGHT_TIME_DAYS_PER_AU);
  return g2 === null ? g1 : g2;
}

function topocentricMoon(eq: Equatorial, distanceKm: number, jd: number,
                         latDeg: number, lonDeg: number): Equatorial {
  // Vector method, spherical Earth: subtract the observer's geocentric
  // position from the Moon's geocentric vector, then convert back to RA/Dec.
  const rEarth: number = distanceKm / EARTH_RADIUS_KM;
  const ra: number = eq.raHours * 15 * DEG;
  const dec: number = eq.decDeg * DEG;
  const mx: number = rEarth * Math.cos(dec) * Math.cos(ra);
  const my: number = rEarth * Math.cos(dec) * Math.sin(ra);
  const mz: number = rEarth * Math.sin(dec);
  const theta: number = lstDeg(jd, lonDeg) * DEG;
  const phi: number = latDeg * DEG;
  const ox: number = Math.cos(phi) * Math.cos(theta);
  const oy: number = Math.cos(phi) * Math.sin(theta);
  const oz: number = Math.sin(phi);
  const tx: number = mx - ox;
  const ty: number = my - oy;
  const tz: number = mz - oz;
  return {
    raHours: norm360(Math.atan2(ty, tx) * RAD) / 15,
    decDeg: Math.atan2(tz, Math.sqrt(tx * tx + ty * ty)) * RAD
  };
}

function angularSizeArcmin(diameterKm: number, distanceKm: number): number {
  if (distanceKm <= 0) {
    return 0;
  }
  return 2 * Math.atan(diameterKm / (2 * distanceKm)) * RAD * 60;
}

function planetDiameterKm(id: string): number {
  if (id === 'MERCURY') {
    return 4879;
  }
  if (id === 'VENUS') {
    return 12104;
  }
  if (id === 'MARS') {
    return 6779;
  }
  if (id === 'JUPITER') {
    return 139820;
  }
  if (id === 'SATURN') {
    return 116460;
  }
  if (id === 'URANUS') {
    return 50724;
  }
  if (id === 'NEPTUNE') {
    return 49244;
  }
  return 3474.8;
}

function planetMagnitude(id: string, rAu: number, deltaAu: number, phaseDeg: number): number {
  const base: number = 5 * Math.log10(rAu * deltaAu);
  if (id === 'MERCURY') {
    return -0.42 + base + 0.0380 * phaseDeg - 0.000273 * phaseDeg * phaseDeg
      + 0.000002 * phaseDeg * phaseDeg * phaseDeg;
  }
  if (id === 'VENUS') {
    return -4.40 + base + 0.0009 * phaseDeg + 0.000239 * phaseDeg * phaseDeg
      - 0.00065 * phaseDeg * phaseDeg * phaseDeg;
  }
  if (id === 'MARS') {
    return -1.52 + base + 0.016 * phaseDeg;
  }
  if (id === 'JUPITER') {
    return -9.40 + base + 0.005 * phaseDeg;
  }
  if (id === 'SATURN') {
    return -8.88 + base + 0.044 * phaseDeg;
  }
  if (id === 'URANUS') {
    return -7.19 + base;
  }
  if (id === 'NEPTUNE') {
    return -6.87 + base;
  }
  return 99;
}

/**
 * Geocentric/topocentric position of a solar-system target for a given JD.
 * Planets: geocentric apparent place (low-precision, light-time corrected).
 * Moon: topocentric when lat/lon are supplied.
 */
export function solarPosition(id: string, jd: number, latDeg: number = 0,
                              lonDeg: number = 0): SolarPosition | null {
  if (id === 'SUN') {
    const eq: Equatorial = sunEquatorial(jd);
    const distAu: number = sunDistanceAu(jd);
    const distKm: number = distAu * AU_KM;
    return {
      raHours: eq.raHours,
      decDeg: eq.decDeg,
      distanceAu: distAu,
      distanceKm: distKm,
      angularSizeArcmin: angularSizeArcmin(1392700, distKm),
      illumination: 1,
      phaseAngleDeg: 0,
      phaseName: '',
      magnitude: -26.74,
      magKnown: true
    };
  }
  if (id === 'MOON') {
    const m: MoonPosition = moonEquatorial(jd);
    const moonDist: number = m.distanceKm;
    let eq: Equatorial = m;
    if (latDeg !== 0 || lonDeg !== 0) {
      eq = topocentricMoon(m, moonDist, jd, latDeg, lonDeg);
    }
    const phase = moonPhase(jd);
    return {
      raHours: eq.raHours,
      decDeg: eq.decDeg,
      distanceAu: moonDist / AU_KM,
      distanceKm: moonDist,
      angularSizeArcmin: angularSizeArcmin(3474.8, moonDist),
      illumination: phase.illumination,
      phaseAngleDeg: phase.elongationDeg,
      phaseName: phase.phaseName,
      magnitude: 99,
      magKnown: false
    };
  }

  const g: Geo | null = planetGeoLightTime(id, jd);
  if (g === null) {
    return null;
  }
  const eq: Equatorial = eclipticToEquatorial(g.lonDeg, g.latDeg, jd);
  const helio: Helio | null = helioOf(id, jd);
  if (helio === null) {
    return null;
  }
  const sunR: number = sunDistanceAu(jd);
  const cosPhase: number = (helio.rAu * helio.rAu + g.distanceAu * g.distanceAu - sunR * sunR)
    / (2 * helio.rAu * g.distanceAu);
  const phaseAngle: number = Math.acos(Math.max(-1, Math.min(1, cosPhase))) * RAD;
  const distanceKm: number = g.distanceAu * AU_KM;
  return {
    raHours: eq.raHours,
    decDeg: eq.decDeg,
    distanceAu: g.distanceAu,
    distanceKm: distanceKm,
    angularSizeArcmin: angularSizeArcmin(planetDiameterKm(id), distanceKm),
    illumination: (1 + Math.cos(phaseAngle * DEG)) / 2,
    phaseAngleDeg: phaseAngle,
    phaseName: '',
    magnitude: planetMagnitude(id, helio.rAu, g.distanceAu, phaseAngle),
    magKnown: true
  };
}

export function solarHorizontal(id: string, jd: number, latDeg: number, lonDeg: number): Horizontal | null {
  const p: SolarPosition | null = solarPosition(id, jd, latDeg, lonDeg);
  if (p === null) {
    return null;
  }
  return equatorialToHorizontal({ raHours: p.raHours, decDeg: p.decDeg }, jd, latDeg, lonDeg);
}

/**
 * Mask-aware visible windows for a moving solar-system target.
 * Scans in 10-minute steps; precision is adequate for the watch's "可见窗口" text.
 */
export function solarVisibleWindows(id: string, localMidnightMs: number, latDeg: number,
                                    lonDeg: number, mask: number[], minAltDeg: number = 10): VisibleWindow[] {
  const stepMs: number = 10 * 60000;
  const endMs: number = localMidnightMs + 24 * 3600000;
  const out: VisibleWindow[] = [];
  const isSun: boolean = id === 'SUN';
  let inWindow: boolean = false;
  let startMs: number = 0;
  let peakMs: number = 0;
  let peakAltDeg: number = -90;
  for (let t = localMidnightMs; t <= endMs; t += stepMs) {
    const jd: number = t / 86400000 + 2440587.5;
    const sunAlt: number = sunAltitude(jd, latDeg, lonDeg);
    const h: Horizontal | null = solarHorizontal(id, jd, latDeg, lonDeg);
    const alt: number = h === null ? -90 : h.altDeg;
    const need: number = h === null ? 90 : horizonMaskAt(mask, h.azDeg);
    const visible: boolean = isSun
      ? alt >= Math.max(minAltDeg, need)
      : sunAlt <= -18 && alt >= Math.max(minAltDeg, need);
    if (visible) {
      if (!inWindow) {
        inWindow = true;
        startMs = t;
        peakMs = t;
        peakAltDeg = alt;
      } else if (alt > peakAltDeg) {
        peakMs = t;
        peakAltDeg = alt;
      }
    } else if (inWindow) {
      out.push({ startMs: startMs, endMs: t, peakMs: peakMs, peakAltDeg: peakAltDeg });
      inWindow = false;
    }
  }
  if (inWindow) {
    out.push({ startMs: startMs, endMs: endMs, peakMs: peakMs, peakAltDeg: peakAltDeg });
  }
  return out;
}
