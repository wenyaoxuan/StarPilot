import { Horizontal, equatorialToHorizontal, horizonMaskAt, jdFromUnixMs, lstDeg, norm180,
  precessFromJ2000 } from './Astro';
import { HopStar } from './StarHopEngine';

export enum PolarAxis {
  Azimuth,
  Altitude
}

export enum DriftField {
  Meridian,
  EastWest,
  Southwest
}

export enum DriftDirection {
  Up,
  Down,
  Left,
  Right,
  None,
  Unsteady
}

export enum DriftTrend {
  Unknown,
  Smaller,
  Similar,
  Larger,
  Reversed
}

export const POLAR_SECONDS: number[] = [60, 120, 180];

export interface PoleTarget {
  readonly north: boolean;
  readonly altitude: number;
  readonly azimuth: number | null;
}

export interface PolarSite {
  readonly lat: number;
  readonly lon: number;
  readonly mask: number[];
  readonly southWindow: boolean;
}

export interface DriftCandidate {
  readonly star: HopStar;
  readonly alt: number;
  readonly az: number;
  readonly hourAngle: number;
  readonly dec: number;
  readonly field: DriftField;
  readonly score: number;
}

export interface DriftRound {
  readonly session: number;
  readonly start: number;
  readonly seconds: number;
  readonly starId: string;
  readonly starName: string;
  readonly site: string;
  readonly north: boolean;
  readonly mount: string;
  readonly image: string;
  readonly side: string;
  readonly axis: PolarAxis;
  readonly field: DriftField;
  readonly alt: number;
  readonly az: number;
  readonly hourAngle: number;
  readonly direction: DriftDirection;
  readonly strength: number;
  readonly adjustments: number;
  trend: DriftTrend;
}

export function polarTarget(latitude: number, northAtEquator: boolean): PoleTarget | null {
  if (!Number.isFinite(latitude) || Math.abs(latitude) > 90) {
    return null;
  }
  const north: boolean = latitude === 0 ? northAtEquator : latitude > 0;
  const altitude: number = Math.abs(latitude);
  return { north: north, altitude: altitude, azimuth: altitude === 90 ? null : (north ? 0 : 180) };
}

export function driftCandidate(star: HopStar, site: PolarSite, axis: PolarAxis, time: number): DriftCandidate | null {
  const jd: number = jdFromUnixMs(time);
  const eq = precessFromJ2000(star.raHours, star.decDeg, jd);
  const horizontal: Horizontal = equatorialToHorizontal(eq, jd, site.lat, site.lon);
  const alt: number = horizontal.altDeg;
  const az: number = horizontal.azDeg;
  const ha: number = norm180(lstDeg(jd, site.lon) - eq.raHours * 15);
  const dec: number = Math.abs(eq.decDeg);
  const west: boolean = ha > 0;
  if (star.mag > 4 || dec > 20 || alt < 20 || alt <= horizonMaskAt(site.mask, az) + 2 ||
    (site.southWindow && (az < 145 || az > 258))) {
    return null;
  }
  if (axis === PolarAxis.Azimuth) {
    if (Math.abs(ha) > 20) {
      return null;
    }
    return { star: star, alt: alt, az: az, hourAngle: ha, dec: eq.decDeg,
      field: DriftField.Meridian, score: Math.abs(ha) + dec * 0.5 + 2 * star.mag };
  }
  const sideDistance: number = Math.abs(norm180(az - (west ? 270 : 90)));
  if (!site.southWindow && Math.abs(ha) >= 50 && Math.abs(ha) <= 80 && sideDistance <= 25 && alt <= 45) {
    return { star: star, alt: alt, az: az, hourAngle: ha, dec: eq.decDeg,
      field: DriftField.EastWest, score: sideDistance + Math.abs(alt - 30) + dec + 2 * star.mag };
  }
  if (ha >= 35 && ha <= 65 && az >= 195 && az <= 258 && alt <= 55 && dec <= 15) {
    return { star: star, alt: alt, az: az, hourAngle: ha, dec: eq.decDeg,
      field: DriftField.Southwest, score: Math.abs(ha - 55) + dec + 2 * star.mag };
  }
  return null;
}

export function driftCandidates(stars: HopStar[], site: PolarSite, axis: PolarAxis, time: number): DriftCandidate[] {
  const candidates: DriftCandidate[] = [];
  for (const star of stars) {
    const candidate: DriftCandidate | null = driftCandidate(star, site, axis, time);
    if (candidate !== null) {
      candidates.push(candidate);
    }
  }
  candidates.sort((a: DriftCandidate, b: DriftCandidate) => a.field - b.field || a.score - b.score);
  return candidates.slice(0, 6);
}

export function remainingDriftSeconds(end: number, now: number): number {
  return Math.max(0, Math.ceil((end - now) / 1000));
}

export function compareDrift(previous: DriftRound | null, current: DriftRound): DriftTrend {
  if (previous === null || previous.session !== current.session || previous.starId !== current.starId ||
    previous.axis !== current.axis || previous.field !== current.field || previous.seconds !== current.seconds ||
    previous.image !== current.image || previous.side !== current.side ||
    Math.abs(norm180(current.hourAngle - previous.hourAngle)) > 8 ||
    current.direction === DriftDirection.Unsteady || previous.direction === DriftDirection.Unsteady ||
    current.strength < 0 || previous.strength < 0) {
    return DriftTrend.Unknown;
  }
  if (previous.direction < DriftDirection.None && current.direction < DriftDirection.None) {
    if (Math.floor(previous.direction / 2) !== Math.floor(current.direction / 2)) {
      return DriftTrend.Unknown;
    }
    if (previous.direction !== current.direction) {
      return DriftTrend.Reversed;
    }
  }
  if (current.strength === previous.strength) {
    return DriftTrend.Similar;
  }
  return current.strength < previous.strength ? DriftTrend.Smaller : DriftTrend.Larger;
}
