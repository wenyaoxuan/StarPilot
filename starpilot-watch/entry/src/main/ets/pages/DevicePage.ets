import { batteryInfo, deviceInfo } from '@kit.BasicServicesKit';
import { display } from '@kit.ArkUI';
import { audit } from '../common/AuditLog';

@Builder
function InfoRow(label: string, value: string) {
  Row() {
    Text(label)
      .fontSize(11)
      .fontColor('#8E8E93')
      .layoutWeight(1)
    Text(value)
      .fontSize(11)
      .fontColor('#FFFFFF')
      .textAlign(TextAlign.End)
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .layoutWeight(1)
  }
  .width('100%')
  .padding({ top: 3, bottom: 3 })
}

@Component
export struct DevicePage {
  @Prop @Watch('onActiveChanged') active: boolean = false;
  @State clock: string = '--:--:--';
  @State utc: string = '--';
  @State tzOffset: string = '--';
  @State model: string = '--';
  @State brand: string = '--';
  @State osName: string = '--';
  @State api: string = '--';
  @State devType: string = '--';
  @State market: string = '--';
  @State screen: string = '--';
  @State battery: string = '--';
  private timerId: number = -1;

  aboutToAppear(): void {
    this.readDevice();
    if (this.active) {
      this.startClock();
    }
  }

  aboutToDisappear(): void {
    this.stopClock();
  }

  onActiveChanged(): void {
    if (this.active) {
      this.startClock();
    } else {
      this.stopClock();
    }
  }

  private readDevice(): void {
    try {
      this.model = deviceInfo.productModel;
      this.brand = deviceInfo.brand;
      this.osName = deviceInfo.osFullName;
      this.api = deviceInfo.sdkApiVersion.toString();
      this.devType = deviceInfo.deviceType;
      this.market = deviceInfo.marketName;
    } catch (err) {
      this.model = `deviceInfo error: ${JSON.stringify(err)}`;
    }
    try {
      const d: display.Display = display.getDefaultDisplaySync();
      this.screen = `${d.width}x${d.height} @${d.densityPixels.toFixed(2)}`;
    } catch (err) {
      this.screen = `display error: ${JSON.stringify(err)}`;
    }
    try {
      this.battery = `${batteryInfo.batterySOC}% / chg=${batteryInfo.chargingStatus}`;
    } catch (err) {
      this.battery = `battery error: ${JSON.stringify(err)}`;
    }
  }

  private startClock(): void {
    if (this.timerId !== -1) {
      return;
    }
    this.tick();
    this.timerId = setInterval(() => {
      this.tick();
    }, 1000);
  }

  private stopClock(): void {
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
    this.clock = `${this.pad(now.getHours())}:${this.pad(now.getMinutes())}:${this.pad(now.getSeconds())}`;
    this.utc = now.toISOString();
    const off: number = -now.getTimezoneOffset();
    const sign: string = off >= 0 ? '+' : '-';
    const abs: number = Math.abs(off);
    this.tzOffset = `UTC${sign}${this.pad(Math.floor(abs / 60))}:${this.pad(abs % 60)}`;
    // Refresh every tick so the 30-minute power test (T15) can read the level
    // without leaving the page.
    try {
      this.battery = `${batteryInfo.batterySOC}% / chg=${batteryInfo.chargingStatus}`;
    } catch (err) {
      this.battery = `battery error: ${JSON.stringify(err)}`;
    }
  }

  private dump(): void {
    this.tick();
    audit('DEVICE', `model=${this.model};brand=${this.brand};os=${this.osName};api=${this.api};` +
      `type=${this.devType};market=${this.market};screen=${this.screen};battery=${this.battery};` +
      `tz=${this.tzOffset};utc=${this.utc}`);
  }

  build() {
    Scroll() {
      Column({ space: 6 }) {
        Text('StarPilot S0')
          .fontSize(13)
          .fontColor('#FF453A')
          .fontWeight(FontWeight.Bold)
        Text(this.clock)
          .fontSize(30)
          .fontColor('#FFFFFF')
          .fontWeight(FontWeight.Lighter)
          .maxLines(1)
          .width('100%')
          .textAlign(TextAlign.Center)
        Text('设备审计版 · 非成品')
          .fontSize(10)
          .fontColor('#8E8E93')
          .margin({ bottom: 6 })

        InfoRow('型号', this.model)
        InfoRow('品牌', this.brand)
        InfoRow('系统', this.osName)
        InfoRow('API', this.api)
        InfoRow('设备类型', this.devType)
        InfoRow('市场名', this.market)
        InfoRow('屏幕', this.screen)
        InfoRow('电量', this.battery)
        InfoRow('时区', this.tzOffset)
        InfoRow('UTC', this.utc)

        Button('输出设备日志')
          .fontSize(11)
          .height(30)
          .backgroundColor('#1C1C1E')
          .fontColor('#FF453A')
          .margin({ top: 6 })
          .onClick(() => this.dump())

        Text('左右滑动或旋转表冠切换页面')
          .fontSize(9)
          .fontColor('#5A5A5E')
          .margin({ top: 2, bottom: 10 })
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
