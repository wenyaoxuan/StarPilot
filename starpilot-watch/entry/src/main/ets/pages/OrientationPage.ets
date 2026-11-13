import { sensor } from '@kit.SensorServiceKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { orientationHub, OrientationHandler } from '../common/OrientationHub';
import { audit } from '../common/AuditLog';

/**
 * Minimal diagnostic page for the system ORIENTATION sensor.
 *
 * It is deliberately standalone: no tracking code, no fusion, no magnetic
 * calibration. The goal is to find out whether Watch 5 exposes
 * SensorId.ORIENTATION and what alpha/beta/gamma mean on this hardware.
 */
@Component
export struct OrientationPage {
  @Prop @Watch('onActiveChanged') active: boolean = false;

  @State running: boolean = false;
  @State support: string = '未检测';
  @State info: string = '--';
  @State hasData: boolean = false;
  @State alpha: number = 0;
  @State beta: number = 0;
  @State gamma: number = 0;
  @State total: number = 0;
  @State hz: number = 0;
  @State live: boolean = false;
  @State errorText: string = '';
  @State marks: string[] = [];

  private subscribed: boolean = false;
  private totalCount: number = 0;
  private secCount: number = 0;
  private lastSampleMs: number = 0;
  private lastUiMs: number = 0;
  private timerId: number = -1;

  private readonly oriHandler: OrientationHandler =
    (alpha: number, beta: number, gamma: number): void => {
      const now: number = Date.now();
      this.totalCount++;
      this.secCount++;
      this.lastSampleMs = now;
      // Log every sample for frequency/axis analysis; UI is throttled below.
      audit('ORI_SAMPLE', `a=${alpha.toFixed(3)};b=${beta.toFixed(3)};` +
        `g=${gamma.toFixed(3)};t=${now}`);
      if (now - this.lastUiMs < 100) {
        return;
      }
      this.lastUiMs = now;
      this.hasData = true;
      this.alpha = alpha;
      this.beta = beta;
      this.gamma = gamma;
      this.live = true;
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
    const e: BusinessError = err as BusinessError;
    const line: string = `${name}: code=${e.code} msg=${e.message}`;
    this.errorText = this.errorText === '' ? line : `${this.errorText}；${line}`;
    audit('ORI_ERR', `${name}|${e.code}|${e.message}`);
  }

  private checkSupport(): void {
    this.support = '检测中';
    this.info = '--';
    sensor.getSingleSensor(sensor.SensorId.ORIENTATION)
      .then((s: sensor.Sensor) => {
        this.support = 'API 可用';
        this.info = `${s.sensorName} / ${s.vendorName} / id=${s.sensorId}`;
        audit('ORI_INFO', JSON.stringify(s));
      })
      .catch((err: BusinessError) => {
        this.support = 'API 不可用';
        this.pushError('getSingleSensor', err);
      });
  }

  private start(): void {
    if (this.running) {
      return;
    }
    this.running = true;
    this.errorText = '';
    this.marks = [];
    this.hasData = false;
    this.live = false;
    this.totalCount = 0;
    this.secCount = 0;
    this.total = 0;
    this.hz = 0;
    this.lastSampleMs = 0;
    this.checkSupport();

    orientationHub.subscribe(this.oriHandler);
    this.subscribed = true;
    audit('ORI_SUB', 'hub subscribe');

    this.timerId = setInterval(() => {
      this.hz = this.secCount;
      this.secCount = 0;
      this.total = this.totalCount;
      this.live = this.lastSampleMs > 0 && Date.now() - this.lastSampleMs < 2500;
    }, 1000);
  }

  private stop(): void {
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
    if (this.subscribed) {
      orientationHub.unsubscribe(this.oriHandler);
      audit('ORI_SUB', 'hub unsubscribe');
      this.subscribed = false;
    }
    this.running = false;
    this.live = false;
  }

