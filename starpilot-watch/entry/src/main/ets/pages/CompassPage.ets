import { preferences } from '@kit.ArkData';
import { sensorHub, AccHandler, GyroHandler, MagHandler, RotHandler } from '../common/SensorHub';
import { orientationHub, OrientationHandler } from '../common/OrientationHub';
import { AzAlt, azAltOfAxis, magHeading, magMagnitude, wrap360 } from '../common/Fusion';
import { audit } from '../common/AuditLog';

const RAD2DEG: number = 180 / Math.PI;

@Component
export struct CompassPage {
  @Prop @Watch('onActiveChanged') active: boolean = false;

  @State azTop: number = 0;
  @State altTop: number = 0;
  @State rawTop: number = 0;
  @State azRight: number = 0;
  @State altRight: number = 0;
  @State mag: number = 0;
  @State headingOffset: number = 0;
  @State pitch: number = 0;
  @State roll: number = 0;
  @State source: string = '--';
  @State hasRot: boolean = false;
  @State hasValid: boolean = false;
  @State listening: boolean = false;
  @State errorText: string = '';

  private ax: number = 0;
  private ay: number = 0;
  private az: number = 0;
  private mx: number = 0;
  private my: number = 0;
  private mz: number = 0;
  private gx: number = 0;
  private gy: number = 0;
  private gz: number = 0;
  private hasAccel: boolean = false;
  private hasMag: boolean = false;
  private lastOriMs: number = 0;
  private lastUi: number = 0;
  private logTimer: number = -1;
  private store: preferences.Preferences | null = null;

  private isOrientationFresh(): boolean {
    return this.lastOriMs > 0 && Date.now() - this.lastOriMs < 2000;
  }

  private oriHandler: OrientationHandler = (alpha: number, beta: number, gamma: number): void => {
    this.lastOriMs = Date.now();
    this.rawTop = alpha;
    this.azTop = wrap360(alpha + this.headingOffset);
    this.hasValid = true;
    this.source = 'ORIENTATION';
    this.lastUi = Date.now();
  };

  private rotHandler: RotHandler = (qx: number, qy: number, qz: number, qw: number): void => {
    const qn: number = Math.sqrt(qx * qx + qy * qy + qz * qz + qw * qw);
    if (qn < 0.5) {
      this.hasRot = false;
      if (!this.isOrientationFresh()) {
        this.source = 'ROT 无有效数据';
        this.hasValid = false;
      }
      return;
    }
    this.hasRot = true;
    const top: AzAlt = azAltOfAxis(qx, qy, qz, qw, 'y');
    const right: AzAlt = azAltOfAxis(qx, qy, qz, qw, 'x');
    this.altTop = top.alt;
    this.azRight = right.az;
    this.altRight = right.alt;
    // ORIENTATION is the heading source. ROT only supplies altitude/attitude
    // and acts as a fallback when the system orientation stream stops.
    if (this.isOrientationFresh()) {
      this.hasValid = true;
      this.source = 'ORIENTATION';
    } else {
      this.rawTop = top.az;
      this.azTop = wrap360(top.az + this.headingOffset);
      this.source = 'ROTATION_VECTOR';
      this.hasValid = true;
    }
    this.lastUi = Date.now();
  };

  private magHandler: MagHandler = (mx: number, my: number, mz: number): void => {
    this.mx = mx;
    this.my = my;
    this.mz = mz;
    this.hasMag = true;
    this.mag = magMagnitude(mx, my, mz);
    if (!this.hasRot && this.hasAccel && !this.isOrientationFresh()) {
      this.applyFallback();
    }
  };

  private gyroHandler: GyroHandler = (gx: number, gy: number, gz: number): void => {
    // The rotation-vector fusion on Watch 5 needs the gyroscope stream alive.
    // Values are not displayed yet; S3 will use them for smoothing.
    this.gx = gx;
    this.gy = gy;
    this.gz = gz;
  };

