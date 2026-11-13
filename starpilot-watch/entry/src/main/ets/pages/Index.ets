import { preferences } from '@kit.ArkData';
import { connection } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { HomePage } from './HomePage';
import { NavPage } from './NavPage';
import { TargetsPage } from './TargetsPage';
import { FramingPage } from './FramingPage';
import { MeteorPage } from './MeteorPage';
import { SatellitePage } from './SatellitePage';
import { StarHopPage } from './StarHopPage';
import { PolarAlignPage } from './PolarAlignPage';
import { PhotoPage } from './PhotoPage';
import { DiagnosticsPage } from './DiagnosticsPage';
import { ArPage } from './ArPage';
import { HorizonPage } from './HorizonPage';
import { WeatherPage } from './WeatherPage';
import { LocationPage } from './LocationPage';
import { PrivacyPage } from './PrivacyPage';
import { vibrateAlert } from '../common/Vibrate';
import { audit } from '../common/AuditLog';
import { CITIES, City, GPS_CITY_NAME, GPS_CITY_REGION, clearGpsCity, ensureGpsCity } from '../data/Cities';
import { defaultSectors, parseSectors, sectorsToString } from '../common/Horizon';
import { maskFromSectors } from '../common/Astro';
import { Palette, palette } from '../common/Theme';
import { fetchWeather } from '../common/Weather';
import { WeatherData } from '../common/WeatherParse';
import { fetchWeather7 } from '../common/Weather7';
import { Weather7Data, cloudBandText, humidityBandText, precipitationTypeText, windBandText } from '../common/Weather7Parse';

@Entry
@Component
struct Index {
  @State current: number = 0;
  @State redMode: boolean = false;
  @State englishNames: boolean = false;
  @State showDiag: boolean = false;
  @State showHorizon: boolean = false;
  @State showAr: boolean = false;
  @State showWeather: boolean = false;
  @State astronomy: number = 0;
  @State foreground: boolean = true;
  @State showLocation: boolean = false;
  @State showPrivacy: boolean = false;
  @State weatherOnlyLocation: boolean = false;
  @State privacyChoice: number = 0;
  @State gpsConsent: boolean = false;
  @State weatherCityIndex: number = 0;
  @State observationCityIndex: number = -1;
  @State gpsTimestamp: number = 0;
  @State sightingCorrection: number = 0;
  @State showSplash: boolean = true;
  @State expiredNote: string = '';
  @State cityIndex: number = 0;
  @State gpsAltitude: number = -10000;
  @State targetId: string = '';
  @State framingId: string = '';
  @State showStarHop: boolean = false;
  @State starHopId: string = '';
  @State targetCrown: number = 0;
  @State horizonSectors: number[] = defaultSectors();
  @State bortle: number = 9;
  @State horizonMask: number[] = [];

  @State wxCloud: string = '--';
  @State wxNote: string = 'S6 天气';
  @State wxTemp: number = 0;
  @State wxHum: number = 0;
  @State wxWind: number = 0;
  @State wxPrecip: number = 0;
  @State wxLastMs: number = 0;
  @State wxValid: boolean = false;
  private wxPrimaryFailed: boolean = false;
  private wxAstroFailed: boolean = false;
  @State wxTick: number = 0;
  @State wxCity: string = '';
  @State wx7City: string = '';

  @State wx7Seeing: number = 0;
  @State wx7Transparency: number = 0;
  @State wx7Cloud: number = 0;
  private wx7Temp: number = -9999;
  private wx7Humidity: number = -9999;
  private wx7Wind: number = 0;
  private wx7Precip: string = '';
  @State wx7ValidMs: number = 0;
  @State wx7FetchMs: number = 0;
  @State wx7Valid: boolean = false;
  @State wxBusy: boolean = false;
  @State wxStatus: string = '';

  private wxTimer: number = -1;
  private wxNetwork: connection.NetConnection | null = null;
  private wxNetId: number = -1;
  private wxNetLost: boolean = false;
  private wxRecoveryPending: boolean = false;
  private wxRecoveryTimer: number = -1;
  private wxLastAttempt: number = 0;
  private cancelPrimary: (() => void) | null = null;
  private cancelAstro: (() => void) | null = null;
  private wxSeq: number = 0;
  private wxDone: number = 0;
  private wxFail: number = 0;
  private wxPending: number = 0;
  private pageIds: number[] = [0, 1, 2, 3];
  private store: preferences.Preferences | null = null;
  private gpsIndex: number = -1;
  private crownAcc: number = 0;

