import { batteryInfo } from '@kit.BasicServicesKit';
import { palette, Palette } from '../common/Theme';
import {
  astronomicalTwilight,
  equatorialToHorizontal,
  jdFromUnixMs,
  moonEquatorial,
  moonPhase,
  Twilight,
  MoonPhase,
  Horizontal
} from '../common/Astro';
import { CITIES, City, GPS_CITY_REGION } from '../data/Cities';
import { audit } from '../common/AuditLog';

@Component
export struct HomePage {
  @Prop @Watch('onActiveChanged') active: boolean = false;
  @Prop redMode: boolean = false;
  @Prop expiredNote: string = '';
  @Prop @Watch('onCityChanged') cityIndex: number = 0;
  @Prop defaultCity: boolean = true;
  @Prop @Watch('onWxTick') wxTick: number = 0;
  @State wxCloudText: string = '--';
  @State wxNoteText: string = 'S6 天气';
  onOpenLocation: () => void = () => {
  };
  onToggleRed: () => void = () => {
  };
  onOpenDiag: () => void = () => {
  };
  onOpenWeather: () => void = () => {
  };
  onOpenAstronomy: () => void = () => {};
  onOpenPrivacy: () => void = () => {};

  @State clock: string = '--:--';
  @State dateText: string = '';
  @State battery: string = '--';
  @State twilightValue: string = '--';
  @State twilightNote: string = 'S2 历算';
  @State moonValue: string = '--';
  @State moonNote: string = 'S2 历算';
  private timerId: number = -1;
  private astroCounter: number = 0;

  private p(): Palette {
    return palette(this.redMode);
  }

  private city(): City {
    return CITIES[this.cityIndex];
  }

  private locationLabel(): string {
    const city: City = this.city();
    if (city.region === GPS_CITY_REGION) {
      return '上次 GPS';
    }
    return `${this.defaultCity ? '默认' : '城市'} · ${city.name}`;
  }

  aboutToAppear(): void {
    this.syncWeather();
    this.refreshAstro();
    if (this.active) {
      this.start();
    }
  }

  aboutToDisappear(): void {
    this.stop();
  }

  onCityChanged(): void {
    this.refreshAstro();
  }

  onWxTick(): void {
    this.syncWeather();
  }

  private syncWeather(): void {
    const c = AppStorage.get('wxCloud') as string;
    const n = AppStorage.get('wxNote') as string;
    if (typeof c === 'string' && c.length > 0) {
      this.wxCloudText = c;
    }
    if (typeof n === 'string' && n.length > 0) {
      this.wxNoteText = n;
    }
    audit('WX_SYNC', `cloud=${c};note=${n};tick=${this.wxTick}`);
  }

  onActiveChanged(): void {
    if (this.active) {
      this.start();
    } else {
      this.stop();
    }
  }

  private start(): void {
    if (this.timerId !== -1) {
      return;
    }
    this.tick();
    this.timerId = setInterval(() => {
      this.tick();
    }, 1000);
  }

