// Near-Earth SGP4 adapted from satellite.js 6.0.1 (MIT), initl, sgp4init and sgp4.
// See resources/rawfile/satellite-js-license.txt. Units follow Vallado's WGS-72 implementation.
const R: number = 6378.135;
const XKE: number = 60 / Math.sqrt(R * R * R / 398600.8);
const J2: number = 0.001082616;
const J3_J2: number = -0.00000253881 / J2;
const J4: number = -0.00000165597;
const TWO_PI: number = 2 * Math.PI;
const DEG: number = Math.PI / 180;

export interface OrbitElements {
  readonly epochMs: number;
  readonly meanMotion: number; // revolutions per day
  readonly eccentricity: number;
  readonly inclination: number; // angles in degrees
  readonly node: number;
  readonly perigee: number;
  readonly anomaly: number;
  readonly bstar: number;
}

export interface OrbitVector {
  readonly x: number;
  readonly y: number;
  readonly z: number;
}

export interface TemeState {
  readonly position: OrbitVector; // km
  readonly velocity: OrbitVector; // km/s
}

export class NearEarthSgp4 {
  readonly epochMs: number;
  private valid: boolean = false;
  private eccentricity: number;
  private inclination: number;
  private argpo: number;
  private nodeo: number;
  private mo: number;
  private bstar: number;
  private no: number;
  private cosi: number;
  private sini: number;
  private con41: number;
  private x1mth2: number;
  private x7thm1: number;
  private aycof: number;
  private xlcof: number;
  private cc1: number = 0;
  private cc4: number = 0;
  private cc5: number = 0;
  private mdot: number = 0;
  private argpdot: number = 0;
  private nodedot: number = 0;
  private nodecf: number = 0;
  private eta: number = 0;
  private omgcof: number = 0;
  private xmcof: number = 0;
  private t2cof: number = 0;
  private t3cof: number = 0;
  private t4cof: number = 0;
  private t5cof: number = 0;
  private d2: number = 0;
  private d3: number = 0;
  private d4: number = 0;
  private delmo: number = 0;
  private simple: boolean = false;

  constructor(elements: OrbitElements) {
    this.epochMs = elements.epochMs;
    this.eccentricity = elements.eccentricity;
    this.inclination = elements.inclination * DEG;
    this.argpo = elements.perigee * DEG;
    this.nodeo = elements.node * DEG;
    this.mo = elements.anomaly * DEG;
    this.bstar = elements.bstar;
    this.no = elements.meanMotion * TWO_PI / 1440;
    this.cosi = Math.cos(this.inclination);
    this.sini = Math.sin(this.inclination);
    const cos2: number = this.cosi * this.cosi;
    this.con41 = 3 * cos2 - 1;
    this.x1mth2 = 1 - cos2;
    this.x7thm1 = 7 * cos2 - 1;
    this.aycof = -0.5 * J3_J2 * this.sini;
    this.xlcof = -0.25 * J3_J2 * this.sini * (3 + 5 * this.cosi) / Math.max(1.5e-12, 1 + this.cosi);
    this.initialize(cos2);
  }

