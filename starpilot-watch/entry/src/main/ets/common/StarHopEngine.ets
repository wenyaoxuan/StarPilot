import { clamp, Equatorial, horizonMaskAt, Horizontal, jdFromUnixMs, norm360, sunAltitude,
  targetHorizontal } from './Astro';

const DEG: number = Math.PI / 180;
export const HOP_MAX_STEP: number = 14;
export const HOP_SEARCH_RADIUS: number = 60;
const EDGE_COS: number = Math.cos(HOP_MAX_STEP * DEG);

export interface HopStar extends Equatorial {
  readonly id: string;
  readonly name: string;
  readonly nameEn: string;
  readonly constellation: string;
  readonly mag: number;
  readonly identifiable: boolean;
}

export interface HopSite {
  readonly lat: number;
  readonly lon: number;
  readonly horizon: number[];
  readonly bortle: number;
}

export interface HopGeometry {
  readonly distance: number;
  readonly angle: number | null;
}

interface Direction {
  readonly x: number;
  readonly y: number;
  readonly z: number;
}

export interface HopPoint {
  readonly star: HopStar;
  readonly alt: number;
  readonly az: number;
  readonly obstruction: number;
  readonly distanceToTarget: number;
  readonly direction: Direction;
}

export enum HopLimit {
  Ready,
  TargetBelow,
  TargetObstructed,
  TargetLow,
  StarsTooFaint,
  StarsObstructed
}

export interface HopField {
  readonly time: number;
  readonly sunAlt: number;
  readonly target: HopPoint;
  readonly candidates: HopPoint[];
  readonly limit: HopLimit;
  readonly bortle: number;
}

export function defaultHopMagnitude(bortle: number): number {
  return clamp(6.5 - 0.5 * (bortle - 1), 2.5, 6);
}

export function hopGeometry(from: Equatorial, to: Equatorial): HopGeometry {
  const a: number = from.decDeg * DEG;
  const b: number = to.decDeg * DEG;
  const delta: number = (to.raHours - from.raHours) * 15 * DEG;
  const east: number = Math.cos(b) * Math.sin(delta);
  const north: number = Math.cos(a) * Math.sin(b) - Math.sin(a) * Math.cos(b) * Math.cos(delta);
  const depth: number = Math.sin(a) * Math.sin(b) + Math.cos(a) * Math.cos(b) * Math.cos(delta);
  const offset: number = Math.sqrt(east * east + north * north);
  const angle: number | null = offset < 1e-12 || Math.abs(Math.cos(a)) < 1e-12 ?
    null : norm360(Math.atan2(east, north) / DEG);
  return { distance: Math.atan2(offset, depth) / DEG, angle: angle };
}

function unit(eq: Equatorial): Direction {
  const ra: number = eq.raHours * 15 * DEG;
  const dec: number = eq.decDeg * DEG;
  return { x: Math.cos(dec) * Math.cos(ra), y: Math.cos(dec) * Math.sin(ra), z: Math.sin(dec) };
}

function dot(a: Direction, b: Direction): number {
  return a.x * b.x + a.y * b.y + a.z * b.z;
}

function makePoint(star: HopStar, jd: number, site: HopSite, targetDir: Direction): HopPoint {
  const horizontal: Horizontal = targetHorizontal(star, jd, site.lat, site.lon);
  const direction: Direction = unit(star);
  return {
    star: star, alt: horizontal.altDeg, az: horizontal.azDeg,
    obstruction: Math.max(0, horizonMaskAt(site.horizon, horizontal.azDeg)),
    direction: direction, distanceToTarget: Math.acos(clamp(dot(direction, targetDir), -1, 1)) / DEG
  };
}

function targetLimit(target: HopPoint): HopLimit {
  if (target.alt <= 0) {
    return HopLimit.TargetBelow;
  }
  if (target.alt <= target.obstruction) {
    return HopLimit.TargetObstructed;
  }
  if (target.alt < 5) {
    return HopLimit.TargetLow;
  }
  return HopLimit.Ready;
}