  private accHandler: AccHandler = (ax: number, ay: number, az: number): void => {
    this.ax = ax;
    this.ay = ay;
    this.az = az;
    this.hasAccel = true;
    this.pitch = Math.atan2(-ax, Math.sqrt(ay * ay + az * az)) * RAD2DEG;
    this.roll = Math.atan2(ay, az) * RAD2DEG;
    if (!this.hasRot && this.hasMag && !this.isOrientationFresh()) {
      this.applyFallback();
    }
  };

  aboutToAppear(): void {
    this.loadOffset();
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

  private loadOffset(): void {
    try {
      const ctx = this.getUIContext().getHostContext();
      if (ctx !== undefined) {
        this.store = preferences.getPreferencesSync(ctx, { name: 'starpilot_s0' });
        this.headingOffset = this.store.getSync('heading_offset', 0) as number;
        const migrated: boolean = this.store.getSync('ori_heading_v2', false) as boolean;
        if (!migrated) {
          this.headingOffset = 0;
          this.store.putSync('heading_offset', 0);
          this.store.putSync('ori_heading_v2', true);
          this.store.flush();
          audit('COMPASS', 'legacy offset cleared for ORIENTATION');
        }
      }
    } catch (err) {
      this.errorText = `prefs: ${JSON.stringify(err)}`;
    }
  }

  private saveOffset(): void {
    if (this.store === null) {
      return;
    }
    try {
      this.store.putSync('heading_offset', this.headingOffset);
      this.store.flush();
    } catch (err) {
      this.errorText = `save: ${JSON.stringify(err)}`;
    }
  }

  private start(): void {
    if (this.listening) {
      return;
    }
    this.listening = true;
    this.errorText = '';
    sensorHub.subscribeAcc(this.accHandler);
    sensorHub.subscribeGyro(this.gyroHandler);
    sensorHub.subscribeMag(this.magHandler);
    sensorHub.subscribeRot(this.rotHandler);
    orientationHub.subscribe(this.oriHandler);

    this.logTimer = setInterval(() => {
      audit('COMPASS', `azTop=${this.azTop.toFixed(1)};altTop=${this.altTop.toFixed(1)};` +
        `azRight=${this.azRight.toFixed(1)};rawTop=${this.rawTop.toFixed(1)};offset=${this.headingOffset};` +
        `mag=${this.mag.toFixed(1)};src=${this.source};pitch=${this.pitch.toFixed(1)};roll=${this.roll.toFixed(1)}`);
    }, 2000);
  }

  private applyFallback(): void {
    if (this.mag < 5 || this.mag > 200) {
      this.source = this.mag < 5 ? '无有效磁数据' : '磁力计量纲异常';
      this.hasValid = false;
      return;
    }
    this.hasValid = true;
    const h: AzAlt = magHeading(this.ax, this.ay, this.az, this.mx, this.my, this.mz);
    this.rawTop = h.az;
    this.altTop = 0;
    this.azTop = wrap360(h.az + this.headingOffset);
    this.azRight = wrap360(h.az + 90 + this.headingOffset);
    this.altRight = 0;
    this.source = 'MAG+ACC';
  }

  private stop(): void {
    if (!this.listening) {
      return;
    }
    this.listening = false;
    orientationHub.unsubscribe(this.oriHandler);
    sensorHub.unsubscribeRot(this.rotHandler);
    sensorHub.unsubscribeMag(this.magHandler);
    sensorHub.unsubscribeGyro(this.gyroHandler);
    sensorHub.unsubscribeAcc(this.accHandler);
    if (this.logTimer !== -1) {
      clearInterval(this.logTimer);
      this.logTimer = -1;
    }
    audit('COMPASS_STOP', `lastAz=${this.azTop.toFixed(1)};src=${this.source}`);
  }

  private magColor(): string {
    if (this.mag < 25 || this.mag > 65) {
      return '#FF9F0A';
    }
    return '#30D158';
  }

  private magLabel(): string {
    if (this.mag < 1) {
      return '无数据';
    }
    if (this.mag > 200) {
      return '量纲异常/未校准';
    }
    if (this.mag < 25) {
      return '偏弱/异常';
    }
    if (this.mag > 65) {
      return '磁干扰';
    }
    return '磁场正常';
  }

  private zero(): void {
    this.headingOffset = wrap360(this.headingOffset - this.rawTop);
    this.azTop = wrap360(this.rawTop + this.headingOffset);
    this.saveOffset();
    audit('COMPASS_ZERO', `raw=${this.rawTop.toFixed(1)};offset=${this.headingOffset.toFixed(1)}`);
  }

  private clearZero(): void {
    this.headingOffset = 0;
    this.azTop = wrap360(this.rawTop);
    this.saveOffset();
    audit('COMPASS_ZERO', 'cleared');
  }

  build() {
    Scroll() {
      Column({ space: 4 }) {
        Text('S0 罗盘 / 姿态')
          .fontSize(12)
          .fontColor('#FF453A')
          .fontWeight(FontWeight.Bold)

        Row({ space: 2 }) {
          Text(this.hasValid ? this.azTop.toFixed(0) : '--')
            .fontSize(56)
            .fontColor('#FFFFFF')
            .fontWeight(FontWeight.Lighter)
          Text(this.hasValid ? '°' : '')
            .fontSize(24)
            .fontColor('#FFFFFF')
            .margin({ bottom: 10 })
        }
        .alignItems(VerticalAlign.Bottom)
        Text('12 点方向方位角')
          .fontSize(9)
          .fontColor('#8E8E93')

        Text(this.hasValid ? `高度 ${this.altTop.toFixed(1)}°` : '高度 --')
          .fontSize(16)
          .fontColor('#FFFFFF')

        Row({ space: 10 }) {
          Text(`磁 ${this.mag.toFixed(1)}µT`)
            .fontSize(9)
            .fontColor(this.magColor())
          Text(this.magLabel())
            .fontSize(9)
            .fontColor(this.magColor())
        }

        Row({ space: 10 }) {
          Text(this.hasValid ? `3点 ${this.azRight.toFixed(0)}°/${this.altRight.toFixed(0)}°` : '3点 --')
            .fontSize(9)
            .fontColor('#C7C7CC')
          Text(this.hasValid ? `原始 ${this.rawTop.toFixed(0)}°` : '原始 --')
            .fontSize(9)
            .fontColor('#C7C7CC')
        }

        Text(`倾角 P${this.pitch.toFixed(0)}° R${this.roll.toFixed(0)}°`)
          .fontSize(9)
          .fontColor('#C7C7CC')
        Text(`数据源 ${this.source} · 偏移 ${this.headingOffset.toFixed(0)}°`)
          .fontSize(9)
          .fontColor('#8E8E93')

        Row({ space: 8 }) {
          Button('归零')
            .fontSize(11)
            .height(28)
            .backgroundColor('#1C1C1E')
            .fontColor('#FF453A')
            .onClick(() => this.zero())
          Button('清除')
            .fontSize(11)
            .height(28)
            .backgroundColor('#1C1C1E')
            .fontColor('#8E8E93')
            .onClick(() => this.clearZero())
        }
        .margin({ top: 4 })

        Text(this.errorText.length > 0 ? this.errorText : '8 字校准后，将 12 点对准目标')
          .fontSize(8)
          .fontColor(this.errorText.length > 0 ? '#FF453A' : '#5A5A5E')
          .textAlign(TextAlign.Center)
          .maxLines(3)
          .margin({ top: 2, bottom: 10 })
      }
      .width('100%')
      .padding({ left: 36, right: 36, top: 36, bottom: 20 })
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .focusable(false)
  }
}
