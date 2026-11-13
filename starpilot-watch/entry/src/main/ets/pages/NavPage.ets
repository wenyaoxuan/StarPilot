import { palette, Palette } from '../common/Theme';
import { AzAlt, azAltOfAxis, magMagnitude, shortestDelta, wrap360 } from '../common/Fusion';
import { twelveTiltFromAcceleration } from '../common/CameraPose';
import { sensorHub, AccHandler, GyroHandler, MagHandler } from '../common/SensorHub';
import { orientationHub } from '../common/OrientationHub';
import { OrientationSample, OrientationSampleHandler, RotationSample, RotationSampleHandler } from '../common/SensorData';
import { SolarBody, isSolarId, solarBody, solarHorizontal } from '../common/SolarSystem';
import { audit } from '../common/AuditLog';
import { MessierObject } from '../data/Messier';
import { findStaticTarget, targetDisplayName } from '../data/TargetCatalog';
import { CITIES, City } from '../data/Cities';
import { Horizontal, horizonMaskAt, jdFromUnixMs, sunAltitude, targetHorizontal } from '../common/Astro';

const SAMPLE_MAX_AGE_MS: number = 2000;
const NEAR_TARGET_DEG: number = 5;

@Component
export struct NavPage {
  @Prop @Watch('onActiveChanged') active: boolean = false;
  @Prop redMode: boolean = false;
  @Prop @Watch('onTargetChanged') englishNames: boolean = false;
  @Prop @Watch('onTargetChanged') cityIndex: number = 0;
  @Prop @Watch('onTargetChanged') targetId: string = '';
  @Prop @Watch('onTargetChanged') horizonMask: number[] = [];
  onOpenHorizon: () => void = () => {};
  onOpenAr: () => void = () => {};
  onChooseTarget: () => void = () => {};
  onClearTarget: () => void = () => {};
  @Prop @Watch('onTargetChanged') sightingCorrection: number = 0;
  onSightingCorrection: (value: number) => void = () => {};
  @State confirmSighting: boolean = false;
  @State sightingNote: string = '';

  @State azTop: number = 0;
  @State altTop: number = 0;
  @State headingReady: boolean = false;
  @State heightReady: boolean = false;
  @State source: string = '';
  @State quality: string = '';
  @State targetName: string = '';
  @State targetAz: number = 0;
  @State targetAlt: number = 0;
  @State targetFound: boolean = false;
  @State skyStatus: string = '';
  @State turnHint: string = '';
  @State liftHint: string = '';

  private ori: OrientationSample | null = null;
  private rotAz: number = 0;
  private rotAlt: number = 0;
  private rotAt: number = 0;
  private rotAccuracy: number = -1;
  private accAlt: number = 0;
  private accAt: number = 0;
  private mag: number = 0;
  private magAt: number = 0;
  private blocked: boolean = false;
  private listening: boolean = false;
  private timer: number = -1;
  private lastTargetMs: number = 0;
  private lastLogMs: number = 0;

  private oriHandler: OrientationSampleHandler = (s: OrientationSample): void => {
    this.ori = s;
    this.updateGuidance();
  };

  private rotHandler: RotationSampleHandler = (s: RotationSample): void => {
    if (s.valid) {
      const top: AzAlt = azAltOfAxis(s.x, s.y, s.z, s.w, 'y');
      this.rotAz = top.az;
      this.rotAlt = top.alt;
      this.rotAt = s.receivedAt;
      this.rotAccuracy = s.accuracy;
    } else {
      this.rotAt = 0;
    }
    this.updateGuidance();
  };

  private magHandler: MagHandler = (x: number, y: number, z: number): void => {
    this.mag = magMagnitude(x, y, z);
    this.magAt = Date.now();
    this.updateGuidance();
  };

  private gyroHandler: GyroHandler = (): void => {
    // Keep the ROT stream active on Watch 5.
  };

  private accHandler: AccHandler = (x: number, y: number, z: number): void => {
    const tilt: number | null = twelveTiltFromAcceleration(x, y, z);
    if (tilt !== null) {
      this.accAlt = tilt;
      this.accAt = Date.now();
    }
  };

  private p(): Palette {
    return palette(this.redMode);
  }

  aboutToAppear(): void {
    this.onActiveChanged();
  }

  aboutToDisappear(): void {
    this.stop();
  }

