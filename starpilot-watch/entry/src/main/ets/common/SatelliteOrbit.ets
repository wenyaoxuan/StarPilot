import { OrbitElements, NearEarthSgp4 } from './Sgp4NearEarth';

const HOUR_MS: number = 3600000;
export const MAX_OMM_BYTES: number = 4096;
export const MAX_ISS_AGE_MS: number = 48 * HOUR_MS;
const ISS_CLOCK_TOLERANCE_MS: number = 2 * HOUR_MS;

interface OmmJson {
  NORAD_CAT_ID?: number;
  EPOCH?: string;
  EPHEMERIS_TYPE?: number;
  MEAN_ELEMENT_THEORY?: string;
  CENTER_NAME?: string;
  REF_FRAME?: string;
  TIME_SYSTEM?: string;
  MEAN_MOTION?: number;
  ECCENTRICITY?: number;
  INCLINATION?: number;
  RA_OF_ASC_NODE?: number;
  ARG_OF_PERICENTER?: number;
  MEAN_ANOMALY?: number;
  BSTAR?: number;
  ELEMENT_SET_NO?: number;
  REV_AT_EPOCH?: number;
  ORIGINATOR?: string;
}

export interface IssOrbit extends OrbitElements {
  readonly catalogId: number;
  readonly elementSet: number;
  readonly revolution: number;
  readonly originator: string;
}

export enum IssFreshness {
  Future,
  Recent,
  Aging,
  Expired
}

function bounded(value: number | undefined, min: number, max: number): number {
  if (value === undefined || !Number.isFinite(value) || value < min || value > max) {
    throw new Error('轨道字段缺失或超出范围');
  }
  return value;
}

function epochMs(value: string | undefined): number {
  if (typeof value !== 'string' || !/^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(\.\d{1,9})?Z?$/.test(value)) {
    throw new Error('轨道历元格式错误');
  }
  const ms: number = Date.parse(value.slice(0, 19) + 'Z');
  if (!Number.isFinite(ms) || new Date(ms).toISOString().slice(0, 19) !== value.slice(0, 19)) {
    throw new Error('轨道历元日期无效');
  }
  const digits: string = value.endsWith('Z') ? value.slice(19, -1) : value.slice(19);
  return ms + Number(digits) * 1000;
}

/** A CCSDS-style OMM JSON object or a single CelesTrak GP JSON record. */
export function parseIssOmm(text: string): IssOrbit {
  if (text.length === 0 || text.length > MAX_OMM_BYTES) {
    throw new Error('文件为空或超过 4 KB');
  }
  const raw: string = text.trim();
  let records: OmmJson[];
  try {
    records = raw.startsWith('[') ? JSON.parse(raw) as OmmJson[] : [JSON.parse(raw) as OmmJson];
  } catch (err) {
    throw new Error('OMM JSON 格式无效');
  }
  if (records.length !== 1 || records[0] === null || typeof records[0] !== 'object' ||
    records[0].NORAD_CAT_ID !== 25544) {
    throw new Error('仅接受一条 ISS（25544）轨道');
  }
  const row: OmmJson = records[0];
  if ((row.MEAN_ELEMENT_THEORY !== undefined && row.MEAN_ELEMENT_THEORY !== 'SGP4') ||
    (row.CENTER_NAME !== undefined && row.CENTER_NAME !== 'EARTH') ||
    (row.REF_FRAME !== undefined && row.REF_FRAME !== 'TEME') ||
    (row.TIME_SYSTEM !== undefined && row.TIME_SYSTEM !== 'UTC') ||
    (row.EPHEMERIS_TYPE !== undefined && row.EPHEMERIS_TYPE !== 0)) {
    throw new Error('需要 TEME / UTC 的 SGP4 元素');
  }
  const orbit: IssOrbit = {
    catalogId: 25544, epochMs: epochMs(row.EPOCH),
    meanMotion: bounded(row.MEAN_MOTION, 14.5, 16.5), eccentricity: bounded(row.ECCENTRICITY, 0, 0.02),
    inclination: bounded(row.INCLINATION, 49, 54), node: bounded(row.RA_OF_ASC_NODE, 0, 360),
    perigee: bounded(row.ARG_OF_PERICENTER, 0, 360), anomaly: bounded(row.MEAN_ANOMALY, 0, 360),
    bstar: bounded(row.BSTAR, -0.01, 0.01), elementSet: row.ELEMENT_SET_NO ?? -1,
    revolution: row.REV_AT_EPOCH ?? -1,
    originator: typeof row.ORIGINATOR === 'string' ? row.ORIGINATOR.trim().slice(0, 40) : ''
  };
  if (!Number.isInteger(orbit.elementSet) || orbit.elementSet < -1 ||
    !Number.isInteger(orbit.revolution) || orbit.revolution < -1 ||
    new NearEarthSgp4(orbit).at(orbit.epochMs) === null) {
    throw new Error('轨道版本无效或 SGP4 无法传播');
  }
  return orbit;
}

export function issFreshness(orbit: IssOrbit, now: number): IssFreshness {
  const age: number = now - orbit.epochMs;
  if (age < -ISS_CLOCK_TOLERANCE_MS) {
    return IssFreshness.Future;
  }
  if (age >= MAX_ISS_AGE_MS) {
    return IssFreshness.Expired;
  }
  return age < 24 * HOUR_MS ? IssFreshness.Recent : IssFreshness.Aging;
}
