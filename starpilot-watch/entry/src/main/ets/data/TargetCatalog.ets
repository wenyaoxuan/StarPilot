import { CONSTELLATION_STARS, ConstellationStar } from './Constellations';
import { MESSIER, MessierObject } from './Messier';

export const STATIC_TARGETS: MessierObject[] = MESSIER.slice();
const targetsById: Map<string, MessierObject> = new Map();
const anchorNamesById: Map<string, ConstellationStar> = new Map();
for (const target of STATIC_TARGETS) {
  targetsById.set(target.id, target);
}

for (const star of CONSTELLATION_STARS) {
  anchorNamesById.set(star.id, star);
  const existing: MessierObject | undefined = targetsById.get(star.id);
  if (existing !== undefined) {
    continue;
  }
  const target: MessierObject = {
    id: star.id,
    name: star.name,
    nameEn: star.nameEn,
    aliases: star.aliases,
    type: '恒星',
    category: 'star',
    raHours: star.raHours,
    decDeg: star.decDeg,
    epoch: 2000.0,
    mag: star.mag,
    magKnown: star.mag !== 99,
    sizeA: 0,
    sizeB: 0,
    sizeKnown: false,
    surfaceBrightness: 0,
    distanceLy: star.distanceLy,
    fl: '',
    season: '',
    desc: 'AR 星座连线端点',
    source: 'HYG v3.5 / Stellarium（CC BY-SA 4.0）'
  };
  STATIC_TARGETS.push(target);
  targetsById.set(target.id, target);
}

export function findStaticTarget(id: string): MessierObject | null {
  return targetsById.get(id) ?? null;
}

export function targetDisplayName(id: string, name: string, nameEn: string, english: boolean): string {
  const anchor: ConstellationStar | undefined = anchorNamesById.get(id);
  const chineseName: string = anchor?.name ?? name;
  const englishName: string = anchor?.nameEn ?? nameEn;
  return english ? (englishName || chineseName || id) : (chineseName || englishName || id);
}

export function anchorSearchNames(id: string): string[] {
  const star: ConstellationStar | undefined = anchorNamesById.get(id);
  return star === undefined ? [] : [star.name, star.nameEn].concat(star.aliases);
}