  onActiveChanged(): void {
    if (this.active) {
      this.start();
    } else {
      this.stop();
    }
  }

  onTargetChanged(): void {
    this.confirmSighting = false;
    this.refreshTarget();
  }

  private start(): void {
    if (this.listening) {
      return;
    }
    this.listening = true;
    this.refreshTarget();
    sensorHub.subscribeAcc(this.accHandler);
    sensorHub.subscribeGyro(this.gyroHandler);
    sensorHub.subscribeMag(this.magHandler);
    sensorHub.subscribeRotSample(this.rotHandler);
    orientationHub.subscribeSample(this.oriHandler);
    this.timer = setInterval(() => {
      const now: number = Date.now();
      if (now - this.lastTargetMs >= 5000) {
        this.refreshTarget();
      } else {
        this.updateGuidance();
      }
      if (now - this.lastLogMs >= 2000) {
        this.lastLogMs = now;
        audit('NAV', 'az=' + (this.headingReady ? this.azTop.toFixed(1) : '--') +
          ';alt=' + (this.heightReady ? this.altTop.toFixed(1) : '--') +
          ';src=' + this.source + ';mag=' + this.mag.toFixed(1) + ';quality=' + this.quality +
          ';target=' + this.targetId + ';status=' + this.skyStatus +
          ';hint=' + this.turnHint + ' / ' + this.liftHint);
      }
    }, 250);
  }

  private stop(): void {
    if (!this.listening) {
      return;
    }
    this.listening = false;
    orientationHub.unsubscribeSample(this.oriHandler);
    sensorHub.unsubscribeRotSample(this.rotHandler);
    sensorHub.unsubscribeMag(this.magHandler);
    sensorHub.unsubscribeGyro(this.gyroHandler);
    sensorHub.unsubscribeAcc(this.accHandler);
    clearInterval(this.timer);
    this.timer = -1;
    this.ori = null;
    this.rotAt = 0;
    this.accAt = 0;
    this.magAt = 0;
    this.updateGuidance();
  }

  private refreshTarget(): void {
    this.lastTargetMs = Date.now();
    if (this.targetId === '') {
      this.targetFound = false;
      this.skyStatus = '';
      this.updateGuidance();
      return;
    }
    const city: City = CITIES[this.cityIndex] ?? CITIES[0];
    const jd: number = jdFromUnixMs(this.lastTargetMs);
    let h: Horizontal | null = null;
    let name: string = '';
    if (isSolarId(this.targetId)) {
      const body: SolarBody | null = solarBody(this.targetId);
      if (body !== null) {
        name = targetDisplayName(body.id, body.name, body.nameEn, this.englishNames);
        h = solarHorizontal(this.targetId, jd, city.lat, city.lon);
      }
    } else {
      const object: MessierObject | null = findStaticTarget(this.targetId);
      if (object !== null) {
        const label: string = targetDisplayName(object.id, object.name, object.nameEn, this.englishNames);
        name = label === object.id ? object.id : object.id + ' ' + label;
        h = targetHorizontal({ raHours: object.raHours, decDeg: object.decDeg }, jd, city.lat, city.lon);
      }
    }
    if (h === null) {
      this.targetFound = false;
      this.skyStatus = '目标数据不可用';
      this.updateGuidance();
      return;
    }
    this.targetName = name;
    this.targetAz = h.azDeg;
    this.targetAlt = h.altDeg;
    this.targetFound = true;

    const obstruction: number = horizonMaskAt(this.horizonMask, h.azDeg);
    this.blocked = h.altDeg < 0 || h.altDeg < obstruction;
    let status: string = '';
    if (h.altDeg < 0) {
      status = '目标在地平线下';
    } else if (h.altDeg < obstruction) {
      status = '被遮挡 · 遮挡线 ' + obstruction.toFixed(0) + '°';
    } else if (this.targetId !== 'SUN') {
      const sun: number = sunAltitude(jd, city.lat, city.lon);
      if (sun > 0) {
        status = '白天';
      } else if (sun > -18) {
        status = '暮光中 · 天未全黑';
      }
    }
    this.skyStatus = status;
    this.updateGuidance();
  }

