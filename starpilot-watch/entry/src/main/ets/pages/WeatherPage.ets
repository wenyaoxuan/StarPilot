import { palette, Palette } from '../common/Theme';

const ASTRO_LABELS: string[] = ['', '极好', '很好', '好', '较好', '一般', '偏下', '较差', '差'];

@Component
export struct WeatherPage {
  @Prop redMode: boolean = false;
  @Prop city: string = '';
  @Prop weatherAllowed: boolean = true;
  onPrivacy: () => void = () => {};
  @Prop @Watch('onWxTick') wxTick: number = 0;
  @State cloud: string = '--';
  @State temp: number = 0;
  @State hum: number = 0;
  @State wind: number = 0;
  @State precip: number = 0;
  @State wxTime: number = 0;
  @State seeing: number = 0;
  @State transparency: number = 0;
  @State cloud7: string = '—';
  @State temp7: string = '—';
  @State humidity7: string = '—';
  @State wind7: string = '—';
  @State precip7: string = '—';
  @State wx7Time: number = 0;
  @State wx7Valid: boolean = false;
  @State wx7Current: boolean = false;
  @State primaryCached: boolean = false;
  @State fallback: boolean = false;
  @State busy: boolean = false;
  @State status: string = '';
  onRefresh: () => void = () => {
  };
  onClose: () => void = () => {
  };

  private p(): Palette {
    return palette(this.redMode);
  }

  aboutToAppear(): void {
    this.syncWeather();
  }

  onWxTick(): void {
    this.syncWeather();
  }

  private syncWeather(): void {
    const c = AppStorage.get('wxPrimaryCloud') as string;
    const t = AppStorage.get('wxTemp') as number;
    const h = AppStorage.get('wxHum') as number;
    const w = AppStorage.get('wxWind') as number;
    const p = AppStorage.get('wxPrecip') as number;
    const wt = AppStorage.get('wxTime') as number;
    const s = AppStorage.get('wx7Seeing') as number;
    const tr = AppStorage.get('wx7Transparency') as number;
    const wt7 = AppStorage.get('wx7Time') as number;
    const v7 = AppStorage.get('wx7Valid') as boolean;
    const b = AppStorage.get('wxBusy') as boolean;
    const st = AppStorage.get('wxStatus') as string;
    if (typeof c === 'string') {
      this.cloud = c;
    }
    if (typeof t === 'number') {
      this.temp = t;
    }
    if (typeof h === 'number') {
      this.hum = h;
    }
    if (typeof w === 'number') {
      this.wind = w;
    }
    if (typeof p === 'number') {
      this.precip = p;
    }
    if (typeof wt === 'number') {
      this.wxTime = wt;
    }
    if (typeof s === 'number') {
      this.seeing = s;
    }
    if (typeof tr === 'number') {
      this.transparency = tr;
    }
    this.cloud7 = AppStorage.get<string>('wx7CloudText') ?? '—';
    this.temp7 = AppStorage.get<string>('wx7TempText') ?? '—';
    this.humidity7 = AppStorage.get<string>('wx7HumText') ?? '—';
    this.wind7 = AppStorage.get<string>('wx7WindText') ?? '—';
    this.precip7 = AppStorage.get<string>('wx7PrecipText') ?? '—';
    this.wx7Current = AppStorage.get<boolean>('wx7Current') ?? false;
    this.primaryCached = AppStorage.get<boolean>('wxPrimaryCached') ?? false;
    this.fallback = AppStorage.get<boolean>('wxFallback') ?? false;
    if (typeof wt7 === 'number') {
      this.wx7Time = wt7;
    }
    if (typeof v7 === 'boolean') {
      this.wx7Valid = v7;
    }
    if (typeof b === 'boolean') {
      this.busy = b;
    }
    if (typeof st === 'string') {
      this.status = st;
    }
  }

  private fmtClock(ms: number): string {
    if (ms <= 0) {
      return '--';
    }
    const d: Date = new Date(ms);
    const h: string = d.getHours() < 10 ? `0${d.getHours()}` : `${d.getHours()}`;
    const m: string = d.getMinutes() < 10 ? `0${d.getMinutes()}` : `${d.getMinutes()}`;
    return `${d.getMonth() + 1}/${d.getDate()} ${h}:${m}`;
  }

  private qualityLabel(n: number): string {
    return ASTRO_LABELS[n] ?? '—';
  }

