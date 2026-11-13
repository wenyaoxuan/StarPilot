import { DevicePage } from './DevicePage';
import { SensorPage } from './SensorPage';
import { CompassPage } from './CompassPage';
import { OrientationPage } from './OrientationPage';
import { SensorAuditPage } from './SensorAuditPage';
import { ToolsPage } from './ToolsPage';

@Component
export struct DiagnosticsPage {
  @Prop cityIndex: number = 0;
  onClose: () => void = () => {
  };

  @State current: number = 0;
  private controller: SwiperController = new SwiperController();
  private crownAcc: number = 0;

  aboutToAppear(): void {
    setTimeout(() => {
      try {
        this.getUIContext().getFocusController().requestFocus('diagRoot');
      } catch (err) {
        // focus is best-effort
      }
    }, 250);
  }

  private go(delta: number): void {
    if (delta > 0) {
      this.controller.showNext();
    } else {
      this.controller.showPrevious();
    }
    this.crownAcc = 0;
    try {
      this.getUIContext().getFocusController().requestFocus('diagRoot');
    } catch (err) {
      // focus is best-effort
    }
  }

  private onCrown(event: CrownEvent): void {
    if (event.action === CrownAction.BEGIN) {
      this.crownAcc = 0;
      return;
    }
    if (event.action !== CrownAction.UPDATE) {
      return;
    }
    this.crownAcc += event.degree;
    if (this.crownAcc >= 45) {
      this.go(1);
    } else if (this.crownAcc <= -45) {
      this.go(-1);
    }
  }

  build() {
    Column() {
      Swiper(this.controller) {
        DevicePage({ active: this.current === 0 })
        SensorPage({ active: this.current === 1 })
        CompassPage({ active: this.current === 2 })
        OrientationPage({ active: this.current === 3 })
        SensorAuditPage({ active: this.current === 4, cityIndex: this.cityIndex })
        ToolsPage()
      }
      .index(this.current)
      .loop(false)
      .indicator(false)
      .onChange((index: number) => {
        this.current = index;
      })
      .width('100%')
      .layoutWeight(1)
      .focusable(false)

      Row({ space: 4 }) {
        Text('返回')
          .fontSize(8)
          .height(28)
          .width(36)
          .textAlign(TextAlign.Center)
          .backgroundColor('#1C1C1E')
          .borderRadius(14)
          .fontColor('#FF453A')
          .focusable(false)
          .onClick(() => this.onClose())
        Text('‹')
          .fontSize(18)
          .fontColor('#FF453A')
          .width(22)
          .height(28)
          .textAlign(TextAlign.Center)
          .focusable(false)
          .onClick(() => this.go(-1))
        Text(`${this.current + 1}/6`)
          .fontSize(8)
          .fontColor('#8E8E93')
          .width(22)
          .textAlign(TextAlign.Center)
        Text('›')
          .fontSize(18)
          .fontColor('#FF453A')
          .width(22)
          .height(28)
          .textAlign(TextAlign.Center)
          .focusable(false)
          .onClick(() => this.go(1))
        Text('退出')
          .fontSize(8)
          .height(28)
          .width(36)
          .textAlign(TextAlign.Center)
          .backgroundColor('#1C1C1E')
          .borderRadius(14)
          .fontColor('#8E8E93')
          .focusable(false)
          .onClick(() => this.onClose())
      }
      .width('100%')
      .height(28)
      .margin({ bottom: 28 })
      .justifyContent(FlexAlign.Center)
    }
    .id('diagRoot')
    .width('100%')
    .height('100%')
    .backgroundColor('#000000')
    .focusable(true)
    .defaultFocus(true)
    .onDigitalCrown((event: CrownEvent) => this.onCrown(event))
  }
}