  private updateGuidance(): void {
    const now: number = Date.now();
    const ori: OrientationSample | null = this.ori;
    const rotFresh: boolean = this.rotAt > 0 && now - this.rotAt < SAMPLE_MAX_AGE_MS;
    const accFresh: boolean = this.accAt > 0 && now - this.accAt < 500;
    const oriFresh: boolean = ori !== null && ori.valid && now - ori.receivedAt < SAMPLE_MAX_AGE_MS;
    this.headingReady = oriFresh || rotFresh;
    this.heightReady = accFresh || rotFresh;
    if (this.heightReady) {
      this.altTop = accFresh ? this.accAlt : this.rotAlt;
    }
    this.source = oriFresh ? '系统方向' : (rotFresh ? 'ROT 回退' : '无新方位');
    if (oriFresh && ori !== null) {
      this.azTop = wrap360(ori.alpha);
    } else if (rotFresh) {
      this.azTop = this.rotAz;
    }
    if (this.headingReady) {
      this.azTop = wrap360(this.azTop + this.sightingCorrection);
    }

    const fieldFresh: boolean = this.magAt > 0 && now - this.magAt < SAMPLE_MAX_AGE_MS;
    const fieldWarning: boolean = fieldFresh && (this.mag < 25 || this.mag > 65);
    const headingLow: boolean = oriFresh && ori !== null ? ori.accuracy === 1 : this.rotAccuracy === 1;
    const trustHeading: boolean = this.headingReady && !fieldWarning && !headingLow;
    const trustHeight: boolean = accFresh || (rotFresh && this.rotAccuracy !== 1);
    this.quality = fieldWarning ? '磁场异常 · 方位仅供参考' : (this.headingReady && headingLow ? '方位精度低' : '');

    if (!this.targetFound || this.blocked) {
      this.turnHint = '';
      this.liftHint = '';
      return;
    }
    const turn: number = shortestDelta(this.azTop, this.targetAz);
    const lift: number = this.targetAlt - this.altTop;
    if (trustHeading && trustHeight && Math.abs(turn) <= NEAR_TARGET_DEG && Math.abs(lift) <= NEAR_TARGET_DEG) {
      this.turnHint = '接近目标';
      this.liftHint = '';
      return;
    }
    if (!trustHeading) {
      this.turnHint = this.headingReady ? '转向暂停' : '等待方位';
    } else if (Math.abs(turn) >= 178) {
      this.turnHint = '目标在身后 · 转身';
    } else if (Math.abs(turn) <= NEAR_TARGET_DEG) {
      this.turnHint = '方位接近';
    } else {
      this.turnHint = (turn > 0 ? '→ 右转 ' : '← 左转 ') + Math.abs(turn).toFixed(0) + '°';
    }
    if (!trustHeight) {
      this.liftHint = this.heightReady ? '高度精度低' : '等待高度';
    } else if (Math.abs(lift) <= NEAR_TARGET_DEG) {
      this.liftHint = '高度接近';
    } else {
      this.liftHint = (lift > 0 ? '↑ 抬高 ' : '↓ 降低 ') + Math.abs(lift).toFixed(0) + '°';
    }
  }

  private sightTarget(): void {
    this.refreshTarget();
    if (!this.targetFound || this.blocked || this.targetId === 'SUN' ||
        !this.headingReady || !this.heightReady || this.quality !== '' ||
        Math.abs(this.targetAlt) > 75 || Math.abs(this.targetAlt - this.altTop) > 5) {
      this.sightingNote = '请选可见目标，停稳并对齐高度后再试';
      return;
    }
    const rawAz: number = wrap360(this.azTop - this.sightingCorrection);
    const correction: number = shortestDelta(rawAz, this.targetAz);
    if (Math.abs(correction) > 45) {
      this.sightingNote = '偏差超过 45°，请检查目标和观测位置';
      return;
    }
    this.onSightingCorrection(correction);
    this.confirmSighting = false;
    this.sightingNote = '已按实物对准，本次有效';
    audit('NAV_SIGHT', 'target=' + this.targetId + ';correction=' + correction.toFixed(1));
  }

  @Builder
  Action(label: string, onTap: () => void) {
    Button(label)
      .fontSize(9)
      .height(27)
      .layoutWeight(1)
      .backgroundColor(this.p().card)
      .fontColor(this.p().fg)
      .onClick(onTap)
  }