  aboutToAppear(): void {
    try {
      const ctx = this.getUIContext().getHostContext();
      if (ctx !== undefined) {
        this.store = preferences.getPreferencesSync(ctx, { name: 'starpilot_s1' });
        this.redMode = this.store.getSync('red_mode', false) as boolean;
        this.englishNames = this.store.getSync('english_sky_names', false) as boolean;
        const choice: number = this.store.getSync('privacy_weather_v1', 0) as number;
        this.privacyChoice = choice === 1 || choice === 2 ? choice : 0;
        this.gpsConsent = this.store.getSync('privacy_gps_v1', false) === true;
        if (this.privacyChoice !== 0 && this.gpsConsent && this.store.getSync('gps_active', false) === true) {
          const timestamp: number = this.store.getSync('gps_timestamp', 0) as number;
          if (Number.isFinite(timestamp) && timestamp > 0) {
            const gpsLat: number = this.store.getSync('gps_lat', 100) as number;
            const gpsLon: number = this.store.getSync('gps_lon', 200) as number;
            if (gpsLat >= -90 && gpsLat <= 90 && gpsLon >= -180 && gpsLon <= 180) {
              this.gpsIndex = ensureGpsCity(gpsLat, gpsLon);
              this.gpsAltitude = this.store.getSync('gps_alt', -10000) as number;
              this.gpsTimestamp = timestamp;
            }
          }
        }
        const savedCity: number = this.store.getSync('city_index', -1) as number;
        const savedWeatherCity: number = this.store.getSync('weather_city_index', -1) as number;
        const savedObservationCity: number = this.store.getSync('observation_city_index', savedCity) as number;
        this.observationCityIndex = this.isWeatherCity(savedObservationCity) ? savedObservationCity : -1;
        this.cityIndex = this.isWeatherCity(savedCity) ? savedCity :
          (this.gpsIndex >= 0 ? this.gpsIndex : Math.max(0, this.observationCityIndex));
        this.weatherCityIndex = this.isWeatherCity(savedWeatherCity) ? savedWeatherCity :
          Math.max(0, this.observationCityIndex);
        this.targetId = this.store.getSync('target_id', '') as string;
        const raw: string = this.store.getSync('horizon_sectors', '') as string;
        this.horizonSectors = raw.length > 0 ? parseSectors(raw) : defaultSectors();
        this.bortle = this.cityIndex === savedCity ?
          this.store.getSync('bortle', CITIES[this.cityIndex].bortle) as number : CITIES[this.cityIndex].bortle;
        this.horizonMask = maskFromSectors(this.horizonSectors);
        if (this.privacyChoice === 2) {
          this.loadWeatherCache();
        } else {
          this.updateWxNote();
        }
        const end: number = this.store.getSync('timer_end', 0) as number;
        if (end > 0 && end <= Date.now()) {
          this.store.putSync('timer_end', 0);
          this.store.flush();
          this.expiredNote = '上次计时已结束';
          audit('TIMER', 'catch-up at launch');
          vibrateAlert(800);
        }
      }
    } catch (err) {
      this.redMode = false;
      audit('INIT_ERR', JSON.stringify(err));
    }

    setTimeout(() => {
      this.showSplash = false;
      this.restoreMainFocus();
    }, 1500);

    this.watchWeatherNetwork();
    this.refreshAll(false);
    this.wxTimer = setInterval(() => {
      if (this.foreground) {
        this.refreshAll(false);
      }
    }, 10 * 60000);
  }

  aboutToDisappear(): void {
    clearInterval(this.wxTimer);
    clearTimeout(this.wxRecoveryTimer);
    this.cancelWeatherRequests();
    const network: connection.NetConnection | null = this.wxNetwork;
    this.wxNetwork = null;
    if (network !== null) {
      network.unregister((err: BusinessError) => {
        if (err) {
          audit('WEATHER_NET', 'unregister=' + err.code);
        }
      });
    }
  }

  private watchWeatherNetwork(): void {
    try {
      const network: connection.NetConnection = connection.createNetConnection();
      this.wxNetwork = network;
      network.on('netAvailable', (handle: connection.NetHandle) => {
        if (this.wxNetwork !== network) {
          return;
        }
        const changed: boolean = this.wxNetLost || (this.wxNetId !== -1 && this.wxNetId !== handle.netId) ||
          (this.wxNetId === -1 && (this.wxPrimaryFailed || this.wxAstroFailed));
        this.wxNetId = handle.netId;
        this.wxNetLost = false;
        if (changed) {
          this.wxRecoveryPending = true;
          this.scheduleWeatherRecovery();
        }
      });
      network.on('netLost', (handle: connection.NetHandle) => {
        if (this.wxNetwork === network && (this.wxNetId === -1 || handle.netId === this.wxNetId)) {
          this.wxNetLost = true;
          clearTimeout(this.wxRecoveryTimer);
        }
      });
      network.register((err: BusinessError) => {
        if (err) {
          audit('WEATHER_NET', 'register=' + err.code);
        }
      });
    } catch (err) {
      audit('WEATHER_NET', 'observer unavailable');
    }
  }

  private scheduleWeatherRecovery(): void {
    clearTimeout(this.wxRecoveryTimer);
    if (!this.foreground || !this.wxRecoveryPending || this.wxNetLost) {
      return;
    }
    this.wxRecoveryTimer = setTimeout((): void => {
      this.wxRecoveryPending = false;
      const interrupted: boolean = this.wxBusy;
      if (interrupted) {
        this.cancelWeatherRequests();
      }
      this.refreshAll(interrupted, true);
    }, 1200);
  }

  private async logWeatherNetwork(seq: number): Promise<void> {
    try {
      const handle: connection.NetHandle = await connection.getDefaultNet();
      if (handle.netId === 0) {
        audit('WEATHER_NET', 'seq=' + seq + ';no_default');
        return;
      }
      const caps: connection.NetCapabilities = await connection.getNetCapabilities(handle);
      audit('WEATHER_NET', 'seq=' + seq + ';net=' + handle.netId + ';bearers=' + caps.bearerTypes.join(',') +
        ';validated=' + (caps.networkCap?.includes(connection.NetCap.NET_CAPABILITY_VALIDATED) ?? false));
    } catch (err) {
      audit('WEATHER_NET', 'seq=' + seq + ';unknown');
    }
  }

