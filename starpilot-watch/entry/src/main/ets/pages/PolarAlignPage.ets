import { sensor } from '@kit.SensorServiceKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { audit } from '../common/AuditLog';
import { jdFromUnixMs, sunAltitude } from '../common/Astro';
import { DriftCandidate, DriftDirection, DriftField, DriftRound, DriftTrend, POLAR_SECONDS, PolarAxis,
  PolarSite, PoleTarget, compareDrift, driftCandidate, driftCandidates, polarTarget,
  remainingDriftSeconds } from '../common/PolarAlignEngine';
import { POLAR_EXPORT, POLAR_LIMIT, driftDirectionLabel, driftFieldLabel, driftStrengthLabel, driftTrendLabel,
  exportPolarRounds, loadPolarRounds, polarAxisLabel, savePolarRounds } from '../common/PolarStore';
import { HopStar } from '../common/StarHopEngine';
import { Palette, palette } from '../common/Theme';
import { vibrateAlert } from '../common/Vibrate';
import { CITIES, City } from '../data/Cities';
import { referenceHopStars } from '../data/StarHopCatalog';

enum PolarScreen {
  Menu,
  Coarse,
  Setup,
  Conditions,
  Select,
  Ready,
  Timing,
  Record,
  Review,
  History
}

function localStamp(ms: number): string {
  const time: Date = new Date(ms);
  return (time.getMonth() + 1) + '/' + time.getDate() + ' ' +
    time.getHours().toString().padStart(2, '0') + ':' + time.getMinutes().toString().padStart(2, '0');
}

@Component
export struct PolarAlignPage {
  @Prop cityIndex: number = 0;
  @Prop altitudeM: number = 0;
  @Prop redMode: boolean = false;
  @Prop englishNames: boolean = false;
  @Prop horizonMask: number[] = [];
  @Prop @Watch('onForegroundChanged') foreground: boolean = true;
  onClose: () => void = () => {};

