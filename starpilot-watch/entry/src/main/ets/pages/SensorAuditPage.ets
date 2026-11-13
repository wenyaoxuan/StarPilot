import {
  GyroSample,
  OrientationSample,
  RotationSample,
  SensorStats,
  accuracyLabel
} from '../common/SensorData';
import { orientationHub } from '../common/OrientationHub';
import { cameraPoseFromQuat, vectorAzAlt } from '../common/CameraPose';
import { rotateByQuat, Vec3 } from '../common/Fusion';
import { CITIES, City } from '../data/Cities';
import { sensor } from '@kit.SensorServiceKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { audit } from '../common/AuditLog';
import { shortestDelta } from '../common/Fusion';
import { sensorHub } from '../common/SensorHub';

@Component
export struct SensorAuditPage {
  @Prop @Watch('onActiveChanged') active: boolean = false;
  @Prop cityIndex: number = 0;

  @State oriText: string = '--';
  @State oriMeta: string = '--';
  @State rotText: string = '--';
  @State rotMeta: string = '--';
  @State gyroText: string = '--';
  @State gyroMeta: string = '--';
  @State statsText: string = '--';
  @State sourceText: string = 'ROT +Z forward (ORIENTATION 对照)';
  @State f2Text: string = '--';
  @State f5Text: string = '--';
  @State declText: string = 'decl --';

  private listening: boolean = false;
  private lastUiMs: number = 0;
  private timerId: number = -1;
  private lastOri: OrientationSample | null = null;
  private lastRot: RotationSample | null = null;
  private lastGyro: GyroSample | null = null;
  private oriBad: number[] = [];
  private rotBad: number[] = [];
  private gyroBad: number[] = [];
  private oriStats: SensorStats | null = null;
  private rotStats: SensorStats | null = null;
  private gyroStats: SensorStats | null = null;

  private readonly oriHandler = (s: OrientationSample): void => {
    this.lastOri = s;
    if (!s.valid) {
      this.oriBad.push(s.receivedAt);
    }
    this.pruneBad();
    this.requestUi();
  };

  private readonly rotHandler = (s: RotationSample): void => {
    this.lastRot = s;
    if (!s.valid) {
      this.rotBad.push(s.receivedAt);
    }
    this.pruneBad();
    this.requestUi();
  };

  private readonly gyroHandler = (s: GyroSample): void => {
    this.lastGyro = s;
    if (!s.valid) {
      this.gyroBad.push(s.receivedAt);
    }
    this.pruneBad();
    this.requestUi();
  };

