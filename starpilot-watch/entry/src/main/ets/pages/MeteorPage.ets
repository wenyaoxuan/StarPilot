import { MeteorSample, MeteorSite, MeteorWindow, meteorActive, meteorCurve, meteorNextPeakDay,
  meteorSample, meteorSeasonYear, meteorWindows } from '../common/MeteorEngine';
import { Palette, palette } from '../common/Theme';
import { CITIES, City } from '../data/Cities';
import { METEOR_FIRST_YEAR, METEOR_LAST_YEAR, METEOR_SHOWERS, METEOR_SOURCE, MeteorShower } from '../data/MeteorShowers';

function pad(value: number): string {
  return value.toString().padStart(2, '0');
}

function watchTime(ms: number): string {
  const time: Date = new Date(ms);
  return (time.getMonth() + 1) + '/' + time.getDate() + ' ' + pad(time.getHours()) + ':' + pad(time.getMinutes());
}

function monthDay(mmdd: number): string {
  return Math.floor(mmdd / 100) + '/' + mmdd % 100;
}

@Component
export struct MeteorPage {
  @Prop redMode: boolean = false;
  @Prop englishNames: boolean = false;
  @Prop cityIndex: number = 0;
  @Prop horizonMask: number[] = [];
  onClose: () => void = () => {};