  private cancelWeatherRequests(): void {
    this.wxSeq++;
    this.cancelPrimary?.();
    this.cancelAstro?.();
    this.cancelPrimary = null;
    this.cancelAstro = null;
    this.wxBusy = false;
  }

  private fmtClock(ms: number): string {
    const d: Date = new Date(ms);
    const h: string = d.getHours() < 10 ? `0${d.getHours()}` : `${d.getHours()}`;
    const m: string = d.getMinutes() < 10 ? `0${d.getMinutes()}` : `${d.getMinutes()}`;
    return `${h}:${m}`;
  }

  private weatherKey(city: City): string {
    return `${city.name}|${city.lat.toFixed(4)}|${city.lon.toFixed(4)}`;
  }

  private isWeatherCity(index: number): boolean {
    return Number.isInteger(index) && index >= 0 && index < CITIES.length && CITIES[index].region !== GPS_CITY_REGION;
  }

  private weatherCity(): City {
    return CITIES[this.isWeatherCity(this.weatherCityIndex) ? this.weatherCityIndex : 0];
  }

  private chooseWeatherPrivacy(allowed: boolean): boolean {
    if (this.store === null) {
      return false;
    }
    try {
      this.store.putSync('privacy_weather_v1', allowed ? 2 : 1);
      this.store.flushSync();
    } catch (err) {
      if (this.privacyChoice !== 0) {
        this.privacyChoice = 1;
      }
      this.resetWeather();
      this.updateWxNote();
      return false;
    }
    this.privacyChoice = allowed ? 2 : 1;
    this.resetWeather();
    if (allowed) {
      this.loadWeatherCache();
      this.refreshAll();
    } else {
      this.updateWxNote();
    }
    return true;
  }

  private allowLocalGps(): boolean {
    if (this.store === null || this.privacyChoice === 0) {
      return false;
    }
    try {
      this.store.putSync('privacy_gps_v1', true);
      this.store.flushSync();
      this.gpsConsent = true;
      return true;
    } catch (err) {
      return false;
    }
  }

  private removeLocalGps(): boolean {
    this.sightingCorrection = 0;
    this.gpsConsent = false;
    if (this.cityIndex === this.gpsIndex) {
      this.cityIndex = Math.max(0, this.observationCityIndex);
      this.bortle = CITIES[this.cityIndex].bortle;
    }
    clearGpsCity();
    this.gpsIndex = -1;
    this.gpsAltitude = -10000;
    this.gpsTimestamp = 0;
    if (this.store === null) {
      return false;
    }
    try {
      this.store.putSync('privacy_gps_v1', false);
      this.store.putSync('gps_active', false);
      this.store.putSync('city_index', this.observationCityIndex);
      this.store.putSync('bortle', this.bortle);
      for (const key of ['gps_lat', 'gps_lon', 'gps_alt', 'gps_acc', 'gps_timestamp']) {
        this.store.deleteSync(key);
      }
      for (const prefix of ['wx', 'wx7']) {
        const name: string = this.store.getSync(prefix + '_city', '') as string;
        if (name === GPS_CITY_NAME) {
          this.store.deleteSync(prefix + '_key');
          this.store.deleteSync(prefix + '_city');
        }
      }
      this.store.flushSync();
      return true;
    } catch (err) {
      return false;
    }
  }

  private loadWeatherCache(): void {
    if (this.store === null) {
      return;
    }
    const city: City = this.weatherCity();
    const key: string = this.weatherKey(city);
    const primaryCacheKey: string = this.store.getSync('wx_key', '') as string;
    const astroCacheKey: string = this.store.getSync('wx7_key', '') as string;
    const primaryMatches: boolean = primaryCacheKey === key ||
      (primaryCacheKey === '' && this.store.getSync('wx_city', '') === city.name);
    const astroMatches: boolean = astroCacheKey === key ||
      (astroCacheKey === '' && this.store.getSync('wx7_city', '') === city.name);
    const cloud: number = this.store.getSync('wx_cloud', -1) as number;
    if (cloud >= 0 && primaryMatches) {
      this.wxTemp = this.store.getSync('wx_temp', 0) as number;
      this.wxHum = this.store.getSync('wx_hum', 0) as number;
      this.wxWind = this.store.getSync('wx_wind', 0) as number;
      this.wxPrecip = this.store.getSync('wx_precip', 0) as number;
      this.wxLastMs = this.store.getSync('wx_time', 0) as number;
      this.wxValid = true;
      this.wxCity = key;
      this.wxCloud = `${Math.round(cloud)}%`;
    }
    const seeing: number = this.store.getSync('wx7_seeing', 0) as number;
    if (seeing > 0 && astroMatches) {
      this.wx7Seeing = seeing;
      this.wx7Transparency = this.store.getSync('wx7_transparency', 0) as number;
      this.wx7Cloud = this.store.getSync('wx7_cloud', 0) as number;
      this.wx7ValidMs = this.store.getSync('wx7_valid_ms', 0) as number;
      this.wx7FetchMs = this.store.getSync('wx7_fetch_ms', 0) as number;
      this.wx7Valid = true;
      this.wx7City = key;
      this.wx7Temp = this.store.getSync('wx7_temp', -9999) as number;
      this.wx7Humidity = this.store.getSync('wx7_humidity', -9999) as number;
      this.wx7Wind = this.store.getSync('wx7_wind', 0) as number;
      this.wx7Precip = this.store.getSync('wx7_precip', '') as string;
    }
    this.updateWxNote();
  }

