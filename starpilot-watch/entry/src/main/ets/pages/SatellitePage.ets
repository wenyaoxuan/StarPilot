import { common } from '@kit.AbilityKit';
import { picker } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { audit } from '../common/AuditLog';
import { IssPass, PassSite, nextIssPass } from '../common/SatelliteEngine';
import { IssFreshness, IssOrbit, MAX_ISS_AGE_MS, MAX_OMM_BYTES, issFreshness, parseIssOmm }
  from '../common/SatelliteOrbit';
import { ISS_STAGING_NAME, IssRecord, importIssRecord, loadIssRecord } from '../common/SatelliteStore';
import { readBoundedText } from '../common/BoundedTextFile';
import { NearEarthSgp4 } from '../common/Sgp4NearEarth';
import { Palette, palette } from '../common/Theme';
import { CITIES, City } from '../data/Cities';

function timeText(ms: number): string {
  const time: Date = new Date(ms);
  return (time.getMonth() + 1) + '/' + time.getDate() + ' ' +
    time.getHours().toString().padStart(2, '0') + ':' + time.getMinutes().toString().padStart(2, '0');
}

function azText(deg: number): string {
  return (Math.round(deg) % 360) + '°';
}

@Component
export struct SatellitePage {
  @Prop redMode: boolean = false;
  @Prop cityIndex: number = 0;
  @Prop altitudeM: number = 0;
  @Prop altitudeKnown: boolean = false;
  @Prop @Watch('onForegroundChanged') foreground: boolean = true;
  onClose: () => void = () => {};