  @State selected: number = -1;
  @State showChart: boolean = false;
  @State usePeak: boolean = false;
  @State now: number = 0;
  private current: MeteorSample | null = null;
  private samples: MeteorSample[] = [];
  private windows: MeteorWindow[] = [];
  private order: number[] = [];
  private scroller: Scroller = new Scroller();
  private chart: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));

  aboutToAppear(): void {
    this.refreshList();
  }

  private refreshList(): void {
    this.now = Date.now();
    this.order = METEOR_SHOWERS.map((_shower: MeteorShower, index: number) => index)
      .sort((a: number, b: number) =>
        Number(meteorActive(METEOR_SHOWERS[b], this.now)) - Number(meteorActive(METEOR_SHOWERS[a], this.now)));
  }

  private scrollTop(): void {
    this.scroller.scrollTo({ xOffset: 0, yOffset: 0 });
  }

  private p(): Palette {
    return palette(this.redMode);
  }

  private city(): City {
    return CITIES[this.cityIndex];
  }

  private site(): MeteorSite {
    const city: City = this.city();
    return { lat: city.lat, lon: city.lon, mask: this.horizonMask };
  }

  private shower(): MeteorShower {
    return METEOR_SHOWERS[this.selected];
  }

  private name(shower: MeteorShower): string {
    return this.englishNames ? shower.nameEn : shower.name + '流星雨';
  }

  private yearKnown(shower: MeteorShower): boolean {
    const year: number = meteorSeasonYear(shower, this.now);
    return year >= METEOR_FIRST_YEAR && year <= METEOR_LAST_YEAR;
  }

  private pick(index: number): void {
    this.now = Date.now();
    this.current = meteorSample(METEOR_SHOWERS[index], this.now, this.site());
    this.scrollTop();
    this.selected = index;
  }

  private peakText(shower: MeteorShower): string {
    const peak: number | null = meteorNextPeakDay(shower, this.now);
    if (peak === null) {
      return '暂无对应年份的极大预报';
    }
    const date: Date = new Date(peak);
    return date.getUTCFullYear() + '/' + (date.getUTCMonth() + 1) + '/' + date.getUTCDate() + ' UTC';
  }

  private openChart(peakMode: boolean): void {
    const from: number | null = peakMode ? meteorNextPeakDay(this.shower(), this.now) : Date.now();
    if (from === null) {
      return;
    }
    this.samples = meteorCurve(this.shower(), from, this.site());
    this.windows = meteorWindows(this.samples);
    this.usePeak = peakMode;
    this.scrollTop();
    this.showChart = true;
  }

  private altitudeText(): string {
    const sample: MeteorSample | null = this.current;
    if (sample === null || !sample.active) {
      return '当前不在参考活跃期';
    }
    if (sample.radiant.altDeg <= 0) {
      return '当前辐射点在地平线下';
    }
    return '当前辐射点 ' + sample.radiant.altDeg.toFixed(0) + '°' +
      (sample.clearsMask ? '' : ' · 地平遮挡') + (sample.driftApplied ? '' : ' · 参考位置');
  }

  private moonText(): string {
    const first: MeteorSample = this.samples[0];
    const time: number = this.windows.length > 0 ? this.windows[0].from : first.ms;
    const sample: MeteorSample = this.samples[Math.round((time - first.ms) / 1800000)];
    const percent: string = Math.round(sample.illumination * 100).toString() + '%';
    return (this.windows.length > 0 ? '首段开始' : '曲线起点') + ' · 月面 ' + percent + ' 照亮\n' +
      (sample.moonAlt <= 0 ? '月亮在地平线下' :
        '月高 ' + sample.moonAlt.toFixed(0) + '° · 距辐射点 ' + sample.moonSeparation.toFixed(0) + '°');
  }

  private drawCurve(): void {
    const ctx: CanvasRenderingContext2D = this.chart;
    const w: number = ctx.width;
    const h: number = ctx.height;
    if (w <= 24 || h <= 14 || this.samples.length < 2) {
      return;
    }
    const left: number = 16;
    const top: number = 7;
    const width: number = w - left - 5;
    const height: number = h - 14;
    const mid: number = top + height / 2;
    const p: Palette = this.p();
    ctx.clearRect(0, 0, w, h);
    ctx.fillStyle = this.redMode ? '#320907' : '#293139';
    const start: number = this.samples[0].ms;
    const span: number = this.samples[this.samples.length - 1].ms - start;
    for (const window of this.windows) {
      ctx.fillRect(left + (window.from - start) / span * width, top,
        (window.until - window.from) / span * width, height);
    }
    ctx.strokeStyle = this.redMode ? '#7B2520' : '#606064';
    ctx.lineWidth = 0.75;
    ctx.strokeRect(left, top, width, height);
    ctx.beginPath();
    ctx.moveTo(left, mid);
    ctx.lineTo(left + width, mid);
    ctx.stroke();
    ctx.font = '10px sans-serif';
    ctx.fillStyle = p.fg;
    ctx.fillText('90°', 0, top + 3);
    ctx.fillText('0°', 3, mid + 2);
    ctx.fillText('−90°', 0, top + height + 2);
    this.drawAltitude(true, left, width, mid, height);
    this.drawAltitude(false, left, width, mid, height);
  }

  private drawAltitude(moon: boolean, left: number, width: number, mid: number, height: number): void {
    const ctx: CanvasRenderingContext2D = this.chart;
    ctx.strokeStyle = moon ? (this.redMode ? '#A53D36' : '#BBC3CE') : this.p().accent;
    ctx.setLineDash(moon ? [2, 2] : []);
    ctx.lineWidth = moon ? 1 : 1.5;
    ctx.beginPath();
    for (let i = 0; i < this.samples.length; i++) {
      const sample: MeteorSample = this.samples[i];
      const x: number = left + i * width / (this.samples.length - 1);
      const y: number = mid - (moon ? sample.moonAlt : sample.radiant.altDeg) * height / 180;
      if (i === 0) {
        ctx.moveTo(x, y);
      } else {
        ctx.lineTo(x, y);
      }
    }
    ctx.stroke();
    ctx.setLineDash([]);
  }

  @Builder
  Header(title: string, back: () => void) {
    Row() {
      Button('返回').fontSize(9).height(24).width(42).padding(0)
        .fontColor(this.p().accent).backgroundColor(this.p().card).onClick(back)
      Text(title).fontSize(11).fontColor(this.p().accent).layoutWeight(1).textAlign(TextAlign.Center)
      Blank().width(42)
    }.width('100%')
  }

  @Builder
  ListContent() {
    this.Header('流星雨', this.onClose)
    Text(this.city().name + ' · 离线历算').fontSize(9).fontColor(this.p().fg)
    ForEach(this.order, (index: number) => {
      Row({ space: 4 }) {
        Text(this.name(METEOR_SHOWERS[index])).fontSize(10).fontColor(this.p().fg).layoutWeight(1)
        Text(meteorActive(METEOR_SHOWERS[index], this.now) ? '活跃期' :
          monthDay(METEOR_SHOWERS[index].start) + '–' + monthDay(METEOR_SHOWERS[index].end))
          .fontSize(8).fontColor(meteorActive(METEOR_SHOWERS[index], this.now) ? this.p().accent : this.p().fg)
      }.width('100%').constraintSize({ minHeight: 32 }).padding({ left: 8, right: 8 })
        .borderRadius(12).backgroundColor(this.p().card).onClick(() => this.pick(index))
    }, (index: number) => METEOR_SHOWERS[index].code)
    Text(METEOR_SOURCE).fontSize(8).fontColor(this.p().fg).textAlign(TextAlign.Center)
  }

  @Builder
  DetailContent() {
    this.Header(this.shower().code, () => {
      this.scrollTop();
      this.refreshList();
      this.selected = -1;
    })
    Text(this.name(this.shower())).fontSize(14).fontColor(this.p().fg).textAlign(TextAlign.Center)
    Text('活跃期 ' + monthDay(this.shower().start) + '–' + monthDay(this.shower().end) +
      ' · 参考 λ☉ ' + this.shower().longitude + '°').fontSize(9).fontColor(this.p().fg)
    Text('极大参考日 ' + this.peakText(this.shower())).fontSize(9).fontColor(this.p().fg).textAlign(TextAlign.Center)
    if (this.yearKnown(this.shower())) {
      Text(this.altitudeText()).fontSize(9).fontColor(this.p().accent).textAlign(TextAlign.Center)
      Row({ space: 4 }) {
        if (meteorActive(this.shower(), this.now)) {
          Button('未来 24h').layoutWeight(1).height(26).padding(0).fontSize(9)
            .fontColor('#000000').backgroundColor(this.p().accent).onClick(() => this.openChart(false))
        }
        if (meteorNextPeakDay(this.shower(), this.now) !== null) {
          Button('极大日 24h').layoutWeight(1).height(26).padding(0).fontSize(9)
            .fontColor(this.p().accent).backgroundColor(this.p().card).onClick(() => this.openChart(true))
        }
      }.width('100%')
      Text('参考 ZHR ' + this.shower().zhr + '（2027 版）\n理想条件参考值，实际数量随条件变化')
        .fontSize(8).fontColor(this.p().fg).textAlign(TextAlign.Center)
    } else {
      Text('年历数据超出覆盖年份').fontSize(9).fontColor(this.p().accent)
    }
    Text('IMO 2026 / 2027 年历 · 极大会波动').fontSize(8).fontColor(this.p().fg)
    Text(METEOR_SOURCE).fontSize(8).fontColor(this.p().fg).textAlign(TextAlign.Center)
  }

  @Builder
  ChartContent() {
    this.Header(this.usePeak ? '极大日 24h' : '未来 24h', () => {
      this.scrollTop();
      this.showChart = false;
    })
    Text(this.shower().code + ' · ' + this.city().name + ' · 手表时间')
      .fontSize(9).fontColor(this.p().fg).maxLines(1)
    Canvas(this.chart).width('100%').height(63).onReady(() => this.drawCurve())
    Text(watchTime(this.samples[0].ms) + ' → ' + watchTime(this.samples[this.samples.length - 1].ms))
      .fontSize(8).fontColor(this.p().fg)
    Text('实线 辐射点 · 虚线 月亮 · 底色 窗口').fontSize(8).fontColor(this.p().fg)
    if (this.windows.length === 0) {
      Text('无满足天黑和地平条件的窗口').fontSize(9).fontColor(this.p().accent)
    }
    ForEach(this.windows, (window: MeteorWindow) => {
      Text(watchTime(window.from) + '–' + watchTime(window.until))
        .fontSize(9).fontColor(this.p().accent)
    }, (window: MeteorWindow) => window.from.toString())
    Text(this.moonText()).fontSize(8).fontColor(this.p().fg).textAlign(TextAlign.Center)
    Text('半小时采样 · 未计云量和光污染').fontSize(8).fontColor(this.p().fg)
    Text(METEOR_SOURCE).fontSize(8).fontColor(this.p().fg).textAlign(TextAlign.Center)
  }

  build() {
    Scroll(this.scroller) {
      Column({ space: 4 }) {
        if (this.showChart) {
          this.ChartContent()
        } else if (this.selected >= 0) {
          this.DetailContent()
        } else {
          this.ListContent()
        }
      }.width('100%').padding({ left: 33, right: 33, top: 26, bottom: 25 })
    }.width('100%').height('100%').backgroundColor(this.p().bg).scrollBar(BarState.Off)
  }
}