  private initialize(cos2: number): void {
    const e: number = this.eccentricity;
    if (!(this.no > 0 && e >= 0 && e < 1)) {
      return;
    }
    // Recover the un-Kozai mean motion.
    const oneMinusE2: number = 1 - e * e;
    const beta: number = Math.sqrt(oneMinusE2);
    const ak: number = Math.pow(XKE / this.no, 2 / 3);
    const d1: number = 0.75 * J2 * this.con41 / (beta * oneMinusE2);
    const d: number = d1 / (ak * ak);
    const adel: number = ak * (1 - d * d - d * (1 / 3 + 134 * d * d / 81));
    this.no /= 1 + d1 / (adel * adel);
    if (TWO_PI / this.no >= 225) {
      return;
    }
    const a: number = Math.pow(XKE / this.no, 2 / 3);
    const p: number = a * oneMinusE2;
    const pinvsq: number = 1 / (p * p);
    const perigeeKm: number = (a * (1 - e) - 1) * R;
    this.simple = perigeeKm < 220;
    const sKm: number = perigeeKm < 156 ? Math.max(20, perigeeKm - 78) : 78;
    const s: number = 1 + sKm / R;
    const tsi: number = 1 / (a - s);
    this.eta = a * e * tsi;
    const eta2: number = this.eta * this.eta;
    const eeta: number = e * this.eta;
    const psi2: number = Math.abs(1 - eta2);
    const coef: number = Math.pow((120 - sKm) * tsi / R, 4);
    const coef1: number = coef / Math.pow(psi2, 3.5);
    const cc2: number = coef1 * this.no * (a * (1 + 1.5 * eta2 + eeta * (4 + eta2)) +
      0.375 * J2 * tsi / psi2 * this.con41 * (8 + 3 * eta2 * (8 + eta2)));
    this.cc1 = this.bstar * cc2;
    const cc3: number = e > 1e-4 ? -2 * coef * tsi * J3_J2 * this.no * this.sini / e : 0;
    const cc4Term: number = -3 * this.con41 * (1 - 2 * eeta + eta2 * (1.5 - 0.5 * eeta)) +
      0.75 * this.x1mth2 * (2 * eta2 - eeta * (1 + eta2)) * Math.cos(2 * this.argpo);
    this.cc4 = 2 * this.no * coef1 * a * oneMinusE2 * (this.eta * (2 + 0.5 * eta2) +
      e * (0.5 + 2 * eta2) - J2 * tsi / (a * psi2) * cc4Term);
    this.cc5 = 2 * coef1 * a * oneMinusE2 * (1 + 2.75 * (eta2 + eeta) + eeta * eta2);
    const cos4: number = cos2 * cos2;
    const t1: number = 1.5 * J2 * pinvsq * this.no;
    const t2: number = 0.5 * t1 * J2 * pinvsq;
    const t3: number = -0.46875 * J4 * pinvsq * pinvsq * this.no;
    const nodeRate: number = -t1 * this.cosi;
    this.mdot = this.no + 0.5 * t1 * beta * this.con41 + 0.0625 * t2 * beta * (13 - 78 * cos2 + 137 * cos4);
    this.argpdot = -0.5 * t1 * (1 - 5 * cos2) + 0.0625 * t2 * (7 - 114 * cos2 + 395 * cos4) +
      t3 * (3 - 36 * cos2 + 49 * cos4);
    this.nodedot = nodeRate + (0.5 * t2 * (4 - 19 * cos2) + 2 * t3 * (3 - 7 * cos2)) * this.cosi;
    this.omgcof = this.bstar * cc3 * Math.cos(this.argpo);
    this.xmcof = e > 1e-4 ? -(2 / 3) * coef * this.bstar / eeta : 0;
    this.nodecf = 3.5 * oneMinusE2 * nodeRate * this.cc1;
    this.t2cof = 1.5 * this.cc1;
    this.delmo = Math.pow(1 + this.eta * Math.cos(this.mo), 3);
    if (!this.simple) {
      const cc1sq: number = this.cc1 * this.cc1;
      this.d2 = 4 * a * tsi * cc1sq;
      const temp: number = this.d2 * tsi * this.cc1 / 3;
      this.d3 = (17 * a + s) * temp;
      this.d4 = 0.5 * temp * a * tsi * (221 * a + 31 * s) * this.cc1;
      this.t3cof = this.d2 + 2 * cc1sq;
      this.t4cof = 0.25 * (3 * this.d3 + this.cc1 * (12 * this.d2 + 10 * cc1sq));
      this.t5cof = 0.2 * (3 * this.d4 + 12 * this.cc1 * this.d3 + 6 * this.d2 * this.d2 +
        15 * cc1sq * (2 * this.d2 + cc1sq));
    }
    this.valid = true;
  }

