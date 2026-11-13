import * as W from './weather.mjs';

const url = W.weatherUrl(39.9042, 116.4074);
const res = await fetch(url);
const text = await res.text();
const d = W.parseWeather(text);
console.log('HTTP', res.status);
console.log('parsed', d);

let ok = res.status === 200 && d !== null;
if (d !== null) {
  ok = ok && d.cloudCover >= 0 && d.cloudCover <= 100
    && d.humidity >= 0 && d.humidity <= 100
    && d.tempC > -60 && d.tempC < 60
    && d.windKmh >= 0
    && d.precipProb >= 0 && d.precipProb <= 100
    && d.updateMs > 0;
}
console.log(`${ok ? 'PASS' : 'FAIL'} weather parse`);
console.log(`${W.parseWeather('not json') === null ? 'PASS' : 'FAIL'} malformed json -> null`);
process.exitCode = ok ? 0 : 1;