  private mark(label: string): void {
    if (!this.hasData) {
      this.errorText = '无数据，先确认传感器有输出';
      return;
    }
    const line: string = `${label} ${this.alpha.toFixed(1)}°`;
    this.marks = this.marks.concat([line]);
    audit('ORI_MARK', `${label}=${this.alpha.toFixed(3)};b=${this.beta.toFixed(3)};g=${this.gamma.toFixed(3)}`);
  }

  @Builder
  MarkButton(label: string) {
    Button(label)
      .fontSize(9)
      .height(26)
      .width(42)
      .backgroundColor('#1C1C1E')
      .fontColor('#FF453A')
      .onClick(() => this.mark(label))
  }

  build() {
    Scroll() {
      Column({ space: 4 }) {
        Text('系统方向探针')
          .fontSize(13)
          .fontColor('#FF453A')
          .fontWeight(FontWeight.Bold)
        Text('SensorId.ORIENTATION · 仅本页订阅')
          .fontSize(8)
          .fontColor('#8E8E93')

        Text(`接口 ${this.support}`)
          .fontSize(9)
          .fontColor(this.support === 'API 可用' ? '#30D158' : '#FFD60A')
          .width('100%')
        Text(`传感器 ${this.info}`)
          .fontSize(7)
          .fontColor('#C7C7CC')
          .width('100%')
          .maxLines(2)

        Text(this.hasData ? `alpha  ${this.alpha.toFixed(1)}°` : 'alpha  --')
          .fontSize(16)
          .fontColor(this.live ? '#FFFFFF' : '#8E8E93')
          .width('100%')
        Text(this.hasData ? `beta ${this.beta.toFixed(1)}°   gamma ${this.gamma.toFixed(1)}°` : 'beta --   gamma --')
          .fontSize(9)
          .fontColor('#FFFFFF')
          .width('100%')

        Text('四方向记录（手动，不假设 alpha=12 点）')
          .fontSize(8)
          .fontColor('#8E8E93')
          .width('100%')
          .margin({ top: 2 })
        Row({ space: 4 }) {
          this.MarkButton('北')
          this.MarkButton('东')
          this.MarkButton('南')
          this.MarkButton('西')
        }
        .width('100%')

        Text(`样本 ${this.total} · ${this.hz} Hz · ${this.live ? '实时' : '无数据'}`)
          .fontSize(9)
          .fontColor('#FFD60A')
          .width('100%')

        if (this.errorText !== '') {
          Text(this.errorText)
            .fontSize(7)
            .fontColor('#FF6961')
            .width('100%')
            .maxLines(3)
        }

        Row({ space: 6 }) {
          Button(this.running ? '停止' : '开始')
            .fontSize(9)
            .height(28)
            .width(62)
            .backgroundColor(this.running ? '#3A0A08' : '#1C1C1E')
            .fontColor(this.running ? '#FF453A' : '#30D158')
            .onClick(() => {
              if (this.running) {
                this.stop();
              } else {
                this.start();
              }
            })
          Button('清零')
            .fontSize(9)
            .height(28)
            .width(62)
            .backgroundColor('#1C1C1E')
            .fontColor('#8E8E93')
            .onClick(() => {
              this.marks = [];
              this.errorText = '';
            })
          Text('100 ms')
            .fontSize(7)
            .fontColor('#8E8E93')
        }
        .width('100%')

        if (this.marks.length > 0) {
          ForEach(this.marks, (item: string, index: number) => {
            Text(item)
              .fontSize(9)
              .fontColor('#FFFFFF')
              .width('100%')
          }, (item: string, index: number) => `${index}_${item}`)
        }

        Text('记录值只用于判断 alpha 的零点和递增方向；不要据此直接当作航向。')
          .fontSize(7)
          .fontColor('#8E8E93')
          .width('100%')
          .margin({ top: 2 })
        Text(' ')
          .height(10)
      }
      .width('100%')
      .padding({ left: 36, right: 36, top: 34, bottom: 18 })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .focusable(false)
  }
}