  @State record: IssRecord | null = null;
  @State pass: IssPass | null = null;
  @State now: number = 0;
  @State searchedAt: number = 0;
  @State threshold: number = 10;
  @State screen: number = 0; // 0 forecast, 1 import, 2 custom elevation
  @State message: string = '';
  @State draft: string = '';
  @State working: boolean = false;
  private context: common.UIAbilityContext | null = null;
  private timer: number = -1;
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    this.context = (this.getUIContext().getHostContext() as common.UIAbilityContext | undefined) ?? null;
    try {
      if (this.context !== null) {
        this.record = loadIssRecord(this.context.filesDir);
      }
    } catch (err) {
      this.message = '轨道缓存无法读取，请重新导入';
      audit('ISS_CACHE', JSON.stringify(err));
    }
    this.onForegroundChanged();
  }

  aboutToDisappear(): void {
    this.stopTimer();
    this.context = null;
  }

  private onForegroundChanged(): void {
    this.stopTimer();
    if (this.foreground) {
      this.calculate();
      this.timer = setInterval(() => {
        this.now = Date.now();
        if ((this.pass !== null && this.now >= this.pass.los) || this.now - this.searchedAt > 600000) {
          this.calculate();
        }
      }, 15000);
    }
  }

  private stopTimer(): void {
    if (this.timer !== -1) {
      clearInterval(this.timer);
      this.timer = -1;
    }
  }

  private p(): Palette {
    return palette(this.redMode);
  }

  private city(): City {
    return CITIES[this.cityIndex];
  }

  private site(): PassSite {
    return { lat: this.city().lat, lon: this.city().lon, altitudeM: this.altitudeM };
  }

  private calculate(): void {
    this.now = Date.now();
    this.searchedAt = this.now;
    this.pass = null;
    const record: IssRecord | null = this.record;
    if (record === null) {
      return;
    }
    const state: IssFreshness = issFreshness(record.orbit, this.now);
    if (state === IssFreshness.Future || state === IssFreshness.Expired) {
      return;
    }
    try {
      this.pass = nextIssPass(new NearEarthSgp4(record.orbit), this.now, this.site(), this.threshold);
      audit('ISS_PASS', 'elapsedMs=' + (Date.now() - this.now) + ';hasPass=' + (this.pass !== null));
    } catch (err) {
      this.message = '轨道传播失败，请更换数据';
      audit('ISS_PROPAGATE', JSON.stringify(err));
    }
  }

  private useThreshold(value: number): void {
    this.threshold = value;
    this.changeScreen(0);
    this.calculate();
  }

  private freshnessText(orbit: IssOrbit): string {
    const state: IssFreshness = issFreshness(orbit, this.now);
    if (state === IssFreshness.Future) {
      return '历元在未来，请检查手表时间';
    }
    if (state === IssFreshness.Expired) {
      return '轨道已过期，请导入新数据';
    }
    const age: number = Math.max(0, (this.now - orbit.epochMs) / 3600000);
    return '历元距今 ' + age.toFixed(1) + ' 小时' + (state === IssFreshness.Aging ? ' · 轨道偏旧' : '');
  }

  private passText(): string {
    if (this.pass === null) {
      return '';
    }
    const minutes: number = Math.ceil((this.pass.aos - this.now) / 60000);
    if (minutes <= 0) {
      return '预计过境进行中';
    }
    const hours: string = minutes >= 60 ? Math.floor(minutes / 60) + ' 小时 ' : '';
    return '约 ' + hours + minutes % 60 + ' 分钟后开始';
  }

  private durationText(pass: IssPass): string {
    const minutes: number = (pass.los - pass.aos) / 60000;
    return minutes < 1 ? '不足 1 分钟' : '约 ' + Math.round(minutes) + ' 分钟';
  }

  private canShowPass(): boolean {
    return this.record !== null && this.now < this.record.orbit.epochMs + MAX_ISS_AGE_MS &&
      issFreshness(this.record.orbit, this.now) !== IssFreshness.Future;
  }

  private changeScreen(screen: number): void {
    this.scroller.scrollTo({ xOffset: 0, yOffset: 0 });
    this.screen = screen;
  }

  private saveImport(text: string, source: string): void {
    const orbit: IssOrbit = parseIssOmm(text);
    const time: number = Date.now();
    const freshness: IssFreshness = issFreshness(orbit, time);
    if (freshness === IssFreshness.Expired) {
      throw new Error('轨道历元已过期');
    }
    if (freshness === IssFreshness.Future) {
      throw new Error('轨道历元在未来，请检查手表时间');
    }
    if (this.record !== null && orbit.epochMs < this.record.orbit.epochMs) {
      throw new Error('导入的轨道比现有缓存旧');
    }
    if (this.context === null) {
      throw new Error('无法访问本地轨道缓存');
    }
    this.record = importIssRecord(this.context.filesDir, text, source, time, orbit);
    this.draft = '';
    this.message = '';
    this.changeScreen(0);
    this.calculate();
    audit('ISS_IMPORT', 'source=' + source + ';epoch=' + new Date(orbit.epochMs).toISOString());
  }

  private importPath(path: string, source: string): void {
    try {
      this.saveImport(readBoundedText(path, MAX_OMM_BYTES), source);
    } catch (err) {
      const error: BusinessError = err as BusinessError;
      this.message = error.code === 13900002 ? '未找到文件 iss-omm.json' :
        (error.message || '无法读取轨道') + ' · 原缓存保留';
      audit('ISS_IMPORT_ERR', JSON.stringify(err));
    }
  }

  private importStaged(): void {
    if (this.context !== null) {
      this.importPath(this.context.filesDir + '/' + ISS_STAGING_NAME, '本地调试文件');
    }
  }

  private openImport(): void {
    this.draft = '';
    this.message = '';
    this.changeScreen(1);
  }

  private async chooseFile(): Promise<void> {
    if (this.context === null || this.working) {
      return;
    }
    this.working = true;
    try {
      const options: picker.DocumentSelectOptions = new picker.DocumentSelectOptions();
      options.maxSelectNumber = 1;
      const files: string[] = await new picker.DocumentViewPicker(this.context).select(options);
      if (files.length === 1 && this.context !== null && this.screen === 1) {
        this.importPath(files[0], '本地文件');
      }
    } catch (err) {
      this.message = '无法打开文件选择器，可粘贴 JSON 或导入调试文件';
      audit('ISS_PICKER', JSON.stringify(err));
    } finally {
      this.working = false;
    }
  }

  @Builder
  Header(title: string, back: () => void, canImport: boolean = false) {
    Row() {
      Button('返回').fontSize(9).height(24).width(42).padding(0)
        .fontColor(this.p().accent).backgroundColor(this.p().card).onClick(back)
      Text(title).fontSize(11).fontColor(this.p().accent).layoutWeight(1).textAlign(TextAlign.Center)
      if (canImport) {
        Button('导入').fontSize(9).height(24).width(42).padding(0)
          .fontColor(this.p().accent).backgroundColor(this.p().card).onClick(() => this.openImport())
      } else {
        Blank().width(42)
      }
    }.width('100%')
  }

  @Builder
  Action(label: string, action: () => void) {
    Button(label).fontSize(9).height(25).padding(0).layoutWeight(1)
      .backgroundColor(this.p().card).fontColor(this.p().accent).enabled(!this.working).onClick(action)
  }

  @Builder
  Forecast() {
    this.Header('ISS 卫星过境', this.onClose, true)
    Text(this.city().name + ' · ' + (this.altitudeKnown ? '海拔 ' + Math.round(this.altitudeM) + ' m' : '海拔按 0 m'))
      .fontSize(9).fontColor(this.p().fg).maxLines(1)
    if (this.record === null) {
      Text('尚无 ISS 轨道').fontSize(13).fontColor(this.p().fg)
      Text('导入 25544 的 OMM JSON 后离线计算').fontSize(9).fontColor(this.p().fg)
    } else {
      Text(this.freshnessText(this.record.orbit)).fontSize(9).fontColor(this.p().accent)
      if (this.canShowPass()) {
        Text('最低仰角 ' + this.threshold + '° · 手表时间').fontSize(9).fontColor(this.p().fg)
        Row({ space: 4 }) {
          this.Action('0°', () => this.useThreshold(0))
          this.Action('10°', () => this.useThreshold(10))
          this.Action('20°', () => this.useThreshold(20))
          this.Action('自定义', () => {
            this.draft = '';
            this.changeScreen(2);
          })
        }.width('100%')
        if (this.pass !== null && this.now < this.pass.los) {
          Text(this.passText()).fontSize(10).fontColor(this.p().accent)
          Text('进入 ' + timeText(this.pass.aos) + ' · 方位 ' + azText(this.pass.riseAz))
            .fontSize(9).fontColor(this.p().fg)
          Text('最高 ' + Math.round(this.pass.maxAlt) + '° · 方位 ' + azText(this.pass.peakAz))
            .fontSize(9).fontColor(this.p().fg)
          Text('离开 ' + timeText(this.pass.los) + ' · 方位 ' + azText(this.pass.setAz))
            .fontSize(9).fontColor(this.p().fg)
          Text(this.durationText(this.pass) + ' · ' +
            (this.pass.possiblyVisible ? '几何条件可能可见' : '未找到可见条件'))
            .fontSize(9).fontColor(this.p().accent)
        } else {
          Text(this.message === '' ? '预测范围内无完整过境' : this.message).fontSize(9).fontColor(this.p().fg)
        }
      }
      Text('历元 ' + new Date(this.record.orbit.epochMs).toISOString().slice(0, 16).replace('T', ' ') + ' UTC')
        .fontSize(8).fontColor(this.p().fg)
      Text(this.record.input.source + ' · 导入 ' + timeText(this.record.input.importedAt))
        .fontSize(8).fontColor(this.p().fg)
      if (this.record.orbit.originator !== '') {
        Text('发布源 ' + this.record.orbit.originator).fontSize(8).fontColor(this.p().fg)
      }
      Text('NORAD ' + this.record.orbit.catalogId + ' · 元素集 ' +
        (this.record.orbit.elementSet < 0 ? '—' : this.record.orbit.elementSet) + ' · 圈次 ' +
        (this.record.orbit.revolution < 0 ? '—' : this.record.orbit.revolution))
        .fontSize(8).fontColor(this.p().fg)
    }
    if (this.record === null && this.message !== '') {
      Text(this.message).fontSize(9).fontColor(this.p().accent)
    }
    Row({ space: 5 }) {
      if (this.record === null) {
        this.Action('导入轨道', () => this.openImport())
      } else {
        this.Action('重新计算', () => { this.message = ''; this.calculate(); })
      }
    }.width('100%')
    Text('最多搜索 24 小时 · 仅几何估算').fontSize(8).fontColor(this.p().fg)
  }

  @Builder
  ImportScreen() {
    this.Header('导入 ISS OMM', () => { this.message = ''; this.changeScreen(0); })
    Text('25544 · OMM JSON · 最大 4 KB').fontSize(9).fontColor(this.p().fg)
    Row({ space: 4 }) {
      if (canIUse('SystemCapability.FileManagement.UserFileService')) {
        this.Action('选择文件', () => { this.chooseFile(); })
      }
      this.Action('读取调试文件', () => this.importStaged())
    }.width('100%')
    TextArea({ placeholder: '粘贴 OMM JSON', text: this.draft })
      .maxLength(MAX_OMM_BYTES).height(49).fontSize(9).width('100%')
      .backgroundColor(this.p().card).fontColor(this.p().fg).placeholderColor(this.p().fg)
      .onChange((value: string) => { this.draft = value; })
    Row() {
      this.Action('校验并导入', () => {
        try {
          this.saveImport(this.draft, '本地文本');
        } catch (err) {
          this.message = (err as Error).message + ' · 原缓存保留';
        }
      })
    }.width('100%')
    Text(this.message || '数据可由电脑获取后导入手表').fontSize(9).fontColor(this.p().accent)
  }

  @Builder
  CustomThreshold() {
    this.Header('最低仰角', () => this.changeScreen(0))
    TextInput({ placeholder: '输入 0–89°', text: this.draft }).type(InputType.Number)
      .maxLength(2).height(36).width('100%').fontSize(12)
      .backgroundColor(this.p().card).fontColor(this.p().fg).placeholderColor(this.p().fg)
      .onChange((value: string) => { this.draft = value; })
    Button('确定').height(26).width('100%').fontSize(9)
      .backgroundColor(this.p().accent).fontColor('#000000')
      .enabled(/^\d{1,2}$/.test(this.draft) && Number(this.draft) <= 89)
      .onClick(() => this.useThreshold(Number(this.draft)))
  }

  build() {
    Scroll(this.scroller) {
      Column({ space: 4 }) {
        if (this.screen === 1) {
          this.ImportScreen()
        } else if (this.screen === 2) {
          this.CustomThreshold()
        } else {
          this.Forecast()
        }
      }.width('100%').padding({ left: 33, right: 33, top: 26, bottom: 24 })
    }.width('100%').height('100%').backgroundColor(this.p().bg).scrollBar(BarState.Off)
  }
}
