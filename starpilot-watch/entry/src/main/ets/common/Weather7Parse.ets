/**
 * 7Timer ASTRO parsing: pure math, shared by the watch and the Node harness.
 * Scales: cloudcover 1-9 (1 clear, 9 overcast), seeing/transparency 1-8
 * (1 best, 8 worst). timepoint is hours after the model init time.
 */

export interface Weather7Data {
  cloud7: number;
  seeing: number;
  transparency: number;
  tempC: number;
  humidityBand: number;
  windBand: number;
  precipType: string;
  timepoint: number;
  validMs: number;
}

interface Weather7Wind {
  direction: string;
  speed: number;
}

interface Weather7Item {
  timepoint: number;
  cloudcover: number;
  seeing: number;
  transparency: number;
  lifted_index: number;
  rh2m: number;
  wind10m: Weather7Wind;
  temp2m: number;
  prec_type: string;
}

interface Weather7Response {
  product: string;
  init: string;
  dataseries: Weather7Item[];
}

export function weather7Url(lat: number, lon: number): string {
  return `https://www.7timer.info/bin/astro.php?lon=${lon.toFixed(4)}&lat=${lat.toFixed(4)}` +
    '&ac=0&unit=metric&output=json&tzshift=0';
}

const CLOUD_BANDS: string[] = ['—', '0–6%', '6–19%', '19–31%', '31–44%', '44–56%', '56–69%',
  '69–81%', '81–94%', '94–100%'];
const WIND_BANDS: string[] = ['—', '<0.3', '0.3–3.4', '3.4–8.0', '8.0–10.8', '10.8–17.2',
  '17.2–24.5', '24.5–32.6', '>32.6'];

export function cloudBandText(band: number): string {
  return CLOUD_BANDS[band] ?? '—';
}

export function windBandText(band: number): string {
  const range: string = WIND_BANDS[band] ?? '—';
  return range === '—' ? range : range + ' m/s';
}

export function humidityBandText(band: number): string {
  if (!Number.isInteger(band) || band < -4 || band > 16) {
    return '—';
  }
  if (band === 16) {
    return '100%';
  }
  const lo: number = (band + 4) * 5;
  return `${lo}–${band === 15 ? 99 : lo + 5}%`;
}

export function precipitationTypeText(type: string): string {
  if (type === 'rain') return '雨';
  if (type === 'snow') return '雪';
  if (type === 'none') return '无';
  return '—';
}

function validBand(n: number, max: number): boolean {
  return Number.isInteger(n) && n >= 1 && n <= max;
}

export function parseWeather7(text: string, now: number = Date.now()): Weather7Data | null {
  try {
    const obj: Weather7Response = JSON.parse(text) as Weather7Response;
    if (obj.init === undefined || obj.dataseries === undefined || obj.dataseries.length === 0) {
      return null;
    }
    const y: number = Number(obj.init.substring(0, 4));
    const mo: number = Number(obj.init.substring(4, 6));
    const d: number = Number(obj.init.substring(6, 8));
    const h: number = Number(obj.init.substring(8, 10));
    const initMs: number = Date.UTC(y, mo - 1, d, h);
    if (!(initMs > 0)) {
      return null;
    }
    const hours: number = (now - initMs) / 3600000;
    let chosen: Weather7Item | null = null;
    for (let i = 0; i < obj.dataseries.length; i++) {
      if (obj.dataseries[i].timepoint >= hours) {
        chosen = obj.dataseries[i];
        break;
      }
    }
    if (chosen === null || chosen.timepoint - hours > 3 ||
      !validBand(chosen.cloudcover, 9) || !validBand(chosen.seeing, 8) || !validBand(chosen.transparency, 8)) {
      return null;
    }
    const out: Weather7Data = {
      cloud7: chosen.cloudcover,
      seeing: chosen.seeing,
      transparency: chosen.transparency,
      tempC: Number.isFinite(chosen.temp2m) ? chosen.temp2m : -9999,
      humidityBand: Number.isInteger(chosen.rh2m) ? chosen.rh2m : -9999,
      windBand: chosen.wind10m?.speed ?? 0,
      precipType: chosen.prec_type ?? '',
      timepoint: chosen.timepoint,
      validMs: initMs + chosen.timepoint * 3600000
    };
    return out;
  } catch (err) {
    return null;
  }
}
