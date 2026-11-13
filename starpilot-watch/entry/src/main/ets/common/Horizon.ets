export const SECTOR_NAMES: string[] = [
  'N', 'NNE', 'NE', 'ENE', 'E', 'ESE', 'SE', 'SSE',
  'S', 'SSW', 'SW', 'WSW', 'W', 'WNW', 'NW', 'NNW'
];

export const SECTOR_COUNT: number = 16;

export function defaultSectors(): number[] {
  const out: number[] = [];
  for (let i = 0; i < SECTOR_COUNT; i++) {
    out.push(0);
  }
  return out;
}

export function sectorsToString(sectors: number[]): string {
  return sectors.join(',');
}

export function parseSectors(text: string): number[] {
  const out: number[] = [];
  const parts: string[] = text.length > 0 ? text.split(',') : [];
  for (let i = 0; i < SECTOR_COUNT; i++) {
    let v: number = i < parts.length ? Number(parts[i]) : 0;
    if (Number.isNaN(v)) {
      v = 0;
    }
    out.push(Math.max(0, Math.min(90, Math.round(v))));
  }
  return out;
}

export function clampHeight(v: number): number {
  return Math.max(0, Math.min(90, Math.round(v)));
}
