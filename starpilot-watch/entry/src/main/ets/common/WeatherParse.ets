/**
 * Pure weather parsing: no HarmonyOS imports, shared by the watch app and the
 * Node test harness.
 */

export interface WeatherData {
  tempC: number;
  humidity: number;
  cloudCover: number;
  windKmh: number;
  precipProb: number;
  updateMs: number;
}

interface OpenMeteoCurrent {
  time: number;
  temperature_2m: number;
  relative_humidity_2m: number;
  cloud_cover: number;
  wind_speed_10m: number;
}

interface OpenMeteoHourly {
  time: number[];
  precipitation_probability: number[];
}

interface OpenMeteoResponse {
  current: OpenMeteoCurrent;
  hourly: OpenMeteoHourly;
}

export function weatherUrl(lat: number, lon: number): string {
  return `https://api.open-meteo.com/v1/forecast?latitude=${lat.toFixed(4)}&longitude=${lon.toFixed(4)}` +
    '&current=temperature_2m,relative_humidity_2m,cloud_cover,wind_speed_10m' +
    '&hourly=precipitation_probability&timezone=GMT&timeformat=unixtime&forecast_days=1';
}

export function parseWeather(text: string): WeatherData | null {
  try {
    const obj: OpenMeteoResponse = JSON.parse(text) as OpenMeteoResponse;
    const current: OpenMeteoCurrent = obj.current;
    if (!current || !Number.isFinite(current.temperature_2m) || !Number.isFinite(current.relative_humidity_2m) ||
      !Number.isFinite(current.cloud_cover) || !Number.isFinite(current.wind_speed_10m)) {
      return null;
    }
    const hour: number = Math.floor(current.time / 3600) * 3600;
    const index: number = obj.hourly?.time?.indexOf(hour) ?? -1;
    const probability: number = obj.hourly?.precipitation_probability?.[index] ?? -1;
    const out: WeatherData = {
      tempC: obj.current.temperature_2m,
      humidity: obj.current.relative_humidity_2m,
      cloudCover: obj.current.cloud_cover,
      windKmh: obj.current.wind_speed_10m,
      precipProb: Number.isFinite(probability) && probability >= 0 && probability <= 100 ? probability : -1,
      updateMs: Date.now()
    };
    return out;
  } catch (err) {
    return null;
  }
}