  private currentAstro(): boolean {
    return this.wx7Valid && Date.now() <= this.wx7ValidMs;
  }

  private useAstroSummary(): boolean {
    return this.currentAstro() && (!this.wxValid || this.wxPrimaryFailed || Date.now() - this.wxLastMs >= 30 * 60000);
  }

  private publishWeather(): void {
    AppStorage.setOrCreate('wxCloud', this.useAstroSummary() ? cloudBandText(this.wx7Cloud) : this.wxCloud);
    AppStorage.setOrCreate('wxPrimaryCloud', this.wxCloud);
    AppStorage.setOrCreate('wxPrimaryCached', this.wxPrimaryFailed || Date.now() - this.wxLastMs >= 30 * 60000);
    AppStorage.setOrCreate('wxTemp', this.wxTemp);
    AppStorage.setOrCreate('wxHum', this.wxHum);
    AppStorage.setOrCreate('wxWind', this.wxWind);
    AppStorage.setOrCreate('wxPrecip', this.wxPrecip);
    AppStorage.setOrCreate('wxTime', this.wxLastMs);
    AppStorage.setOrCreate('wx7Seeing', this.wx7Seeing);
    AppStorage.setOrCreate('wx7Transparency', this.wx7Transparency);
    AppStorage.setOrCreate('wx7Cloud', this.wx7Cloud);
    AppStorage.setOrCreate('wx7CloudText', cloudBandText(this.wx7Cloud));
    AppStorage.setOrCreate('wx7TempText', this.wx7Temp > -9999 ? `${this.wx7Temp}°C` : '—');
    AppStorage.setOrCreate('wx7HumText', humidityBandText(this.wx7Humidity));
    AppStorage.setOrCreate('wx7WindText', windBandText(this.wx7Wind));
    AppStorage.setOrCreate('wx7PrecipText', precipitationTypeText(this.wx7Precip));
    AppStorage.setOrCreate('wx7Time', this.wx7ValidMs);
    AppStorage.setOrCreate('wx7Valid', this.wx7Valid);
    AppStorage.setOrCreate('wx7Current', this.currentAstro());
    AppStorage.setOrCreate('wxFallback', this.useAstroSummary());
    AppStorage.setOrCreate('wxBusy', this.wxBusy);
    AppStorage.setOrCreate('wxStatus', this.wxStatus);
  }

  private updateWxNote(): void {
    if (this.privacyChoice !== 2) {
      this.wxNote = '城市天气已关闭';
      this.wxStatus = '可在主页「隐私」开启城市天气';
    } else if (this.useAstroSummary()) {
      const temp: string = this.wx7Temp > -9999 ? `${this.wx7Temp}°C · ` : '';
      this.wxNote = `${temp}7Timer 预报\n视宁 ${this.wx7Seeing}/8 · ${this.fmtClock(this.wx7ValidMs)}`;
    } else if (this.wxValid) {
      const cache: boolean = this.wxPrimaryFailed || Date.now() - this.wxLastMs >= 30 * 60000;
      const detail: string = cache ? 'Open-Meteo 缓存' :
        (this.currentAstro() ? `视宁 ${this.wx7Seeing}/8 · 透明 ${this.wx7Transparency}/8` : 'Open-Meteo');
      this.wxNote = `${this.wxTemp.toFixed(0)}°C 湿${this.wxHum}%\n${detail}`;
    } else {
      this.wxNote = this.wxBusy ? '天气更新中…' : '天气暂无数据';
    }
    AppStorage.setOrCreate('wxNote', this.wxNote);
    this.publishWeather();
    this.wxTick++;
  }

  private refreshWeather(city: City, key: string, seq: number): void {
    const cityName: string = city.name;
    this.cancelPrimary = fetchWeather(city.lat, city.lon, (d: WeatherData | null) => {
      if (seq !== this.wxSeq) {
        return;
      }
      this.cancelPrimary = null;
      this.wxPrimaryFailed = d === null;
      if (d === null) {
        audit('WEATHER_ERR', 'open-meteo null');
        this.finishRefresh(seq, 'Open-Meteo', false);
        return;
      }
      this.wxValid = true;
      this.wxCity = key;
      this.wxCloud = `${Math.round(d.cloudCover)}%`;
      this.wxTemp = d.tempC;
      this.wxHum = d.humidity;
      this.wxWind = d.windKmh;
      this.wxPrecip = d.precipProb;
      this.wxLastMs = d.updateMs;
      try {
        if (this.store !== null) {
          this.store.putSync('wx_city', cityName);
          this.store.putSync('wx_key', key);
          this.store.putSync('wx_cloud', d.cloudCover);
          this.store.putSync('wx_temp', d.tempC);
          this.store.putSync('wx_hum', d.humidity);
          this.store.putSync('wx_wind', d.windKmh);
          this.store.putSync('wx_precip', d.precipProb);
          this.store.putSync('wx_time', d.updateMs);
          this.store.flush();
        }
      } catch (err) {
        audit('WEATHER_ERR', `save ${JSON.stringify(err)}`);
      }
      audit('WEATHER', `city=${cityName};cloud=${d.cloudCover};temp=${d.tempC};hum=${d.humidity};wind=${d.windKmh};precip=${d.precipProb}`);
      this.finishRefresh(seq, 'Open-Meteo', true);
    });
  }