function starPenalty(point: HopPoint, bortle: number): number {
  const brightness: number = 0.16 * Math.max(0, point.star.mag + 0.5) * (1 + 0.12 * (bortle - 1));
  return brightness + (point.star.identifiable ? 0 : 0.65) +
    0.55 * Math.max(0, (22 - (point.alt - point.obstruction)) / 22);
}

export function makeHopField(targetStar: HopStar, stars: HopStar[], site: HopSite, magnitude: number,
                             time: number): HopField {
  const jd: number = jdFromUnixMs(time);
  const targetDir: Direction = unit(targetStar);
  const target: HopPoint = makePoint(targetStar, jd, site, targetDir);
  const candidates: HopPoint[] = [];
  const radiusCos: number = Math.cos(HOP_SEARCH_RADIUS * DEG);
  let brightInArea: boolean = false;
  for (const star of stars) {
    if (star.id !== targetStar.id && star.mag <= magnitude && dot(unit(star), targetDir) >= radiusCos) {
      brightInArea = true;
      const point: HopPoint = makePoint(star, jd, site, targetDir);
      if (point.alt >= 10 && point.alt > point.obstruction + 1) {
        candidates.push(point);
      }
    }
  }
  candidates.sort((a: HopPoint, b: HopPoint) => a.distanceToTarget / 12 + starPenalty(a, site.bortle) -
    b.distanceToTarget / 12 - starPenalty(b, site.bortle));
  let limit: HopLimit = targetLimit(target);
  if (limit === HopLimit.Ready && candidates.length === 0) {
    limit = brightInArea ? HopLimit.StarsObstructed : HopLimit.StarsTooFaint;
  }
  return {
    time: time, sunAlt: sunAltitude(jd, site.lat, site.lon), target: target, candidates: candidates,
    limit: limit, bortle: site.bortle
  };
}

/** Dijkstra on an implicit graph, without allocating an adjacency matrix on the watch. */
export function planStarHop(field: HopField, startId: string): HopPoint[] {
  const nodes: HopPoint[] = field.candidates.concat([field.target]);
  const goal: number = nodes.length - 1;
  const start: number = field.candidates.findIndex((point: HopPoint) => point.star.id === startId);
  if (field.limit !== HopLimit.Ready || start < 0) {
    return [];
  }
  const cost: number[] = new Array<number>(nodes.length).fill(Infinity);
  const previous: number[] = new Array<number>(nodes.length).fill(-1);
  const visited: boolean[] = new Array<boolean>(nodes.length).fill(false);
  cost[start] = 0;
  for (let expanded = 0; expanded < nodes.length; expanded++) {
    let best: number = -1;
    let bestCost: number = Infinity;
    for (let i = 0; i < nodes.length; i++) {
      if (!visited[i] && cost[i] < bestCost) {
        best = i;
        bestCost = cost[i];
      }
    }
    if (best < 0) {
      return [];
    }
    if (best === goal) {
      const route: HopPoint[] = [];
      for (let i = goal; i >= 0; i = previous[i]) {
        route.push(nodes[i]);
      }
      return route.reverse();
    }
    visited[best] = true;
    for (let i = 0; i < nodes.length; i++) {
      if (visited[i]) {
        continue;
      }
      const cosine: number = dot(nodes[best].direction, nodes[i].direction);
      if (cosine < EDGE_COS) {
        continue;
      }
      const distance: number = Math.acos(clamp(cosine, -1, 1)) / DEG;
      if (distance < 0.02 && i !== goal) {
        continue;
      }
      const penalty: number = i === goal ? 0 : starPenalty(nodes[i], field.bortle);
      const edge: number = 1.1 + Math.pow(distance / 8, 2) + penalty;
      if (bestCost + edge < cost[i]) {
        cost[i] = bestCost + edge;
        previous[i] = best;
      }
    }
  }
  return [];
}
