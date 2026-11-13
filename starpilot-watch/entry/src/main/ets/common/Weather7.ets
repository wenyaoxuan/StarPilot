import { requestWeatherText } from './WeatherRequest';
import { Weather7Data, parseWeather7, weather7Url } from './Weather7Parse';

export function fetchWeather7(lat: number, lon: number, done: (data: Weather7Data | null) => void): () => void {
  return requestWeatherText(weather7Url(lat, lon), '7Timer', (text: string | null) => {
    done(text === null ? null : parseWeather7(text));
  });
}