  private refresh7(city: City, key: string, seq: number): void {
    const cityName: string = city.name;
    this.cancelAstro = fetchWeather7(city.lat, city.lon, (d: Weather7Data | null) => {
      if (seq !== this.wxSeq) {
        return;
      }
      this.cancelAstro = null;
      this.wxAstroFailed = d === null;
      if (d === null) {
        audit('WEATHER7_ERR', '7timer null');
        this.finishRefresh(seq, '7Timer', false);
        return;
      }
      this.wx7Valid = true;
      this.wx7City = key;
      this.wx7Seeing = d.seeing;
      this.wx7Transparency = d.transparency;
      this.wx7Cloud = d.cloud7;
      this.wx7Temp = d.tempC;
      this.wx7Humidity = d.humidityBand;
      this.wx7Wind = d.windBand;
      this.wx7Precip = d.precipType;
      this.wx7ValidMs = d.validMs;
      this.wx7FetchMs = Date.now();
      try {
        if (this.store !== null) {
          this.store.putSync('wx7_city', cityName);
          this.store.putSync('wx7_key', key);
          this.store.putSync('wx7_seeing', d.seeing);
          this.store.putSync('wx7_transparency', d.transparency);
          this.store.putSync('wx7_cloud', d.cloud7);
          this.store.putSync('wx7_temp', d.tempC);
          this.store.putSync('wx7_humidity', d.humidityBand);
          this.store.putSync('wx7_wind', d.windBand);
          this.store.putSync('wx7_precip', d.precipType);
          this.store.putSync('wx7_valid_ms', d.validMs);
          this.store.putSync('wx7_fetch_ms', this.wx7FetchMs);
          this.store.flush();
        }
      } catch (err) {
        audit('WEATHER7_ERR', `save ${JSON.stringify(err)}`);
      }
      audit('WEATHER7', `city=${cityName};cloud=${d.cloud7};seeing=${d.seeing};transparency=${d.transparency};valid=${d.validMs}`);
      this.finishRefresh(seq, '7Timer', true);
    });
  }

  private finishRefresh(seq: number, label: string, ok: boolean): void {
    if (seq !== this.wxSeq) {
      return;
    }
    this.wxDone++;
    if (!ok) {
      this.wxFail++;
    }
    if (this.wxDone < this.wxPending) {
      this.wxStatus = `${label}${ok ? '已更新' : '暂不可用'}，另一源仍在刷新…`;
    } else {
      this.wxBusy = false;
      if (this.wxFail === this.wxPending) {
        this.wxStatus = this.wxValid || this.wx7Valid ? '刷新失败，显示缓存' : '天气源暂不可用';
      } else if (this.useAstroSummary()) {
        this.wxStatus = '当前显示 7Timer 预报';
      } else if (this.wxFail === 0) {
        this.wxStatus = `已刷新 ${this.fmtClock(Date.now())}`;
      } else {
        this.wxStatus = '部分天气源暂不可用';
      }
    }
    this.updateWxNote();
  }

  private refreshAll(force: boolean = true, recovered: boolean = false): void {
    if (this.privacyChoice !== 2 || this.wxBusy) {
      return;
    }
    const city: City = this.weatherCity();
    const key: string = this.weatherKey(city);
    const now: number = Date.now();
    if (!force && !recovered && now - this.wxLastAttempt < 15000) {
      return;
    }
    const primary: boolean = force || this.wxPrimaryFailed || this.wxCity !== key || now - this.wxLastMs >= 30 * 60000;
    const astro: boolean = force || this.wxAstroFailed || this.wx7City !== key || !this.currentAstro() ||
      now - this.wx7FetchMs >= 2 * 3600000;
    this.wxPending = Number(primary) + Number(astro);
    if (this.wxPending === 0) {
      return;
    }
    const seq: number = ++this.wxSeq;
    this.wxLastAttempt = now;
    this.wxDone = 0;
    this.wxFail = 0;
    this.wxBusy = true;
    this.wxStatus = '刷新中…';
    this.updateWxNote();
    this.logWeatherNetwork(seq);
    if (primary) {
      this.refreshWeather(city, key, seq);
    }
    if (astro) {
      this.refresh7(city, key, seq);
    }
  }

  private saveHorizon(sectors: number[], bortle: number): void {
    this.horizonSectors = sectors;
    this.bortle = bortle;
    this.horizonMask = maskFromSectors(sectors);
    this.showHorizon = false;
    try {
      if (this.store !== null) {
        this.store.putSync('horizon_sectors', sectorsToString(sectors));
        this.store.putSync('bortle', bortle);
        this.store.flush();
      }
    } catch (err) {
      audit('HORIZON_ERR', JSON.stringify(err));
    }
  }

  private resetWeather(): void {
    this.cancelWeatherRequests();
    this.wxValid = false;
    this.wxPrimaryFailed = false;
    this.wxAstroFailed = false;
    this.wx7Valid = false;
    this.wxCloud = '--';
    this.wxNote = '更新中';
    this.wxLastMs = 0;
    this.wx7FetchMs = 0;
    this.wx7ValidMs = 0;
    this.wxCity = '';
    this.wx7City = '';
    this.wxBusy = false;
    this.wxStatus = '';
    AppStorage.setOrCreate('wxCloud', '--');
    AppStorage.setOrCreate('wxNote', '更新中');
    this.publishWeather();
    this.wxTick++;
  }