  at(ms: number): TemeState | null {
    if (!this.valid) {
      return null;
    }
    const t: number = (ms - this.epochMs) / 60000;
    const t2: number = t * t;
    let meanAnomaly: number = this.mo + this.mdot * t;
    let argp: number = this.argpo + this.argpdot * t;
    const node: number = (this.nodeo + this.nodedot * t + this.nodecf * t2) % TWO_PI;
    let dragA: number = 1 - this.cc1 * t;
    let dragE: number = this.bstar * this.cc4 * t;
    let dragL: number = this.t2cof * t2;
    if (!this.simple) {
      const delta: number = this.omgcof * t + this.xmcof * (Math.pow(1 + this.eta * Math.cos(meanAnomaly), 3) - this.delmo);
      meanAnomaly += delta;
      argp -= delta;
      const t3: number = t2 * t;
      const t4: number = t3 * t;
      dragA -= this.d2 * t2 + this.d3 * t3 + this.d4 * t4;
      dragE += this.bstar * this.cc5 * (Math.sin(meanAnomaly) - Math.sin(this.mo));
      dragL += this.t3cof * t3 + t4 * (this.t4cof + t * this.t5cof);
    }
    const a: number = Math.pow(XKE / this.no, 2 / 3) * dragA * dragA;
    const e: number = this.eccentricity - dragE;
    if (!(e >= -0.001 && e < 1) || a <= 0) {
      return null;
    }
    return this.periodics(a, Math.max(e, 1e-6), meanAnomaly + this.no * dragL, argp % TWO_PI, node);
  }

  private periodics(a: number, e: number, meanAnomaly: number, argp: number, node: number): TemeState | null {
    const ax: number = e * Math.cos(argp);
    const temp: number = 1 / (a * (1 - e * e));
    const ay: number = e * Math.sin(argp) + temp * this.aycof;
    const u: number = (meanAnomaly + argp + temp * this.xlcof * ax) % TWO_PI;
    let anomaly: number = u;
    for (let i = 0; i < 10; i++) {
      const sin: number = Math.sin(anomaly);
      const cos: number = Math.cos(anomaly);
      const step: number = (u - ay * cos + ax * sin - anomaly) / (1 - ax * cos - ay * sin);
      anomaly += Math.max(-0.95, Math.min(0.95, step));
      if (Math.abs(step) < 1e-12) {
        break;
      }
    }
    const sinE: number = Math.sin(anomaly);
    const cosE: number = Math.cos(anomaly);
    const esin: number = ax * sinE - ay * cosE;
    const el2: number = ax * ax + ay * ay;
    const p: number = a * (1 - el2);
    if (p <= 0) {
      return null;
    }
    const r: number = a * (1 - ax * cosE - ay * sinE);
    const beta: number = Math.sqrt(1 - el2);
    const q: number = esin / (1 + beta);
    const sinU: number = a / r * (sinE - ay - ax * q);
    const cosU: number = a / r * (cosE - ax + ay * q);
    const sin2: number = 2 * sinU * cosU;
    const cos2: number = 1 - 2 * sinU * sinU;
    const t1: number = 0.5 * J2 / p;
    const t2: number = t1 / p;
    const radius: number = r * (1 - 1.5 * t2 * beta * this.con41) + 0.5 * t1 * this.x1mth2 * cos2;
    if (!(radius >= 1)) {
      return null;
    }
    const su: number = Math.atan2(sinU, cosU) - 0.25 * t2 * this.x7thm1 * sin2;
    const asc: number = node + 1.5 * t2 * this.cosi * sin2;
    const inc: number = this.inclination + 1.5 * t2 * this.cosi * this.sini * cos2;
    const n: number = XKE / Math.pow(a, 1.5);
    const vr: number = Math.sqrt(a) * esin / r - n * t1 * this.x1mth2 * sin2 / XKE;
    const vt: number = Math.sqrt(p) / r + n * t1 * (this.x1mth2 * cos2 + 1.5 * this.con41) / XKE;
    const sinSu: number = Math.sin(su);
    const cosSu: number = Math.cos(su);
    const sinAsc: number = Math.sin(asc);
    const cosAsc: number = Math.cos(asc);
    const wx: number = -sinAsc * Math.cos(inc);
    const wy: number = cosAsc * Math.cos(inc);
    const wz: number = Math.sin(inc);
    const ux: number = wx * sinSu + cosAsc * cosSu;
    const uy: number = wy * sinSu + sinAsc * cosSu;
    const uz: number = wz * sinSu;
    const velocityScale: number = R * XKE / 60;
    return {
      position: { x: radius * ux * R, y: radius * uy * R, z: radius * uz * R },
      velocity: {
        x: (vr * ux + vt * (wx * cosSu - cosAsc * sinSu)) * velocityScale,
        y: (vr * uy + vt * (wy * cosSu - sinAsc * sinSu)) * velocityScale,
        z: (vr * uz + vt * wz * cosSu) * velocityScale
      }
    };
  }
}
