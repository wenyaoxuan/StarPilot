import { sensor } from '@kit.SensorServiceKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { audit } from '../common/AuditLog';
import { sensorHub, AccHandler, GyroHandler, MagHandler, RotHandler } from '../common/SensorHub';

@Component
export struct SensorPage {
  @Prop @Watch('onActiveChanged') active: boolean = false;

  @State accel: string = '--';
  @State gyro: string = '--';
  @State mag: string = '--';
  @State rot: string = '--';
  @State accelHz: number = 0;
  @State rotHz: number = 0;
  @State sensorList: string[] = [];
  @State errors: string[] = [];
  @State listening: boolean = false;

  private lastAccelUi: number = 0;
  private lastGyroUi: number = 0;
  private lastMagUi: number = 0;
  private lastRotUi: number = 0;
  private accelCount: number = 0;
  private rotCount: number = 0;
  private hzTimer: number = -1;
  private logTimer: number = -1;

  private accHandler: AccHandler = (x: number, y: number, z: number): void => {
    this.accelCount++;
    const now: number = Date.now();
    if (now - this.lastAccelUi < 150) {
      return;
    }
    this.lastAccelUi = now;
    this.accel = `${x.toFixed(2)}  ${y.toFixed(2)}  ${z.toFixed(2)}`;
  };

  private gyroHandler: GyroHandler = (x: number, y: number, z: number): void => {
    const now: number = Date.now();
    if (now - this.lastGyroUi < 150) {
      return;
    }
    this.lastGyroUi = now;
    this.gyro = `${x.toFixed(3)}  ${y.toFixed(3)}  ${z.toFixed(3)}`;
  };

  private magHandler: MagHandler = (x: number, y: number, z: number): void => {
    const now: number = Date.now();
    if (now - this.lastMagUi < 150) {
      return;
    }
    this.lastMagUi = now;
    const m: number = Math.sqrt(x * x + y * y + z * z);
    this.mag = `${x.toFixed(1)} ${y.toFixed(1)} ${z.toFixed(1)} | ${m.toFixed(1)}uT`;
  };

  private rotHandler: RotHandler = (x: number, y: number, z: number, w: number): void => {
    this.rotCount++;
    const now: number = Date.now();
    if (now - this.lastRotUi < 150) {
      return;
    }
    this.lastRotUi = now;
    this.rot = `${x.toFixed(3)} ${y.toFixed(3)} ${z.toFixed(3)} ${w.toFixed(3)}`;
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

  private pushError(name: string, err: BusinessError): void {
    const e = err as BusinessError;
    this.errors = this.errors.concat([`${name}: code=${e.code} msg=${e.message}`]);
    audit('SENSOR_ERR', `${name}|${e.code}|${e.message}`);
  }

  private loadList(): void {
    try {
      const data: Array<sensor.Sensor> = sensor.getSensorListSync();
      const out: string[] = [];
      for (let i = 0; i < data.length; i++) {
        const item: string = JSON.stringify(data[i]);
        out.push(item);
        audit('SENSOR_ITEM', item);
      }
      this.sensorList = out;
      audit('SENSOR_LIST', `count=${out.length}`);
    } catch (err) {
      this.pushError('getSensorList', err as BusinessError);
    }
  }

  private start(): void {
    if (this.listening) {
      return;
    }
    this.listening = true;
    this.errors = [];
    this.loadList();

    sensorHub.subscribeAcc(this.accHandler);
    sensorHub.subscribeGyro(this.gyroHandler);
    sensorHub.subscribeMag(this.magHandler);
    sensorHub.subscribeRot(this.rotHandler);

    this.hzTimer = setInterval(() => {
      this.accelHz = this.accelCount;
      this.rotHz = this.rotCount;
      this.accelCount = 0;
      this.rotCount = 0;
    }, 1000);

    // 2 Hz snapshot to hilog for later analysis; capture with hdc hilog.
    this.logTimer = setInterval(() => {
      audit('LIVE', `acc=${this.accel};gyro=${this.gyro};mag=${this.mag};rot=${this.rot};` +
        `accHz=${this.accelHz};rotHz=${this.rotHz};err=${this.errors.length}`);
    }, 2000);
  }

  private stop(): void {
    if (!this.listening) {
      return;
    }
    this.listening = false;
    sensorHub.unsubscribeAcc(this.accHandler);
    sensorHub.unsubscribeGyro(this.gyroHandler);
    sensorHub.unsubscribeMag(this.magHandler);
    sensorHub.unsubscribeRot(this.rotHandler);

    if (this.hzTimer !== -1) {
      clearInterval(this.hzTimer);
      this.hzTimer = -1;
    }
    if (this.logTimer !== -1) {
      clearInterval(this.logTimer);
      this.logTimer = -1;
    }
    audit('SENSOR_STOP', `errors=${this.errors.length}`);
  }

  build() {
    Scroll() {
      Column({ space: 5 }) {
        Text('传感器探针')
          .fontSize(13)
          .fontColor('#FF453A')
          .fontWeight(FontWeight.Bold)
        Text('仅本页订阅；离开即退订')
          .fontSize(9)
          .fontColor('#8E8E93')

        Text(`ACC  ${this.accel}`)
          .fontSize(10)
          .fontColor('#FFFFFF')
          .width('100%')
        Text(`GYR  ${this.gyro}`)
          .fontSize(10)
          .fontColor('#FFFFFF')
          .width('100%')
        Text(`MAG  ${this.mag}`)
          .fontSize(10)
          .fontColor('#FFFFFF')
          .width('100%')
        Text(`ROT  ${this.rot}`)
          .fontSize(10)
          .fontColor('#FFFFFF')
          .width('100%')
        Text(`实测频率  加速度 ${this.accelHz} Hz / 旋转矢量 ${this.rotHz} Hz`)
          .fontSize(9)
          .fontColor('#FFD60A')
          .width('100%')

        if (this.errors.length > 0) {
          Text(`错误 ${this.errors.length}`)
            .fontSize(10)
            .fontColor('#FF453A')
            .width('100%')
          ForEach(this.errors, (item: string, index: number) => {
            Text(item)
              .fontSize(8)
              .fontColor('#FF6961')
              .width('100%')
          }, (item: string, index: number) => `${index}_${item}`)
        }

        Text(`传感器列表 (${this.sensorList.length})`)
          .fontSize(10)
          .fontColor('#8E8E93')
          .width('100%')
          .margin({ top: 4 })
        ForEach(this.sensorList, (item: string, index: number) => {
          Text(item)
            .fontSize(7)
            .fontColor('#C7C7CC')
            .width('100%')
        }, (item: string, index: number) => `${index}_${item}`)

        Text(' ')
          .height(10)
      }
      .width('100%')
      .padding({ left: 36, right: 36, top: 36, bottom: 20 })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .focusable(false)
  }
}