  private selectCity(index: number): void {
    if (index < 0 || index >= CITIES.length) {
      return;
    }
    this.cityIndex = index;
    this.sightingCorrection = 0;
    this.bortle = CITIES[index].bortle;
    if (this.isWeatherCity(index)) {
      this.observationCityIndex = index;
    }
    const weatherChanged: boolean = this.isWeatherCity(index) && this.weatherCityIndex !== index;
    if (weatherChanged) {
      this.weatherCityIndex = index;
    }
    try {
      if (this.store !== null) {
        this.store.putSync('city_index', index);
        this.store.putSync('observation_city_index', this.observationCityIndex);
        this.store.putSync('bortle', this.bortle);
        this.store.putSync('gps_active', index === this.gpsIndex);
        this.store.putSync('weather_city_index', this.weatherCityIndex);
        this.store.flush();
      }
    } catch (err) {
      audit('CITY_ERR', JSON.stringify(err));
    }
    if (weatherChanged) {
      this.resetWeather();
      this.updateWxNote();
      this.refreshAll();
    }
    setTimeout(() => {
      this.showLocation = false;
      this.restoreMainFocus();
    }, 120);
  }

  private selectWeatherCity(index: number): void {
    if (!this.isWeatherCity(index)) {
      return;
    }
    this.weatherCityIndex = index;
    try {
      this.store?.putSync('weather_city_index', index);
      this.store?.flush();
    } catch (err) {
      audit('WEATHER_ERR', 'weather city save failed');
    }
    this.resetWeather();
    this.updateWxNote();
    this.refreshAll();
    this.showLocation = false;
    this.showPrivacy = true;
  }

  private applyGpsFix(lat: number, lon: number, alt: number, accuracy: number, timestamp: number): void {
    if (!this.gpsConsent) {
      return;
    }
    this.gpsIndex = ensureGpsCity(lat, lon);
    this.sightingCorrection = 0;
    this.gpsAltitude = alt;
    this.gpsTimestamp = timestamp;
    this.cityIndex = this.gpsIndex;
    this.bortle = CITIES[this.gpsIndex].bortle;
    try {
      if (this.store !== null) {
        this.store.putSync('city_index', this.gpsIndex);
        this.store.putSync('observation_city_index', this.observationCityIndex);
        this.store.putSync('bortle', this.bortle);
        this.store.putSync('gps_active', true);
        this.store.putSync('gps_lat', lat);
        this.store.putSync('gps_lon', lon);
        this.store.putSync('gps_alt', alt);
        this.store.putSync('gps_acc', accuracy);
        this.store.putSync('gps_timestamp', timestamp);
        this.store.flush();
      }
    } catch (err) {
      audit('GPS_SAVE_ERR', JSON.stringify(err));
    }
    audit('GPS_CITY', 'local fix saved');
  }

  private selectTarget(id: string): void {
    this.targetId = id;
    this.current = 1;
    try {
      if (this.store !== null) {
        this.store.putSync('target_id', id);
        this.store.flush();
      }
    } catch (err) {
      audit('TARGET_ERR', JSON.stringify(err));
    }
  }

  private clearTarget(): void {
    this.targetId = '';
    try {
      if (this.store !== null) {
        this.store.putSync('target_id', '');
        this.store.flush();
      }
    } catch (err) {
      audit('TARGET_ERR', JSON.stringify(err));
    }
  }

  private toggleRed(): void {
    this.redMode = !this.redMode;
    try {
      if (this.store !== null) {
        this.store.putSync('red_mode', this.redMode);
        this.store.flush();
      }
    } catch (err) {
      // preference failure must not block the UI
    }
  }

  private toggleSkyNames(): void {
    this.englishNames = !this.englishNames;
    try {
      if (this.store !== null) {
        this.store.putSync('english_sky_names', this.englishNames);
        this.store.flush();
      }
    } catch (err) {
      audit('SKY_NAMES_ERR', JSON.stringify(err));
    }
  }

  private restoreMainFocus(): void {
    setTimeout(() => {
      try {
        this.getUIContext().getFocusController().requestFocus('mainSwiper');
      } catch (err) {
        // focus is best-effort
      }
    }, 120);
  }

  private goPage(delta: number): void {
    const next: number = this.current + delta;
    if (next < 0 || next >= this.pageIds.length) {
      this.crownAcc = 0;
      return;
    }
    this.current = next;
    this.crownAcc = 0;
    audit('CROWN', `page=${next}`);
    try {
      this.getUIContext().getFocusController().requestFocus('mainSwiper');
    } catch (err) {
      // focus is best-effort
    }
  }

  private onCrown(event: CrownEvent): void {
    if (this.framingId !== '' || this.showStarHop) {
      return;
    }
    if (event.action === CrownAction.BEGIN) {
      this.crownAcc = 0;
      return;
    }
    if (event.action !== CrownAction.UPDATE) {
      return;
    }
    this.crownAcc += event.degree;
    if (this.current === 2) {
      if (this.crownAcc >= 20) {
        this.targetCrown++;
        this.crownAcc = 0;
        audit('CROWN', `catalog=${this.targetCrown}`);
      } else if (this.crownAcc <= -20) {
        this.targetCrown--;
        this.crownAcc = 0;
        audit('CROWN', `catalog=${this.targetCrown}`);
      }
      return;
    }
    if (this.crownAcc >= 20) {
      this.goPage(1);
    } else if (this.crownAcc <= -20) {
      this.goPage(-1);
    }
  }