  build() {
    Scroll() {
      Column({ space: 5 }) {
        Text('星空导航')
          .fontSize(12)
          .fontColor(this.p().accent)
          .fontWeight(FontWeight.Bold)

        Column({ space: 3 }) {
          if (this.targetFound) {
            Text(this.targetName)
              .fontSize(12)
              .fontColor(this.p().fg)
              .fontWeight(FontWeight.Bold)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          } else {
            Text(this.skyStatus !== '' ? this.skyStatus : '未选择目标')
              .fontSize(13)
              .fontColor(this.p().fg)
          }

          if (this.skyStatus !== '' && this.targetFound) {
            Text(this.skyStatus)
              .fontSize(this.blocked ? 13 : 9)
              .fontColor(this.p().accent)
          }
          if (this.targetId === 'SUN') {
            Text('太阳须使用合格太阳滤镜，严禁直视')
              .fontSize(9)
              .fontColor(this.p().accent)
              .textAlign(TextAlign.Center)
          }
          if (this.turnHint !== '') {
            Text(this.turnHint)
              .fontSize(17)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.p().fg)
          }
          if (this.liftHint !== '') {
            Text(this.liftHint)
              .fontSize(17)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.p().fg)
          }
          if (this.quality !== '') {
            Text(this.quality)
              .fontSize(9)
              .fontColor(this.p().accent)
          }
          if (this.targetFound) {
            Text('目标方位 ' + (Math.round(this.targetAz) % 360).toString() + '° · 高度 ' +
              this.targetAlt.toFixed(0) + '°')
              .fontSize(8)
              .fontColor(this.p().dim)
          }
        }
        .width('100%')
        .padding({ top: 6, bottom: 6, left: 6, right: 6 })
        .backgroundColor(this.p().card)
        .borderRadius(12)

        Text('12 点  ' + (this.headingReady ? (Math.round(this.azTop) % 360).toString() + '°' : '—') +
          '  ·  高度 ' + (this.heightReady ? this.altTop.toFixed(0) + '°' : '—'))
          .fontSize(9)
          .fontColor(this.p().fg)

        if (!this.targetFound) {
          Button('选择目标')
            .width('100%')
            .height(28)
            .fontSize(10)
            .backgroundColor(this.p().accent)
            .fontColor('#000000')
            .onClick(() => this.onChooseTarget())
        }

        Row({ space: 5 }) {
          this.Action('AR 星图', () => this.onOpenAr())
          this.Action('遮挡', () => this.onOpenHorizon())
        }
        .width('100%')

        Text('屏幕朝自己，用表盘 12 点边缘指向')
          .fontSize(8)
          .fontColor(this.p().dim)
          .textAlign(TextAlign.Center)

        if (this.targetFound && this.targetId !== 'SUN') {
          if (this.confirmSighting) {
            Text('用 12 点边缘实际对准 ' + this.targetName + '，停稳后确认。请以天空中的实物为准。')
              .fontSize(9).fontColor(this.p().fg).textAlign(TextAlign.Center)
            Row({ space: 5 }) {
              this.Action('已对准，校准', () => this.sightTarget())
              this.Action('取消', () => { this.confirmSighting = false; })
            }.width('100%')
          } else {
            Button('对准目标校准').width('100%').height(27).fontSize(9)
              .backgroundColor(this.p().card).fontColor(this.p().fg)
              .onClick(() => { this.sightingNote = ''; this.confirmSighting = true; })
          }
        }
        if (this.sightingCorrection !== 0) {
          Text('本次实物校准 ' + this.sightingCorrection.toFixed(1) + '° · 导航与 AR 共用')
            .fontSize(8).fontColor(this.p().accent).textAlign(TextAlign.Center)
          Button('清除实物校准').width('100%').height(25).fontSize(9)
            .backgroundColor(this.p().card).fontColor(this.p().fg)
            .onClick(() => { this.onSightingCorrection(0); this.sightingNote = ''; })
        }
        if (this.sightingNote !== '') {
          Text(this.sightingNote).fontSize(8).fontColor(this.p().accent).textAlign(TextAlign.Center)
        }

        if (this.targetFound) {
          Row({ space: 5 }) {
            this.Action('更换目标', () => this.onChooseTarget())
            this.Action('取消目标', () => this.onClearTarget())
          }
          .width('100%')
        }
      }
      .width('100%')
      .padding({ left: 36, right: 36, top: 26, bottom: 25 })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
  }
}