  aboutToAppear(): void {
    if (this.active) {
      this.start();
    }
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

  private loadDeclination(): void {
    const city: City = CITIES[this.cityIndex >= 0 && this.cityIndex < CITIES.length ? this.cityIndex : 0];
    const loc: sensor.LocationOptions = { latitude: city.lat, longitude: city.lon, altitude: 0 };
    sensor.getGeomagneticInfo(loc, Date.now())
      .then((g: sensor.GeomagneticResponse) => {
        this.declText = `decl ${g.deflectionAngle.toFixed(2)}° · dip ${g.geomagneticDip.toFixed(2)}°` +
          ` · H ${g.levelIntensity.toFixed(0)}nT`;
        audit('F5_DECL', `decl=${g.deflectionAngle};dip=${g.geomagneticDip};H=${g.levelIntensity};city=${city.name}`);
      })
      .catch((err: BusinessError) => {
        this.declText = `getGeomagneticInfo code=${err.code} ${err.message}`;
        audit('F5_DECL_ERR', `${err.code};${err.message}`);
      });
  }

  private start(): void {
    if (this.listening) {
      return;
    }
    this.listening = true;
    this.loadDeclination();
    orientationHub.subscribeSample(this.oriHandler);
    sensorHub.subscribeRotSample(this.rotHandler);
    sensorHub.subscribeGyroSample(this.gyroHandler);
    this.timerId = setInterval(() => {
      this.refreshStats();
      this.renderUi();
    }, 1000);
  }

  private stop(): void {
    if (!this.listening) {
      return;
    }
    this.listening = false;
    orientationHub.unsubscribeSample(this.oriHandler);
    sensorHub.unsubscribeRotSample(this.rotHandler);
    sensorHub.unsubscribeGyroSample(this.gyroHandler);
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  private requestUi(): void {
    const now: number = Date.now();
    if (now - this.lastUiMs < 200) {
      return;
    }
    this.lastUiMs = now;
    this.refreshStats();
    this.renderUi();
  }

  private refreshStats(): void {
    this.oriStats = orientationHub.statsSnapshot();
    this.rotStats = sensorHub.rotStatsSnapshot();
    this.gyroStats = sensorHub.gyroStatsSnapshot();
  }

  private pruneBad(): void {
    const cut: number = Date.now() - 60000;
    this.oriBad = this.oriBad.filter((t: number) => t >= cut);
    this.rotBad = this.rotBad.filter((t: number) => t >= cut);
    this.gyroBad = this.gyroBad.filter((t: number) => t >= cut);
  }

  private age(receivedAt: number): string {
    if (receivedAt <= 0) {
      return '--';
    }
    const ms: number = Date.now() - receivedAt;
    return `${ms} ms${ms > 2000 ? ' STALE' : ''}`;
  }

  private renderUi(): void {
    const o: OrientationSample | null = this.lastOri;
    if (o !== null) {
      this.oriText = `${o.alpha.toFixed(2)}  ${o.beta.toFixed(2)}  ${o.gamma.toFixed(2)}`;
      this.oriMeta = `${accuracyLabel(o.accuracy, o.accuracyKnown)} · ts ${o.timestamp} · age ${this.age(o.receivedAt)}` +
        (o.valid ? '' : ` · INVALID ${o.reason}`);
    }
    const r: RotationSample | null = this.lastRot;
    if (r !== null) {
      this.rotText = `${r.x.toFixed(3)} ${r.y.toFixed(3)} ${r.z.toFixed(3)} ${r.w.toFixed(3)}`;
      this.rotMeta = `${accuracyLabel(r.accuracy, r.accuracyKnown)} · ts ${r.timestamp} · age ${this.age(r.receivedAt)}` +
        ` · norm ${r.rawNorm.toFixed(3)}→${r.norm.toFixed(3)}` + (r.valid ? '' : ` · INVALID ${r.reason}`);
    }
    if (o !== null && r !== null) {
      const pose = cameraPoseFromQuat(r.x, r.y, r.z, r.w);
      const view = vectorAzAlt(pose.forward);
      const dAz = shortestDelta(o.alpha, view.az);
      this.f2Text = `B 相机 +Z: ${view.az.toFixed(1)}° / ${view.alt.toFixed(1)}°` +
        `  A ORI α: ${o.alpha.toFixed(1)}°  Δaz ${dAz.toFixed(1)}°`;
      const yv: Vec3 = rotateByQuat(-r.x, -r.y, -r.z, r.w, new Vec3(0, 1, 0));
      const ya = vectorAzAlt(new Vec3(-yv.x, yv.y, yv.z));
      const dTop = shortestDelta(o.alpha, ya.az);
      this.f5Text = `ROT +Y: ${ya.az.toFixed(1)}° / ${ya.alt.toFixed(1)}° · ORI α ${o.alpha.toFixed(1)}° · Δ ${dTop.toFixed(1)}°
` + this.declText;
    }
    const g: GyroSample | null = this.lastGyro;
    if (g !== null) {
      this.gyroText = `${g.x.toFixed(2)}  ${g.y.toFixed(2)}  ${g.z.toFixed(2)}`;
      this.gyroMeta = `${accuracyLabel(g.accuracy, g.accuracyKnown)} · ts ${g.timestamp} · age ${this.age(g.receivedAt)}` +
        (g.valid ? '' : ` · INVALID ${g.reason}`);
    }
    const os: SensorStats | null = this.oriStats;
    const rs: SensorStats | null = this.rotStats;
    const gs: SensorStats | null = this.gyroStats;
    if (os !== null && rs !== null && gs !== null) {
      this.statsText = `ORI ok ${os.valid}/${os.samples} bad ${os.invalid} dup ${os.duplicates} reg ${os.regressions} stale ${os.stale}\n` +
        `ROT ok ${rs.valid}/${rs.samples} bad ${rs.invalid} dup ${rs.duplicates} reg ${rs.regressions} stale ${rs.stale}\n` +
        `GYR ok ${gs.valid}/${gs.samples} bad ${gs.invalid} dup ${gs.duplicates} reg ${gs.regressions} stale ${gs.stale}\n` +
        `bad60s ORI ${this.oriBad.length} / ROT ${this.rotBad.length} / GYR ${this.gyroBad.length}\n` +
        `last reason: ORI ${os.lastReason === '' ? '-' : os.lastReason} / ROT ${rs.lastReason === '' ? '-' : rs.lastReason} / GYR ${gs.lastReason === '' ? '-' : gs.lastReason}`;
    }
  }

  build() {
    Scroll() {
      Column({ space: 2 }) {
        Text('传感器数据审计')
          .fontSize(12)
          .fontColor('#FF453A')
          .fontWeight(FontWeight.Bold)
        Text('F1：元数据/精度/时间戳/异常计数')
          .fontSize(7)
          .fontColor('#8E8E93')

        Text('ORIENTATION')
          .fontSize(8)
          .fontColor('#FFD60A')
          .width('100%')
          .margin({ top: 2 })
        Text(this.oriText)
          .fontSize(9)
          .fontColor('#FFFFFF')
          .width('100%')
        Text(this.oriMeta)
          .fontSize(7)
          .fontColor('#8E8E93')
          .width('100%')
          .maxLines(2)

        Text('ROTATION_VECTOR')
          .fontSize(8)
          .fontColor('#FFD60A')
          .width('100%')
          .margin({ top: 2 })
        Text(this.rotText)
          .fontSize(9)
          .fontColor('#FFFFFF')
          .width('100%')
        Text(this.rotMeta)
          .fontSize(7)
          .fontColor('#8E8E93')
          .width('100%')
          .maxLines(2)

        Text('GYROSCOPE')
          .fontSize(8)
          .fontColor('#FFD60A')
          .width('100%')
          .margin({ top: 2 })
        Text(this.gyroText)
          .fontSize(9)
          .fontColor('#FFFFFF')
          .width('100%')
        Text(this.gyroMeta)
          .fontSize(7)
          .fontColor('#8E8E93')
          .width('100%')
          .maxLines(2)

        Text(this.statsText)
          .fontSize(7)
          .fontColor('#C7C7CC')
          .width('100%')
          .margin({ top: 3 })

        Text(this.f5Text)
          .fontSize(7)
          .fontColor('#C7C7CC')
          .width('100%')
          .maxLines(3)
          .margin({ top: 2 })
        Text(this.f2Text)
          .fontSize(7)
          .fontColor('#FFD60A')
          .width('100%')
          .margin({ top: 2 })
        Text('源：' + this.sourceText)
          .fontSize(7)
          .fontColor('#8E8E93')
          .width('100%')
          .margin({ top: 2 })
        Text('原始磁力计/加速度计：AR 未订阅；不伪造原始读数')
          .fontSize(7)
          .fontColor('#8E8E93')
          .width('100%')
        Text(' ')
          .height(10)
      }
      .width('100%')
      .padding({ left: 34, right: 34, top: 32, bottom: 18 })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .focusable(false)
  }
}