  private stop(): void {
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  private pad(n: number): string {
    return n < 10 ? `0${n}` : `${n}`;
  }

  private tick(): void {
    const now: Date = new Date();
    this.clock = `${this.pad(now.getHours())}:${this.pad(now.getMinutes())}`;
    const week: string[] = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
    this.dateText = `${week[now.getDay()]} ${now.getMonth() + 1}月${now.getDate()}日`;
    try {
      this.battery = `${batteryInfo.batterySOC}%`;
    } catch (err) {
      this.battery = '--';
    }
    this.astroCounter++;
    if (this.astroCounter >= 60) {
      this.astroCounter = 0;
      this.refreshAstro();
    }
  }

  private fmtTime(ms: number): string {
    const d: Date = new Date(ms);
    return `${this.pad(d.getHours())}:${this.pad(d.getMinutes())}`;
  }

  private refreshAstro(): void {
    try {
      const now: Date = new Date();
      // The observing night that contains "now": after local noon it is the
      // coming night, before noon it is the night that started yesterday.
      const nightRef: Date = new Date(now.getFullYear(), now.getMonth(), now.getDate());
      if (now.getHours() < 12) {
        nightRef.setDate(nightRef.getDate() - 1);
      }
      const midnight: number = nightRef.getTime();
      const tw: Twilight = astronomicalTwilight(midnight, this.city().lat, this.city().lon);
      const jd: number = jdFromUnixMs(now.getTime());
      const phase: MoonPhase = moonPhase(jd);
      const moonHor: Horizontal = equatorialToHorizontal(moonEquatorial(jd), jd, this.city().lat, this.city().lon);

      this.moonValue = `${Math.round(phase.illumination * 100)}%`;
      this.moonNote = `${phase.phaseName} · 高度 ${moonHor.altDeg.toFixed(0)}°`;

      if (tw.eveningEndMs <= 0) {
        this.twilightValue = '--';
        this.twilightNote = '极昼/极夜';
      } else {
        const nowMs: number = now.getTime();
        if (nowMs < tw.eveningEndMs) {
          this.twilightValue = this.fmtTime(tw.eveningEndMs);
          const mins: number = Math.round((tw.eveningEndMs - nowMs) / 60000);
          this.twilightNote = `距暗夜 ${Math.floor(mins / 60)}h${mins % 60}m`;
        } else if (tw.morningStartMs > 0 && nowMs < tw.morningStartMs) {
          this.twilightValue = this.fmtTime(tw.morningStartMs);
          const mins: number = Math.round((tw.morningStartMs - nowMs) / 60000);
          this.twilightNote = `暗夜中 · 余 ${Math.floor(mins / 60)}h${mins % 60}m`;
        } else {
          this.twilightValue = '--';
          this.twilightNote = '已天亮';
        }
      }
      audit('ASTRO', `city=${this.city().name};twEnd=${tw.eveningEndMs};moon=${this.moonValue};alt=${moonHor.altDeg.toFixed(1)}`);
    } catch (err) {
      this.twilightNote = '历算错误';
      audit('ASTRO_ERR', JSON.stringify(err));
    }
  }

  @Builder
  WeatherCard() {
    Column({ space: 0 }) {
      Text('拍摄条件')
        .fontSize(7)
        .fontColor(this.p().dim)
      Text(this.wxCloudText)
        .fontSize(16)
        .fontColor(this.p().fg)
        .fontWeight(FontWeight.Medium)
      Text(this.wxNoteText)
        .fontSize(6)
        .fontColor(this.p().dim)
        .maxLines(2)
        .lineHeight(7)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .layoutWeight(1)
    .height(42)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(this.p().card)
    .borderRadius(10)
    .border({ width: 1, color: this.p().line })
    .onClick(() => this.onOpenWeather())
  }

  @Builder
  Card(label: string, value: string, note: string, onTap: () => void) {
    Column({ space: 0 }) {
      Text(label)
        .fontSize(7)
        .fontColor(this.p().dim)
      Text(value)
        .fontSize(16)
        .fontColor(this.p().fg)
        .fontWeight(FontWeight.Medium)
      Text(note)
        .fontSize(6)
        .fontColor(this.p().dim)
        .maxLines(2)
        .lineHeight(7)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .layoutWeight(1)
    .height(42)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(this.p().card)
    .borderRadius(10)
    .border({ width: 1, color: this.p().line })
    .onClick(onTap)
  }

  build() {
    Column({ space: 1 }) {
      Text('StarPilot')
        .fontSize(11)
        .fontColor(this.p().accent)
        .fontWeight(FontWeight.Bold)
        .width('100%')
        .textAlign(TextAlign.Center)

      Text(this.clock)
        .fontSize(30)
        .fontColor(this.p().fg)
        .fontWeight(FontWeight.Lighter)
      Row() {
        Text(this.battery)
          .fontSize(9)
          .fontColor(this.p().dim)
        Text(this.expiredNote.length > 0 ? this.expiredNote : this.dateText)
          .fontSize(9)
          .fontColor(this.expiredNote.length > 0 ? this.p().accent : this.p().dim)
          .layoutWeight(1)
          .textAlign(TextAlign.Start)
          .margin({ left: 6 })
        Text(`${this.locationLabel()} ▸`)
          .fontSize(9)
          .fontColor(this.p().accent)
      }
      .width('100%')
      .padding({ top: 2, bottom: 2 })
      .onClick(() => this.onOpenLocation())

      Row({ space: 5 }) {
        this.WeatherCard()
        this.Card('天文暮光', this.twilightValue, this.twilightNote, () => {
        })
      }
      .width('100%')
      .margin({ top: 2 })

      Row({ space: 5 }) {
        this.Card('月相', this.moonValue, this.moonNote, () => {
        })
        this.Card('手机', '未知', 'S6 同步', () => {
        })
      }
      .width('100%')

      Row({ space: 6 }) {
        Button(this.redMode ? '关闭红光' : '红光模式')
          .fontSize(8)
          .height(24)
          .layoutWeight(1)
          .padding(0)
          .backgroundColor(this.p().card)
          .fontColor(this.p().accent)
          .onClick(() => this.onToggleRed())
        Button('诊断')
          .fontSize(8)
          .height(24)
          .layoutWeight(1)
          .padding(0)
          .backgroundColor(this.p().card)
          .fontColor(this.p().dim)
          .onClick(() => this.onOpenDiag())
        Button('天文工具')
          .fontSize(8)
          .height(24)
          .layoutWeight(1)
          .padding(0)
          .backgroundColor(this.p().card)
          .fontColor(this.p().accent)
          .onClick(() => this.onOpenAstronomy())
        Button('隐私')
          .fontSize(8).height(24).layoutWeight(1).padding(0)
          .backgroundColor(this.p().card).fontColor(this.p().fg)
          .onClick(() => this.onOpenPrivacy())
      }
      .width('100%')
      .margin({ top: 2 })
    }
    .width('100%')
    .height('100%')
    .padding({ left: 40, right: 40, top: 16, bottom: 8 })
    .justifyContent(FlexAlign.Center)
  }
}