  @State screen: PolarScreen = PolarScreen.Menu;
  @State north: boolean = true;
  @State mount: string = '';
  @State imageMode: number = 0;
  @State side: number = 0;
  @State tracking: boolean = false;
  @State guideOff: boolean = false;
  @State southWindow: boolean = true;
  @State axis: PolarAxis = PolarAxis.Azimuth;
  @State options: DriftCandidate[] = [];
  @State daylight: boolean = false;
  @State seconds: number = 60;
  @State remaining: number = 0;
  @State driftChoice: number = -1;
  @State strength: number = -1;
  @State continuous: boolean = true;
  @State adjustments: number = 0;
  @State rounds: DriftRound[] = [];
  @State message: string = '';
  @State magnetic: string = '';
  @State clearPrompt: boolean = false;
  @State historyCount: number = 8;
  private blockedStorage: boolean = false;
  private directory: string = '';
  private stars: HopStar[] = [];
  private selected: DriftCandidate | null = null;
  private result: DriftRound | null = null;
  private session: number = 0;
  private start: number = 0;
  private deadline: number = 0;
  private tickId: number = -1;
  private scrollReset: number = -1;
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    this.north = this.city().lat >= 0;
    this.directory = this.getUIContext().getHostContext()?.filesDir ?? '';
    try {
      if (this.directory !== '') {
        this.rounds = loadPolarRounds(this.directory);
      }
    } catch (err) {
      this.blockedStorage = true;
      audit('POLAR_STORAGE', 'load_failed');
    }
  }

  aboutToDisappear(): void {
    this.stopTimer();
    this.deadline = 0;
    clearTimeout(this.scrollReset);
  }

  private p(): Palette {
    return palette(this.redMode);
  }

  private city(): City {
    return CITIES[this.cityIndex] ?? CITIES[0];
  }

  private site(): PolarSite {
    return { lat: this.city().lat, lon: this.city().lon, mask: this.horizonMask, southWindow: this.southWindow };
  }

  private pole(): PoleTarget | null {
    return polarTarget(this.city().lat, this.north);
  }

  private hemisphereOK(): boolean {
    return this.city().lat === 0 || this.north === (this.city().lat > 0);
  }

  private starName(candidate: DriftCandidate): string {
    return this.englishNames ? candidate.star.nameEn : candidate.star.name;
  }

  private locationText(candidate: DriftCandidate): string {
    return '高度 ' + candidate.alt.toFixed(0) + '° · 真方位 ' + (Math.round(candidate.az) % 360) + '°';
  }

  private imageText(): string {
    return ['未知', '未翻转', '上下翻转', '左右镜像', '上下及左右翻转'][this.imageMode];
  }

  private sideText(): string {
    return ['未知', '架台东侧', '架台西侧', '固定/楔式'][this.side];
  }

  private showPage(screen: PolarScreen): void {
    this.scroller.scrollTo({ xOffset: 0, yOffset: 0 });
    this.message = '';
    this.screen = screen;
    // A taller child can shift the Scroll offset during ArkUI's next layout.
    clearTimeout(this.scrollReset);
    this.scrollReset = setTimeout((): void => {
      this.scroller.scrollTo({ xOffset: 0, yOffset: 0 });
    }, 120);
  }

  private openCoarse(): void {
    this.showPage(PolarScreen.Coarse);
    this.magnetic = '读取 SDK 地磁模型…';
    const time: number = Date.now();
    const location: sensor.LocationOptions = {
      latitude: this.city().lat, longitude: this.city().lon, altitude: this.altitudeM
    };
    try {
      sensor.getGeomagneticInfo(location, time).then((model: sensor.GeomagneticResponse) => {
        this.magnetic = Number.isFinite(model.deflectionAngle) ?
          'SDK 模型磁偏角 ' + model.deflectionAngle.toFixed(1) + '° · ' + localStamp(time) : 'SDK 地磁模型无有效值';
        audit('POLAR_MAG_MODEL', Number.isFinite(model.deflectionAngle) ? 'available' : 'invalid');
      }).catch((err: BusinessError) => {
        this.magnetic = 'SDK 地磁模型不可用';
        audit('POLAR_MAG_MODEL', 'error=' + err.code);
      });
    } catch (err) {
      this.magnetic = 'SDK 地磁模型不可用';
    }
  }

  private listStars(axis: PolarAxis, reset: boolean): void {
    this.axis = axis;
    if (reset) {
      this.adjustments = this.rounds.find((round: DriftRound) =>
        round.session === this.session && round.axis === axis)?.adjustments ?? 0;
    }
    if (this.stars.length === 0) {
      this.stars = referenceHopStars();
    }
    this.refreshStars();
    this.showPage(PolarScreen.Select);
  }

  private refreshStars(): void {
    const now: number = Date.now();
    this.daylight = sunAltitude(jdFromUnixMs(now), this.city().lat, this.city().lon) > -6;
    this.options = driftCandidates(this.stars, this.site(), this.axis, now);
  }

  private beginSession(): void {
    if (!this.tracking || !this.guideOff || !this.hemisphereOK() || this.mount === '') {
      this.message = '需确认半球、架台、恒星跟踪与关闭导星修正';
      return;
    }
    this.session = Date.now();
    this.listStars(PolarAxis.Azimuth, true);
  }

  private startRound(): void {
    if (this.selected === null || !this.tracking || !this.guideOff) {
      return;
    }
    const now: number = Date.now();
    const site: PolarSite = this.site();
    if (sunAltitude(jdFromUnixMs(now), site.lat, site.lon) > -6) {
      this.message = '当前为白天或亮暮光，请在可辨星时复查';
      return;
    }
    const end: number = now + this.seconds * 1000;
    const first: DriftCandidate | null = driftCandidate(this.selected.star, site, this.axis, now);
    const last: DriftCandidate | null = driftCandidate(this.selected.star, site, this.axis, end);
    if (first === null || last === null || first.field !== last.field) {
      this.message = '当前星将在计时内离开适用范围，请返回换星';
      return;
    }
    this.selected = first;
    this.start = now;
    this.deadline = end;
    this.remaining = this.seconds;
    this.continuous = true;
    this.driftChoice = -1;
    this.strength = -1;
    this.showPage(PolarScreen.Timing);
    audit('POLAR_TIMER', 'start=' + this.seconds + ';axis=' + this.axis + ';star=' + first.star.id);
    this.onForegroundChanged();
  }

  private stopTimer(): void {
    if (this.tickId >= 0) {
      clearInterval(this.tickId);
      this.tickId = -1;
    }
  }

  private onForegroundChanged(): void {
    this.stopTimer();
    if (this.screen !== PolarScreen.Timing) {
      return;
    }
    if (!this.foreground) {
      this.continuous = false;
      audit('POLAR_TIMER', 'paused_ui_background');
      return;
    }
    this.updateTimer();
    if (this.screen === PolarScreen.Timing) {
      this.tickId = setInterval(() => this.updateTimer(), 250);
    }
  }

  private updateTimer(): void {
    const now: number = Date.now();
    if (now < this.start) {
      this.cancelRound();
      this.message = '手表时间已改变，本轮请重测';
      return;
    }
    const remaining: number = remainingDriftSeconds(this.deadline, now);
    if (remaining !== this.remaining) {
      this.remaining = remaining;
    }
    if (remaining === 0) {
      this.stopTimer();
      this.deadline = 0;
      this.showPage(PolarScreen.Record);
      vibrateAlert(300);
      audit('POLAR_TIMER', 'elapsed=' + (now - this.start) + ';continuous=' + this.continuous);
    }
  }

  private cancelRound(): void {
    this.stopTimer();
    this.deadline = 0;
    this.showPage(PolarScreen.Ready);
    audit('POLAR_TIMER', 'cancelled');
  }

  private remainingText(): string {
    return Math.floor(this.remaining / 60).toString().padStart(2, '0') + ':' +
      (this.remaining % 60).toString().padStart(2, '0');
  }

  private saveRound(): void {
    if (this.selected === null || this.driftChoice < 0 || !this.continuous) {
      return;
    }
    if (this.blockedStorage || this.directory === '') {
      this.message = '记录文件不可用，请在记录页检查';
      return;
    }
    const star: DriftCandidate = this.selected;
    const round: DriftRound = {
      session: this.session, start: this.start, seconds: this.seconds, starId: star.star.id,
      starName: this.starName(star), site: this.city().name, north: this.north, mount: this.mount,
      image: this.imageText(), side: this.sideText(), axis: this.axis, field: star.field,
      alt: star.alt, az: star.az, hourAngle: star.hourAngle, direction: this.driftChoice,
      strength: this.driftChoice === DriftDirection.None ? 0 :
        (this.driftChoice === DriftDirection.Unsteady ? -1 : this.strength),
      adjustments: this.adjustments, trend: DriftTrend.Unknown
    };
    const previous: DriftRound | undefined = this.rounds.find((item: DriftRound) =>
      item.session === round.session && item.axis === round.axis && item.starId === round.starId);
    round.trend = compareDrift(previous ?? null, round);
    const saved: DriftRound[] = [round].concat(this.rounds).slice(0, POLAR_LIMIT);
    try {
      savePolarRounds(this.directory, saved);
      this.rounds = saved;
      this.result = round;
      this.showPage(PolarScreen.Review);
      audit('POLAR_RECORD', 'count=' + saved.length + ';axis=' + round.axis);
    } catch (err) {
      this.message = '记录未保存，可重试';
    }
  }

  private openHistory(): void {
    this.clearPrompt = false;
    this.historyCount = 8;
    this.showPage(PolarScreen.History);
  }

  private exportRecords(): void {
    if (this.blockedStorage || this.rounds.length === 0 || this.directory === '') {
      this.message = '没有可导出的记录';
      return;
    }
    try {
      exportPolarRounds(this.directory, this.rounds);
      this.message = '已导出 ' + POLAR_EXPORT;
      audit('POLAR_RECORD', 'export_count=' + this.rounds.length);
    } catch (err) {
      this.message = '导出失败，原记录保留';
    }
  }

  private clearRecords(): void {
    if (this.directory === '') {
      this.message = '记录文件不可用';
      return;
    }
    try {
      savePolarRounds(this.directory, []);
      this.rounds = [];
      this.blockedStorage = false;
      this.clearPrompt = false;
      this.message = '历史记录已清除';
      audit('POLAR_RECORD', 'cleared');
    } catch (err) {
      this.message = '清除失败，原记录保留';
    }
  }

  @Builder
  Header(title: string, back: () => void, actionText: string = '', action: () => void = () => {}) {
    Row() {
      Button('返回').fontSize(9).width(42).height(24).padding(0)
        .fontColor(this.p().accent).backgroundColor(this.p().card).onClick(back)
      Text(title).fontSize(11).fontColor(this.p().accent).textAlign(TextAlign.Center).layoutWeight(1)
      if (actionText !== '') {
        Button(actionText).fontSize(9).width(42).height(24).padding(0)
          .fontColor(this.p().accent).backgroundColor(this.p().card).onClick(action)
      } else {
        Blank().width(42)
      }
    }.width('100%')
  }

  @Builder
  Key(label: string, action: () => void, selected: () => boolean = () => false) {
    Button(label).fontSize(9).height(25).padding(0).layoutWeight(1)
      .backgroundColor(selected() ? this.p().accent : this.p().card)
      .fontColor(selected() ? '#000000' : this.p().fg).onClick(action)
  }

  @Builder
  Full(label: string, action: () => void) {
    Row() {
      this.Key(label, action)
    }.width('100%')
  }

  @Builder
  Note(value: () => string) {
    Text(value()).fontSize(9).fontColor(this.p().fg).textAlign(TextAlign.Center)
  }

  @Builder
  Menu() {
    this.Header('极轴辅助', this.onClose)
    this.Note(() => this.city().name + ' · 手动观测')
    this.Full('粗对准', () => this.openCoarse())
    this.Full('漂移法', () => this.showPage(PolarScreen.Setup))
    this.Full('观测记录', () => this.openHistory())
  }

  @Builder
  Coarse() {
    this.Header('仅粗对准', () => this.showPage(PolarScreen.Menu))
    this.Note(() => this.city().name + ' · 纬度 ' + this.city().lat.toFixed(2) + '°')
    if (this.pole() !== null) {
      Text((this.pole()!.north ? '北天极' : '南天极') + ' · 高度 ' + this.pole()!.altitude.toFixed(1) + '°')
        .fontSize(14).fontColor(this.p().fg)
      this.Note(() => this.pole()!.azimuth === null ? '天极在天顶，方位无定义' :
        (this.pole()!.altitude === 0 ? '赤道：北 0°／南 180°，高度 0°' :
          '数学真方位 ' + this.pole()!.azimuth + '°'))
    }
    Text('手表航向基准未确认').fontSize(9).fontColor(this.p().accent)
    this.Note(() => this.magnetic)
    this.Note(() => '现场磁场未测 · 模型误差未知')
    this.Note(() => '用地图地理方位线或外部真北参照摆向，按机械刻度设高度。')
    this.Note(() => '地点不符时，请返回主页更改城市或 GPS。')
  }

  @Builder
  Setup() {
    this.Header('观测准备', () => this.showPage(PolarScreen.Menu))
    this.Note(() => this.city().name + ' · 确认所在半球')
    Row({ space: 4 }) {
      this.Key('北半球', () => { this.north = true; }, () => this.north)
      this.Key('南半球', () => { this.north = false; }, () => !this.north)
    }.width('100%')
    if (!this.hemisphereOK()) {
      Text('所选半球与地点纬度不符').fontSize(9).fontColor(this.p().accent)
    }
    this.Note(() => '架台类型')
    Row({ space: 4 }) {
      this.Key('赤道仪', () => { this.mount = '赤道仪'; }, () => this.mount === '赤道仪')
      this.Key('楔式跟踪', () => { this.mount = '楔式跟踪'; }, () => this.mount === '楔式跟踪')
    }.width('100%')
    this.Note(() => '相机/目镜成像（点按切换）')
    Button(this.imageText()).fontSize(9).height(25).width('100%')
      .fontColor(this.p().fg).backgroundColor(this.p().card)
      .onClick(() => { this.imageMode = (this.imageMode + 1) % 5; })
    Button('下一步').fontSize(9).height(26).width('100%')
      .backgroundColor(this.p().accent).fontColor('#000000')
      .enabled(this.mount !== '' && this.hemisphereOK()).onClick(() => this.showPage(PolarScreen.Conditions))
  }

  @Builder
  Conditions() {
    this.Header('确认观测条件', () => this.showPage(PolarScreen.Setup))
    this.Note(() => '视野范围')
    Row({ space: 4 }) {
      this.Key('仅南/西南', () => { this.southWindow = true; }, () => this.southWindow)
      this.Key('东西也开放', () => { this.southWindow = false; }, () => !this.southWindow)
    }.width('100%')
    this.Note(() => '镜头所在侧位（点按切换）')
    Button(this.sideText()).fontSize(9).height(24).width('100%')
      .fontColor(this.p().fg).backgroundColor(this.p().card)
      .onClick(() => { this.side = (this.side + 1) % 4; })
    Button(this.tracking ? '已开启恒星跟踪 ✓' : '点此确认恒星跟踪已开启').fontSize(9).height(24).width('100%')
      .fontColor(this.p().fg).backgroundColor(this.p().card).onClick(() => { this.tracking = !this.tracking; })
    Button(this.guideOff ? '导星修正已关闭 ✓' : '点此确认自动导星修正已关闭').fontSize(9).height(24).width('100%')
      .fontColor(this.p().fg).backgroundColor(this.p().card).onClick(() => { this.guideOff = !this.guideOff; })
    Button('选方位参考星').fontSize(9).height(26).width('100%')
      .backgroundColor(this.p().accent).fontColor('#000000')
      .enabled(this.tracking && this.guideOff).onClick(() => this.beginSession())
  }

  @Builder
  SelectStar() {
    this.Header(polarAxisLabel(this.axis) + '检查', () => this.showPage(PolarScreen.Conditions), '刷新',
      () => this.refreshStars())
    if (this.axis === PolarAxis.Azimuth) {
      this.Note(() => '选靠近子午圈、赤纬接近 0° 的恒星')
    } else {
      this.Note(() => '标准高度检查需东或西侧约 30° 高')
      if (this.southWindow) {
        Text('南/西南限制 · 标准东/西视野受限').fontSize(9).fontColor(this.p().accent)
      }
    }
    if (this.daylight) {
      Text('白天/亮暮光 · 仅预览选星').fontSize(9).fontColor(this.p().accent)
    }
    if (this.options.length === 0) {
      Text('当前没有合适参考星').fontSize(12).fontColor(this.p().accent)
      this.Note(() => '可稍后刷新，或到能看到所需方向的地点再测。')
    }
    ForEach(this.options, (candidate: DriftCandidate) => {
      Column({ space: 2 }) {
        Text(this.starName(candidate)).fontSize(11).fontColor(this.p().fg).maxLines(1)
        Text(this.locationText(candidate) + ' · ' +
          (candidate.field === DriftField.Southwest ? '西南替代' : driftFieldLabel(candidate.field)))
          .fontSize(8).fontColor(this.p().fg).textAlign(TextAlign.Center)
      }.width('100%').padding({ top: 4, bottom: 4, left: 5, right: 5 })
        .backgroundColor(this.p().card).borderRadius(12).onClick(() => {
          this.selected = candidate;
          this.showPage(PolarScreen.Ready);
        })
    }, (candidate: DriftCandidate) => candidate.star.id + ':' + candidate.alt.toFixed(0) + ':' +
      candidate.az.toFixed(0) + ':' + candidate.field)
    if (this.axis === PolarAxis.Altitude) {
      Row({ space: 4 }) {
        this.Key('返回方位组', () => this.listStars(PolarAxis.Azimuth, true))
        this.Key('查看记录', () => this.openHistory())
      }.width('100%')
    }
  }

  @Builder
  Ready() {
    this.Header('准备观察', () => this.listStars(this.axis, false))
    if (this.selected !== null) {
      Text(this.starName(this.selected)).fontSize(14).fontColor(this.p().fg)
      this.Note(() => this.locationText(this.selected!))
      this.Note(() => driftFieldLabel(this.selected!.field) + ' · ' + polarAxisLabel(this.axis) + '组')
      if (this.selected.field === DriftField.Southwest) {
        Text('几何较弱，仅定性试调，仍需标准高度复测。')
          .fontSize(9).fontColor(this.p().accent).textAlign(TextAlign.Center)
      }
    }
    this.Note(() => '居中并辨认这颗星；保持跟踪、关闭导星修正。')
    Row({ space: 4 }) {
      ForEach(POLAR_SECONDS, (duration: number) => {
        this.Key(duration + ' 秒', () => { this.seconds = duration; }, () => this.seconds === duration)
      }, (duration: number) => duration.toString())
    }.width('100%')
    this.Full('已认星 · 开始计时', () => this.startRound())
  }

  @Builder
  Timing() {
    Text('观察持续漂移').fontSize(13).fontColor(this.p().accent)
    Text(this.remainingText()).fontSize(42).fontColor(this.p().fg)
    if (this.selected !== null) {
      this.Note(() => this.starName(this.selected!) + ' · ' + this.locationText(this.selected!))
    }
    this.Note(() => '观察相机/目镜，留意持续单向移动。')
    this.Note(() => '来回摆动或风振请记为不稳定。')
    this.Full('中断本轮', () => this.cancelRound())
  }

  @Builder
  RecordDirection() {
    this.Header('记录屏幕方向', () => this.cancelRound())
    this.Note(() => '按相机画面或目镜所见原样记录')
    Row({ space: 4 }) {
      this.Key('↑ 上', () => { this.driftChoice = DriftDirection.Up; }, () => this.driftChoice === DriftDirection.Up)
      this.Key('↓ 下', () => { this.driftChoice = DriftDirection.Down; }, () => this.driftChoice === DriftDirection.Down)
      this.Key('← 左', () => { this.driftChoice = DriftDirection.Left; }, () => this.driftChoice === DriftDirection.Left)
      this.Key('→ 右', () => { this.driftChoice = DriftDirection.Right; }, () => this.driftChoice === DriftDirection.Right)
    }.width('100%')
    Row({ space: 4 }) {
      this.Key('未见持续漂移', () => { this.driftChoice = DriftDirection.None; },
        () => this.driftChoice === DriftDirection.None)
      this.Key('不稳定', () => { this.driftChoice = DriftDirection.Unsteady; },
        () => this.driftChoice === DriftDirection.Unsteady)
    }.width('100%')
    if (this.driftChoice >= 0 && this.driftChoice < DriftDirection.None) {
      Row({ space: 4 }) {
        this.Key('轻微', () => { this.strength = 1; }, () => this.strength === 1)
        this.Key('明显', () => { this.strength = 2; }, () => this.strength === 2)
        this.Key('未估幅度', () => { this.strength = -1; }, () => this.strength === -1)
      }.width('100%')
    }
    if (!this.continuous) {
      this.Note(() => '曾离开计时页。中断观察请返回重测。')
      this.Full('确认仍有连续观察', () => { this.continuous = true; })
    }
    Button('保存本轮').fontSize(9).height(25).width('100%')
      .backgroundColor(this.p().accent).fontColor('#000000')
      .enabled(this.driftChoice >= 0 && this.continuous).onClick(() => this.saveRound())
  }

  @Builder
  Review() {
    this.Header('本轮已保存', () => this.listStars(this.axis, false))
    if (this.result !== null) {
      this.Note(() => driftDirectionLabel(this.result!.direction) + ' · ' + driftStrengthLabel(this.result!.strength))
      Text(driftTrendLabel(this.result.trend)).fontSize(12).fontColor(this.p().accent)
    }
    this.Note(() => '一次只微调' + polarAxisLabel(this.axis) + '轴。变差可回原位，稳定后用同星复测。')
    if (this.side === 0 || this.imageMode === 0) {
      this.Note(() => '成像或侧位未确认，按屏幕方向记录。')
    }
    Row({ space: 4 }) {
      this.Key('原设置复测', () => this.showPage(PolarScreen.Ready))
      this.Key('试调后复测', () => {
        this.adjustments++;
        this.showPage(PolarScreen.Ready);
      })
    }.width('100%')
    if (this.axis === PolarAxis.Azimuth) {
      this.Full('下一组 · 高度', () => this.listStars(PolarAxis.Altitude, true))
    } else {
      this.Full('回到方位复核', () => this.listStars(PolarAxis.Azimuth, true))
    }
    this.Full('查看记录', () => this.openHistory())
  }

  @Builder
  History() {
    this.Header('漂移记录', () => this.showPage(PolarScreen.Menu))
    this.Note(() => '最近 ' + POLAR_LIMIT + ' 轮 · 手表时间')
    if (this.blockedStorage) {
      Text('原记录无法读取，可确认清除后重新记录').fontSize(9).fontColor(this.p().accent)
    } else if (this.rounds.length === 0) {
      this.Note(() => '暂无记录')
    }
    Row({ space: 4 }) {
      this.Key('导出文本', () => this.exportRecords())
      this.Key('清除记录', () => { this.clearPrompt = true; })
    }.width('100%')
    if (this.clearPrompt) {
      this.Note(() => '清除手表内全部漂移记录？')
      Row({ space: 4 }) {
        this.Key('取消', () => { this.clearPrompt = false; })
        this.Key('确认清除', () => this.clearRecords(), () => true)
      }.width('100%')
    }
    ForEach(this.rounds.slice(0, this.historyCount), (round: DriftRound) => {
      Column({ space: 2 }) {
        Text(localStamp(round.start) + ' · ' + round.starName + ' · ' + round.seconds + ' 秒')
          .fontSize(9).fontColor(this.p().fg)
        Text(polarAxisLabel(round.axis) + ' · ' + driftDirectionLabel(round.direction) + ' · ' +
          driftStrengthLabel(round.strength)).fontSize(8).fontColor(this.p().fg)
        Text('试调 ' + round.adjustments + ' 次 · ' + driftTrendLabel(round.trend))
          .fontSize(8).fontColor(this.p().fg)
      }.width('100%').padding(5).borderRadius(10).backgroundColor(this.p().card)
    }, (round: DriftRound) => round.start.toString())
    if (this.rounds.length > this.historyCount) {
      this.Full('更多记录', () => { this.historyCount += 8; })
    }
  }

  build() {
    Scroll(this.scroller) {
      Column({ space: 4 }) {
        if (this.screen === PolarScreen.Coarse) {
          this.Coarse()
        } else if (this.screen === PolarScreen.Setup) {
          this.Setup()
        } else if (this.screen === PolarScreen.Conditions) {
          this.Conditions()
        } else if (this.screen === PolarScreen.Select) {
          this.SelectStar()
        } else if (this.screen === PolarScreen.Ready) {
          this.Ready()
        } else if (this.screen === PolarScreen.Timing) {
          this.Timing()
        } else if (this.screen === PolarScreen.Record) {
          this.RecordDirection()
        } else if (this.screen === PolarScreen.Review) {
          this.Review()
        } else if (this.screen === PolarScreen.History) {
          this.History()
        } else {
          this.Menu()
        }
        if (this.message !== '') {
          Text(this.message).fontSize(9).fontColor(this.p().accent).textAlign(TextAlign.Center)
        }
      }.width('100%').padding({ left: 33, right: 33, top: 26, bottom: 25 })
    }.width('100%').height('100%').backgroundColor(this.p().bg).scrollBar(BarState.Off)
  }
}
