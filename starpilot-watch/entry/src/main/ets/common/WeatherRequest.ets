import { http } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { audit } from './AuditLog';

function transient(code: number): boolean {
  return code === 2300005 || code === 2300006 || code === 2300007 || code === 2300016 ||
    code === 2300028 || code === 2300052 || code === 2300055 || code === 2300056;
}

/** Each attempt uses a fresh request on the current system network. */
export function requestWeatherText(url: string, source: string, done: (text: string | null) => void): () => void {
  let request: http.HttpRequest | null = null;
  let timer: number = -1;
  let attempt: number = 0;
  let closed: boolean = false;
  const release = (): void => {
    clearTimeout(timer);
    const previous: http.HttpRequest | null = request;
    request = null;
    if (previous !== null) {
      try {
        previous.destroy();
      } catch (err) {
        audit('WEATHER_HTTP', source + ';destroy_error');
      }
    }
  };
  const complete = (text: string | null): void => {
    closed = true;
    done(text);
  };
  const start = (): void => {
    if (closed) {
      return;
    }
    attempt++;
    const failed = (reason: string, retry: boolean): void => {
      release();
      audit('WEATHER_HTTP', source + ';attempt=' + attempt + ';' + reason);
      if (retry && attempt === 1) {
        timer = setTimeout(start, 1000);
      } else {
        complete(null);
      }
    };
    try {
      const current: http.HttpRequest = http.createHttp();
      request = current;
      const timeout: number = attempt === 1 ? 16000 : 24000;
      timer = setTimeout(() => failed('deadline', true), timeout + 1000);
      current.request(url, {
        method: http.RequestMethod.GET,
        connectTimeout: timeout,
        readTimeout: timeout,
        expectDataType: http.HttpDataType.STRING
      }, (err: BusinessError, response: http.HttpResponse) => {
        if (closed || request !== current) {
          return;
        }
        if (err) {
          failed('http=' + err.code, transient(err.code));
        } else if (response.responseCode !== 200 || typeof response.result !== 'string') {
          failed('response=' + response.responseCode, false);
        } else {
          release();
          audit('WEATHER_HTTP', source + ';attempt=' + attempt + ';ok');
          complete(response.result);
        }
      });
    } catch (err) {
      failed('request_error', false);
    }
  };
  timer = setTimeout(start, 0);
  return (): void => {
    closed = true;
    release();
  };
}
