import { requestWeatherText } from './WeatherRequest';
import { WeatherData, parseWeather, weatherUrl } from './WeatherParse';

export function fetchWeather(lat: number, lon: number, done: (data: WeatherData | null) => void): () => void {
  return requestWeatherText(weatherUrl(lat, lon), 'Open-Meteo', (text: string | null) => {
    done(text === null ? null : parseWeather(text));
  });
}