  @Builder
  InfoRow(label: string, value: () => string) {
    Row() {
      Text(label)
        .fontSize(9)
        .fontColor(this.p().dim)
        .width(60)
      Text(value())
        .fontSize(10)
        .fontColor(this.p().fg)
        .layoutWeight(1)
        .textAlign(TextAlign.End)
    }
    .width('100%')
    .padding({ top: 3, bottom: 3 })
  }

  @Builder
  PrimaryPanel() {
    Text(this.wxTime > 0 && this.primaryCached ? 'Open-Meteo · 缓存' : 'Open-Meteo · 常规天气')
      .fontSize(9)
      .fontColor(this.p().accent)
      .width('100%')
    if (this.wxTime > 0) {
      Column() {
        this.InfoRow('云量', () => this.cloud)
        this.InfoRow('温度', () => this.temp.toFixed(0) + '°C')
        this.InfoRow('湿度', () => this.hum.toString() + '%')
        this.InfoRow('风速', () => this.wind.toFixed(1) + ' km/h')
        this.InfoRow('降水概率', () => this.precip >= 0 ? this.precip.toString() + '%' : '—')
        this.InfoRow('更新时间', () => this.fmtClock(this.wxTime))
      }
      .width('100%')
      .padding({ left: 8, right: 8, top: 2, bottom: 2 })
      .backgroundColor(this.p().card)
      .borderRadius(8)
    } else {
      Text('Open-Meteo 暂无数据')
        .fontSize(8)
        .fontColor(this.p().dim)
        .width('100%')
    }
  }

  @Builder
  AstroPanel() {
    Text(this.wx7Valid && !this.wx7Current ? '7Timer ASTRO · 已过预报时刻' : '7Timer ASTRO · 预报')
      .fontSize(9)
      .fontColor(this.p().accent)
      .width('100%')
    if (this.wx7Valid) {
      Column() {
        this.InfoRow('云量', () => this.cloud7)
        this.InfoRow('温度', () => this.temp7)
        this.InfoRow('湿度', () => this.humidity7)
        this.InfoRow('风速', () => this.wind7)
        this.InfoRow('降水类型', () => this.precip7)
        this.InfoRow('视宁度', () => this.seeing.toString() + '/8 · ' + this.qualityLabel(this.seeing))
        this.InfoRow('透明度', () => this.transparency.toString() + '/8 · ' + this.qualityLabel(this.transparency))
        this.InfoRow('预报时间', () => this.fmtClock(this.wx7Time))
      }
      .width('100%')
      .padding({ left: 8, right: 8, top: 2, bottom: 2 })
      .backgroundColor(this.p().card)
      .borderRadius(8)
    } else {
      Text('7Timer 暂无数据')
        .fontSize(8)
        .fontColor(this.p().dim)
        .width('100%')
    }
  }

  build() {
    Scroll() {
      Column({ space: 3 }) {
        Row() {
          Button('← 返回')
            .fontSize(9)
            .height(22)
            .backgroundColor(this.p().card)
            .fontColor(this.p().accent)
            .onClick(() => this.onClose())
          Blank()
          Text('天气 · ' + this.city)
            .fontSize(9)
            .fontColor(this.p().dim)
        }
        .width('100%')

        Button(!this.weatherAllowed ? '隐私设置' : (this.busy ? '刷新中…' : '立即刷新'))
          .fontSize(10)
          .height(28)
          .width('100%')
          .backgroundColor(this.p().card)
          .fontColor(this.busy ? this.p().dim : this.p().accent)
          .enabled(!this.busy)
          .opacity(this.busy ? 0.6 : 1)
          .margin({ top: 2 })
          .onClick(() => {
            if (this.weatherAllowed) {
              this.onRefresh();
            } else {
              this.onPrivacy();
            }
          })

        Text(this.status !== '' ? this.status : '点按立即刷新')
          .fontSize(8)
          .fontColor(this.busy ? this.p().accent : this.p().dim)
          .width('100%')

        if (this.fallback) {
          this.AstroPanel()
          this.PrimaryPanel()
        } else {
          this.PrimaryPanel()
          this.AstroPanel()
        }

        Text('7Timer 云量、湿度和风速为预报区间。视宁、透明等级越小越好。')
          .fontSize(8)
          .fontColor(this.p().dim)
          .width('100%')
        Text(' ')
          .height(6)
      }
      .width('100%')
      .padding({ left: 36, right: 36, top: 34, bottom: 18 })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .backgroundColor('#000000')
  }
}
