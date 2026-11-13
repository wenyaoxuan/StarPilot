import { HopStar } from '../common/StarHopEngine';
import { MessierObject } from './Messier';
import { EXTRA_HOP_STARS, HOP_CONSTELLATIONS } from './StarHopSupplement';
import { STATIC_TARGETS, anchorSearchNames, targetDisplayName } from './TargetCatalog';

const tags: Map<string, string> = new Map<string, string>();
for (const entry of HOP_CONSTELLATIONS.split(',')) {
  const separator: number = entry.indexOf(':');
  tags.set('HIP' + entry.slice(0, separator), entry.slice(separator + 1));
}

export function isHopTarget(category: string): boolean {
  return category === 'nebula' || category === 'galaxy' || category === 'cluster';
}

function isHopStar(category: string): boolean {
  return category === 'star' || category === 'double' || category === 'variable';
}

export function asHopStar(row: MessierObject): HopStar {
  const name: string = targetDisplayName(row.id, row.name, row.nameEn, false);
  const nameEn: string = targetDisplayName(row.id, row.name, row.nameEn, true);
  return {
    id: row.id, name: name, nameEn: nameEn, raHours: row.raHours, decDeg: row.decDeg,
    constellation: tags.get(row.id) ?? '', mag: row.mag,
    identifiable: nameEn !== row.id && !/^(HIP|HR|HD|HYG)[\s\d]/.test(nameEn)
  };
}

export function referenceHopStars(): HopStar[] {
  return STATIC_TARGETS.filter((row: MessierObject) => isHopStar(row.category) && row.magKnown &&
    row.mag <= 6 && row.epoch === 2000).map((row: MessierObject) => asHopStar(row)).concat(EXTRA_HOP_STARS);
}

export function hopStarMatches(star: HopStar, query: string): boolean {
  return [star.id, star.name, star.nameEn, star.constellation].concat(anchorSearchNames(star.id))
    .some((value: string) => value.toLowerCase().replace(/\s/g, '').includes(query));
}
