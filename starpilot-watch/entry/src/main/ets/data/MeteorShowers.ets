export const METEOR_FIRST_YEAR: number = 2026;
export const METEOR_LAST_YEAR: number = 2027;
export const METEOR_SOURCE: string = 'Source: International Meteor Organization (IMO) – www.imo.net';

export interface MeteorShower {
  readonly code: string;
  readonly name: string;
  readonly nameEn: string;
  readonly start: number;
  readonly end: number;
  readonly peakMonth: number;
  readonly peak2026: number;
  readonly peak2027: number;
  readonly longitude: number;
  readonly raDeg: number;
  readonly decDeg: number;
  readonly zhr: string;
  readonly driftRa: number;
  readonly driftDec: number;
  readonly driftStart: number;
  readonly driftEnd: number;
}

// Selected factual parameters from IMO Calendar 2026/2027, Table 5. Dates use MMDD and UTC.
// Drift is StarPilot's linear approximation of nearby Table 6 positions, in degrees per solar degree.
// Drift bounds are offsets from reference solar longitude and stay within the sampled arc.
export const METEOR_SHOWERS: MeteorShower[] = [
  {
    code: 'QUA', name: '象限仪座', nameEn: 'Quadrantids',
    start: 1228, end: 112, peakMonth: 1, peak2026: 3, peak2027: 4,
    longitude: 283.15, raDeg: 230, decDeg: 49, zhr: '80+',
    driftRa: 0.59, driftDec: -0.12, driftStart: -4, driftEnd: 6
  },
  {
    code: 'LYR', name: '天琴座', nameEn: 'April Lyrids',
    start: 414, end: 430, peakMonth: 4, peak2026: 22, peak2027: 23,
    longitude: 32.32, raDeg: 271, decDeg: 34, zhr: '18',
    driftRa: 1.02, driftDec: 0, driftStart: -7, driftEnd: 7
  },
  {
    code: 'ETA', name: '宝瓶座 η', nameEn: 'η Aquariids',
    start: 419, end: 528, peakMonth: 5, peak2026: 6, peak2027: 6,
    longitude: 45.5, raDeg: 338, decDeg: -1, zhr: '50',
    driftRa: 0.83, driftDec: 0.41, driftStart: -14, driftEnd: 18
  },
  {
    code: 'PER', name: '英仙座', nameEn: 'Perseids',
    start: 717, end: 824, peakMonth: 8, peak2026: 13, peak2027: 13,
    longitude: 140, raDeg: 48, decDeg: 58, zhr: '110+',
    driftRa: 1.35, driftDec: 0.14, driftStart: -21, driftEnd: 11
  },
  {
    code: 'ORI', name: '猎户座', nameEn: 'Orionids',
    start: 1002, end: 1107, peakMonth: 10, peak2026: 21, peak2027: 22,
    longitude: 208, raDeg: 95, decDeg: 16, zhr: '20',
    driftRa: 0.65, driftDec: 0.13, driftStart: -15, driftEnd: 13
  },
  {
    code: 'STA', name: '南金牛座', nameEn: 'Southern Taurids',
    start: 920, end: 1120, peakMonth: 11, peak2026: 5, peak2027: 6,
    longitude: 223, raDeg: 52, decDeg: 15, zhr: '7',
    driftRa: 0.70, driftDec: 0.13, driftStart: -37, driftEnd: 13
  },
  {
    code: 'NTA', name: '北金牛座', nameEn: 'Northern Taurids',
    start: 1020, end: 1210, peakMonth: 11, peak2026: 12, peak2027: 13,
    longitude: 230, raDeg: 58, decDeg: 22, zhr: '5',
    driftRa: 0.86, driftDec: 0.18, driftStart: -22, driftEnd: 23
  },
  {
    code: 'LEO', name: '狮子座', nameEn: 'Leonids',
    start: 1106, end: 1130, peakMonth: 11, peak2026: 17, peak2027: 18,
    longitude: 235.27, raDeg: 152, decDeg: 22, zhr: '15+',
    driftRa: 0.60, driftDec: -0.25, driftStart: -7, driftEnd: 11
  },
  {
    code: 'GEM', name: '双子座', nameEn: 'Geminids',
    start: 1204, end: 1220, peakMonth: 12, peak2026: 14, peak2027: 14,
    longitude: 262.2, raDeg: 112, decDeg: 33, zhr: '150',
    driftRa: 0.98, driftDec: -0.07, driftStart: -8, driftEnd: 5
  },
  {
    code: 'URS', name: '小熊座', nameEn: 'Ursids',
    start: 1217, end: 1226, peakMonth: 12, peak2026: 22, peak2027: 23,
    longitude: 270.7, raDeg: 217, decDeg: 76, zhr: '10',
    driftRa: 0, driftDec: -0.39, driftStart: -2, driftEnd: 2
  },
];
