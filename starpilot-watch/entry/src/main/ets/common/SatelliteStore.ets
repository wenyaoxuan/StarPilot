import { fileIo } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { readBoundedText, writeAtomicText } from './BoundedTextFile';
import { IssOrbit, MAX_OMM_BYTES, parseIssOmm } from './SatelliteOrbit';

export const ISS_STAGING_NAME: string = 'iss-omm.json';
const CACHE_NAME: string = 'iss-orbit-v1.json';
const CACHE_LIMIT: number = 8192;

export interface IssImport {
  readonly version: number;
  readonly importedAt: number;
  readonly source: string;
  readonly omm: string;
}

export interface IssRecord {
  readonly input: IssImport;
  readonly orbit: IssOrbit;
}

export function loadIssRecord(directory: string): IssRecord | null {
  const path: string = directory + '/' + CACHE_NAME;
  if (!fileIo.accessSync(path)) {
    return null;
  }
  const input: IssImport = JSON.parse(readBoundedText(path, CACHE_LIMIT)) as IssImport;
  if (input === null || input.version !== 1 || !Number.isFinite(input.importedAt) ||
    typeof input.source !== 'string' || typeof input.omm !== 'string') {
    throw new Error('轨道缓存无效');
  }
  return { input: input, orbit: parseIssOmm(input.omm) };
}

export function importIssRecord(directory: string, omm: string, source: string, time: number,
                                orbit: IssOrbit): IssRecord {
  if (new util.TextEncoder().encodeInto(omm).byteLength > MAX_OMM_BYTES) {
    throw new Error('轨道文件超过 4 KB');
  }
  const input: IssImport = { version: 1, importedAt: time, source: source, omm: omm };
  writeAtomicText(directory + '/' + CACHE_NAME, JSON.stringify(input), CACHE_LIMIT);
  return { input: input, orbit: orbit };
}
