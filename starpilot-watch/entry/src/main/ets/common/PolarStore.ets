import { fileIo } from '@kit.CoreFileKit';
import { readBoundedText, writeAtomicText } from './BoundedTextFile';
import { DriftDirection, DriftField, DriftRound, DriftTrend, POLAR_SECONDS, PolarAxis } from './PolarAlignEngine';

export const POLAR_LIMIT: number = 96;
export const POLAR_EXPORT: string = 'starpilot-polar-records.txt';
const CACHE: string = 'polar-rounds-v1.json';
const LIMIT_BYTES: number = 96 * 1024;

interface SavedRounds {
  readonly version: number;
  readonly rounds: DriftRound[];
}

export function polarAxisLabel(axis: PolarAxis): string {
  return axis === PolarAxis.Azimuth ? '方位' : '高度';
}

export function driftFieldLabel(field: DriftField): string {
  switch (field) {
    case DriftField.Meridian:
      return '子午圈';
    case DriftField.EastWest:
      return '标准东西';
    default:
      return '西南替代（两轴耦合）';
  }
}

export function driftDirectionLabel(direction: DriftDirection): string {
  const labels: string[] = ['向上', '向下', '向左', '向右', '未见持续漂移', '不稳定'];
  return labels[direction];
}

export function driftStrengthLabel(strength: number): string {
  const labels: string[] = ['无明显', '轻微', '明显'];
  return labels[strength] ?? '未估幅度';
}

export function driftTrendLabel(trend: DriftTrend): string {
  const labels: string[] = ['暂无可比结果', '目测减小', '目测相近', '目测增大', '方向反转，需复测'];
  return labels[trend];
}

function validRound(round: DriftRound): boolean {
  return round !== null && Number.isFinite(round.session) && Number.isFinite(round.start) &&
    POLAR_SECONDS.includes(round.seconds) && typeof round.starId === 'string' &&
    typeof round.starName === 'string' && typeof round.site === 'string' && typeof round.north === 'boolean' &&
    typeof round.mount === 'string' && typeof round.image === 'string' && typeof round.side === 'string' &&
    (round.axis === PolarAxis.Azimuth || round.axis === PolarAxis.Altitude) &&
    Number.isInteger(round.field) && round.field >= DriftField.Meridian && round.field <= DriftField.Southwest &&
    Number.isFinite(round.alt) && Number.isFinite(round.az) && Number.isFinite(round.hourAngle) &&
    Number.isInteger(round.direction) && round.direction >= DriftDirection.Up && round.direction <= DriftDirection.Unsteady &&
    Number.isInteger(round.strength) && round.strength >= -1 && round.strength <= 2 &&
    Number.isInteger(round.adjustments) && round.adjustments >= 0 &&
    Number.isInteger(round.trend) && round.trend >= DriftTrend.Unknown && round.trend <= DriftTrend.Reversed;
}

export function loadPolarRounds(directory: string): DriftRound[] {
  const path: string = directory + '/' + CACHE;
  if (!fileIo.accessSync(path)) {
    return [];
  }
  const file: SavedRounds = JSON.parse(readBoundedText(path, LIMIT_BYTES)) as SavedRounds;
  if (file === null || file.version !== 1 || !Array.isArray(file.rounds) ||
    file.rounds.length > POLAR_LIMIT || !file.rounds.every((round: DriftRound) => validRound(round))) {
    throw new Error('漂移记录格式无效');
  }
  return file.rounds;
}

export function savePolarRounds(directory: string, rounds: DriftRound[]): void {
  const file: SavedRounds = { version: 1, rounds: rounds };
  writeAtomicText(directory + '/' + CACHE, JSON.stringify(file), LIMIT_BYTES);
}

export function exportPolarRounds(directory: string, rounds: DriftRound[]): void {
  const lines: string[] = ['StarPilot 赤道仪漂移记录（人工观察，UTC）'];
  for (const round of rounds) {
    lines.push(new Date(round.start).toISOString() + ' · ' + round.site + ' · ' + round.starName + ' [' +
      round.starId + '] · ' + polarAxisLabel(round.axis) + '/' + driftFieldLabel(round.field) + ' · ' +
      round.seconds + ' s · 高度 ' + round.alt.toFixed(1) + '° / 方位 ' + round.az.toFixed(1) +
      '° · ' + (round.north ? '北半球' : '南半球') + ' · ' + round.mount + ' · 成像 ' + round.image +
      ' · 侧位 ' + round.side + ' · ' + driftDirectionLabel(round.direction) + ' / ' +
      driftStrengthLabel(round.strength) + ' · 试调累计 ' + round.adjustments + ' · ' + driftTrendLabel(round.trend));
  }
  writeAtomicText(directory + '/' + POLAR_EXPORT, lines.join('\n') + '\n', LIMIT_BYTES);
}
