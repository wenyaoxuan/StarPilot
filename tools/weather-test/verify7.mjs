import * as W from './weather7.mjs';

const url = W.weather7Url(39.9042, 116.4074);
const res = await fetch(url);
const text = await res.text();
const d = W.parseWeather7(text);
console.log('HTTP', res.status);
console.log('parsed', d);
let ok = res.status === 200 && d !== null;
if (d !== null) {
  ok = ok && d.cloud7 >= 1 && d.cloud7 <= 9
    && d.seeing >= 1 && d.seeing <= 8
    && d.transparency >= 1 && d.transparency <= 8
    && d.validMs > 0;
}
console.log(`${ok ? 'PASS' : 'FAIL'} 7timer parse`);
console.log(`${W.parseWeather7('not json') === null ? 'PASS' : 'FAIL'} malformed json -> null`);
process.exitCode = ok ? 0 : 1;