  onPageShow(): void {
    this.foreground = true;
    if (this.wxRecoveryPending) {
      this.scheduleWeatherRecovery();
    } else {
      this.refreshAll(false);
    }
  }

  onPageHide(): void {
    this.foreground = false;
    clearTimeout(this.wxRecoveryTimer);
  }

  private knownSatelliteAltitude(): boolean {
    return this.gpsIndex === this.cityIndex && this.gpsAltitude >= -500 && this.gpsAltitude <= 9000;
  }

  private astronomyPalette(): Palette {
    return palette(this.redMode);
  }

  private openStarHop(targetId: string): void {
    this.starHopId = targetId;
    this.showStarHop = true;
  }

  @Builder
  AstronomyMenu() {
    Column({ space: 6 }) {
      Row() {
        Button('返回').width(42).height(24).padding(0).fontSize(9)
          .backgroundColor(this.astronomyPalette().card).fontColor(this.astronomyPalette().accent)
          .onClick(() => { this.astronomy = 0; this.restoreMainFocus(); })
        Text('天文工具').fontSize(12).fontColor(this.astronomyPalette().accent)
          .textAlign(TextAlign.Center).layoutWeight(1)
        Blank().width(42)
      }.width('100%')
      Button('流星雨').height(30).width('100%').fontSize(11)
        .backgroundColor(this.astronomyPalette().card).fontColor(this.astronomyPalette().fg)
        .onClick(() => { this.astronomy = 2; })
      Button('ISS 卫星过境').height(30).width('100%').fontSize(11)
        .backgroundColor(this.astronomyPalette().card).fontColor(this.astronomyPalette().fg)
        .onClick(() => { this.astronomy = 3; })
      Button('手动星桥').height(30).width('100%').fontSize(11)
        .backgroundColor(this.astronomyPalette().card).fontColor(this.astronomyPalette().fg)
        .onClick(() => this.openStarHop(''))
      Button('极轴辅助').height(30).width('100%').fontSize(11)
        .backgroundColor(this.astronomyPalette().card).fontColor(this.astronomyPalette().fg)
        .onClick(() => { this.astronomy = 4; })
    }.width('100%').height('100%').padding({ left: 34, right: 34, top: 32 })
      .backgroundColor(this.astronomyPalette().bg)
  }

  build() {
    Stack() {
      if (this.privacyChoice === 0 || this.showPrivacy) {
        PrivacyPage({
          first: this.privacyChoice === 0,
          weatherAllowed: this.privacyChoice === 2,
          gpsAllowed: this.gpsConsent,
          city: this.weatherCity().name,
          redMode: this.redMode,
          onWeatherChoice: (allowed: boolean) => this.chooseWeatherPrivacy(allowed),
          onClearGps: () => this.removeLocalGps(),
          onChooseCity: () => {
            this.showPrivacy = false;
            this.weatherOnlyLocation = true;
            this.showLocation = true;
          },
          onClose: () => {
            this.showPrivacy = false;
            this.restoreMainFocus();
          }
        })
      } else if (this.showLocation) {
        LocationPage({
          redMode: this.redMode,
          cityIndex: this.weatherOnlyLocation ? this.weatherCityIndex : this.cityIndex,
          weatherOnly: this.weatherOnlyLocation,
          gpsAllowed: this.gpsConsent,
          gpsTimestamp: this.gpsTimestamp,
          onAllowGps: () => this.allowLocalGps(),
          onSelect: (index: number) => {
            if (this.weatherOnlyLocation) {
              this.selectWeatherCity(index);
            } else {
              this.selectCity(index);
            }
          },
          onGpsFix: (lat: number, lon: number, alt: number, accuracy: number, timestamp: number) =>
            this.applyGpsFix(lat, lon, alt, accuracy, timestamp),
          onClose: () => {
            this.showLocation = false;
            if (this.weatherOnlyLocation) {
              this.showPrivacy = true;
            }
            this.restoreMainFocus();
          }
        })
      } else if (this.astronomy === 4) {
        PolarAlignPage({
          redMode: this.redMode,
          englishNames: this.englishNames,
          cityIndex: this.cityIndex,
          altitudeM: this.knownSatelliteAltitude() ? this.gpsAltitude : 0,
          horizonMask: this.horizonMask,
          foreground: this.foreground,
          onClose: () => { this.astronomy = 1; }
        })
      } else if (this.astronomy === 3) {
        SatellitePage({
          redMode: this.redMode,
          cityIndex: this.cityIndex,
          altitudeM: this.knownSatelliteAltitude() ? this.gpsAltitude : 0,
          altitudeKnown: this.knownSatelliteAltitude(),
          foreground: this.foreground,
          onClose: () => { this.astronomy = 1; }
        })
      } else if (this.astronomy === 2) {
        MeteorPage({
          redMode: this.redMode,
          englishNames: this.englishNames,
          cityIndex: this.cityIndex,
          horizonMask: this.horizonMask,
          onClose: () => { this.astronomy = 1; }
        })
      } else if (this.astronomy === 1) {
        this.AstronomyMenu()
      } else if (this.showWeather) {
        WeatherPage({
          redMode: this.redMode,
          city: this.weatherCity().name,
          weatherAllowed: this.privacyChoice === 2,
          onPrivacy: () => {
            this.showWeather = false;
            this.showPrivacy = true;
          },
          wxTick: this.wxTick,
          onRefresh: () => this.refreshAll(),
          onClose: () => {
            this.showWeather = false;
            this.restoreMainFocus();
          }
        })
      } else if (this.showHorizon) {
        HorizonPage({
          sectors: this.horizonSectors,
          bortle: this.bortle,
          onSave: (sectors: number[], bortle: number) => this.saveHorizon(sectors, bortle),
          onClose: () => {
            this.showHorizon = false;
            this.restoreMainFocus();
          }
        })
      } else if (this.showAr) {
        ArPage({
          sightingCorrection: this.sightingCorrection,
          redMode: this.redMode,
          englishNames: this.englishNames,
          onToggleNames: () => this.toggleSkyNames(),
          cityIndex: this.cityIndex,
          targetId: this.targetId,
          onClose: () => {
            this.showAr = false;
            this.restoreMainFocus();
          }
        })
      } else if (this.showDiag) {
        DiagnosticsPage({ cityIndex: this.cityIndex, onClose: () => {
          this.showDiag = false;
          this.restoreMainFocus();
        } })
      } else {
        Column() {
          Swiper() {
            HomePage({
              active: this.current === 0,
              redMode: this.redMode,
              expiredNote: this.expiredNote,
              cityIndex: this.cityIndex,
              defaultCity: this.observationCityIndex < 0,
              wxTick: this.wxTick,
              onOpenLocation: () => {
                this.weatherOnlyLocation = false;
                this.showLocation = true;
              },
              onOpenPrivacy: () => { this.showPrivacy = true; },
              onOpenWeather: () => {
                this.showWeather = true;
              },
              onOpenAstronomy: () => {
                this.astronomy = 1;
              },
              onToggleRed: () => this.toggleRed(),
              onOpenDiag: () => {
                this.showDiag = true;
              }
            })
            NavPage({
              sightingCorrection: this.sightingCorrection,
              onSightingCorrection: (value: number) => { this.sightingCorrection = value; },
              active: this.current === 1,
              redMode: this.redMode,
              englishNames: this.englishNames,
              cityIndex: this.cityIndex,
              targetId: this.targetId,
              horizonMask: this.horizonMask,
              onOpenHorizon: () => {
                this.showHorizon = true;
              },
              onOpenAr: () => {
                this.showAr = true;
              },
              onChooseTarget: () => {
                this.current = 2;
              },
              onClearTarget: () => this.clearTarget()
            })
            TargetsPage({
              active: this.current === 2 && this.framingId === '' && !this.showStarHop,
              redMode: this.redMode,
              englishNames: this.englishNames,
              onToggleNames: () => this.toggleSkyNames(),
              cityIndex: this.cityIndex,
              horizonMask: this.horizonMask,
              crownStep: this.targetCrown,
              onNavigate: (id: string) => this.selectTarget(id),
              onFrame: (id: string) => { this.framingId = id; },
              onStarHop: (id: string) => this.openStarHop(id)
            })
            PhotoPage({ active: this.current === 3, redMode: this.redMode, targetId: this.targetId, bortle: this.bortle })
          }
          .id('mainSwiper')
          .focusable(true)
          .defaultFocus(true)
          .index(this.current)
          .loop(false)
          .disableSwipe(this.framingId !== '' || this.showStarHop)
          .indicator(false)
          .onChange((index: number) => {
            this.current = index;
          })
          .onDigitalCrown((event: CrownEvent) => this.onCrown(event))
          .width('100%')
          .layoutWeight(1)

          Row({ space: 5 }) {
            ForEach(this.pageIds, (id: number) => {
              Row()
                .width(5)
                .height(5)
                .borderRadius(2.5)
                .backgroundColor(this.current === id ? '#FF453A' : '#3A3A3C')
            }, (id: number) => id.toString())
          }
          .width('100%')
          .height(14)
          .justifyContent(FlexAlign.Center)
        }
        .width('100%')
        .height('100%')
      }

      if (this.framingId !== '') {
        FramingPage({
          targetId: this.framingId,
          redMode: this.redMode,
          englishNames: this.englishNames,
          onClose: () => {
            this.framingId = '';
            this.restoreMainFocus();
          }
        })
      }

      if (this.showStarHop) {
        StarHopPage({
          targetId: this.starHopId,
          redMode: this.redMode,
          englishNames: this.englishNames,
          cityIndex: this.cityIndex,
          bortle: this.bortle,
          horizonMask: this.horizonMask,
          onClose: () => {
            this.showStarHop = false;
            if (this.astronomy === 0) {
              this.restoreMainFocus();
            }
          },
          onBrowse: () => {
            this.astronomy = 0;
            this.current = 2;
            this.showStarHop = false;
            this.restoreMainFocus();
          }
        })
      }

      if (this.showSplash && this.privacyChoice !== 0) {
        Column() {
          Image($r('app.media.splash_logo'))
            .width('100%')
            .height('100%')
            .objectFit(ImageFit.Contain)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor('#000000')
        .onClick(() => {
          this.showSplash = false;
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#000000')
  }
}
