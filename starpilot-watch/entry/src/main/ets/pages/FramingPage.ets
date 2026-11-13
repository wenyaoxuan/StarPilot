import { Equatorial } from '../common/Astro';
import { FramingFrame, FramePoint, angularRadiusOnPlane, offsetFrameCenter } from '../common/FramingEngine';
import { A7R4 } from '../common/Photo';
import { Palette, palette } from '../common/Theme';
import { CONSTELLATION_STARS } from '../data/Constellations';
import { MessierObject } from '../data/Messier';
import { findStaticTarget, targetDisplayName } from '../data/TargetCatalog';

const SHORT_FOCALS: number[] = [20, 35, 50, 85];
const LONG_FOCALS: number[] = [100, 135, 200];

enum FramingScreen {
  Setup,
  Preview,
  Adjust,
  Number
}

@Component
export struct FramingPage {
  @Prop targetId: string = '';
  @Prop redMode: boolean = false;
  @Prop englishNames: boolean = false;
  onClose: () => void = () => {};

  @State screen: FramingScreen = FramingScreen.Setup;
  @State focal: number = 85;
  @State widthMm: number = A7R4.sensorW;
  @State heightMm: number = A7R4.sensorH;
  @State customSensor: boolean = false;
  @State portrait: boolean = false;
  @State rotation: number = 0;
  @State center: Equatorial = { raHours: 0, decDeg: 0 };
  @State field: string = '';
  @State digits: string = '';
  private target: MessierObject | null = null;
  private canvas: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));

  aboutToAppear(): void {
    this.target = findStaticTarget(this.targetId);
    this.resetCenter();
  }

  private p(): Palette {
    return palette(this.redMode);
  }

  private targetName(): string {
    const o: MessierObject | null = this.target;
    return o === null ? '目标不可用' : targetDisplayName(o.id, o.name, o.nameEn, this.englishNames);
  }

  private sensorWidth(): number {
    return this.customSensor ? this.widthMm : A7R4.sensorW;
  }

  private sensorHeight(): number {
    return this.customSensor ? this.heightMm : A7R4.sensorH;
  }

  private frameWidth(): number {
    return this.portrait ? this.sensorHeight() : this.sensorWidth();
  }

  private frameHeight(): number {
    return this.portrait ? this.sensorWidth() : this.sensorHeight();
  }

  private frame(): FramingFrame {
    return new FramingFrame(this.center, this.frameWidth(), this.frameHeight(), this.focal, this.rotation);
  }

  private resetCenter(): void {
    if (this.target !== null) {
      this.center = { raHours: this.target.raHours, decDeg: this.target.decDeg };
    }
  }

  private rotateFrame(delta: number): void {
    this.rotation = (this.rotation + delta + 360) % 360;
  }

  private pan(x: number, y: number): void {
    this.center = this.frame().move(x, y);
  }

  private openNumber(field: string): void {
    this.field = field;
    this.digits = '';
    this.screen = FramingScreen.Number;
  }

  private numberLimit(): number {
    return this.field === '焦距' ? 3000 : 100;
  }

  private inputKey(key: string): void {
    if (key === '退格') {
      this.digits = this.digits.slice(0, -1);
    } else if (key === '.') {
      if (!this.digits.includes('.')) {
        this.digits += this.digits === '' ? '0.' : '.';
      }
    } else if (this.digits.length < 7) {
      this.digits += key;
    }
  }

  private saveNumber(): void {
    const value: number = Number(this.digits);
    if (this.field === '焦距') {
      this.focal = value;
    } else if (this.field === '传感器宽') {
      this.widthMm = value;
    } else {
      this.heightMm = value;
    }
    this.screen = FramingScreen.Setup;
  }

  private sizeNote(): string {
    const target: MessierObject | null = this.target;
    if (target === null || !target.sizeKnown || target.sizeA <= 0) {
      return '角尺寸未知 · 只标中心';
    }
    const size: string = target.sizeB > 0 && target.sizeA !== target.sizeB ?
      target.sizeA.toString() + '′ × ' + target.sizeB.toString() + '′' : target.sizeA.toString() + '′';
    return size + ' · 位置角未知';
  }

  private targetPosition(): string {
    if (this.target === null) {
      return '';
    }
    const point: FramePoint | null = this.frame().project({
      raHours: this.target.raHours, decDeg: this.target.decDeg
    });
    return point !== null && point.inside ? '目标中心在画幅内' : '目标中心已出框';
  }

  private drawRing(frame: FramingFrame, target: Equatorial, diameter: number, halfW: number,
                   halfH: number, cx: number, cy: number): void {
    if (diameter <= 0 || diameter >= 10800) {
      return;
    }
    const radius: number = angularRadiusOnPlane(diameter);
    const c: CanvasRenderingContext2D = this.canvas;
    let started: boolean = false;
    c.beginPath();
    for (let i = 0; i <= 36; i++) {
      const angle: number = i * Math.PI / 18;
      const sky: Equatorial = offsetFrameCenter(target, radius * Math.cos(angle), radius * Math.sin(angle));
      const point: FramePoint | null = frame.project(sky);
      if (point === null) {
        started = false;
      } else if (started) {
        c.lineTo(cx + point.x * halfW, cy - point.y * halfH);
      } else {
        c.moveTo(cx + point.x * halfW, cy - point.y * halfH);
        started = true;
      }
    }
    c.stroke();
  }

  private draw(): void {
    const c: CanvasRenderingContext2D = this.canvas;
    const target: MessierObject | null = this.target;
    const w: number = c.width;
    const h: number = c.height;
    if (target === null || w <= 10 || h <= 8) {
      return;
    }
    const frame: FramingFrame = this.frame();
    const ratio: number = this.frameWidth() / this.frameHeight();
    const width: number = Math.min(w - 10, (h - 8) * ratio);
    const height: number = width / ratio;
    const cx: number = w / 2;
    const cy: number = h / 2;
    const left: number = cx - width / 2;
    const top: number = cy - height / 2;
    c.clearRect(0, 0, w, h);
    c.fillStyle = this.p().card;
    c.fillRect(left, top, width, height);
    c.save();
    c.beginPath();
    c.rect(left, top, width, height);
    c.clip();
    c.fillStyle = this.redMode ? '#C0645C' : '#C6CCD3';
    for (const star of CONSTELLATION_STARS) {
      const p: FramePoint | null = frame.project({ raHours: star.raHours, decDeg: star.decDeg });
      if (p !== null && p.inside) {
        c.beginPath();
        c.arc(cx + p.x * width / 2, cy - p.y * height / 2, star.mag < 2 ? 1.7 : 0.8, 0, Math.PI * 2);
        c.fill();
      }
    }
    c.strokeStyle = this.p().accent;
    c.lineWidth = 1;
    const targetCenter: Equatorial = { raHours: target.raHours, decDeg: target.decDeg };
    if (target.sizeKnown && target.sizeA > 0) {
      c.setLineDash([2, 2]);
      this.drawRing(frame, targetCenter, target.sizeA, width / 2, height / 2, cx, cy);
      if (target.sizeB !== target.sizeA) {
        this.drawRing(frame, targetCenter, target.sizeB, width / 2, height / 2, cx, cy);
      }
      c.setLineDash([]);
    }
    const point: FramePoint | null = frame.project(targetCenter);
    if (point !== null && point.inside) {
      const x: number = cx + point.x * width / 2;
      const y: number = cy - point.y * height / 2;
      c.beginPath();
      c.moveTo(x - 3, y);
      c.lineTo(x + 3, y);
      c.moveTo(x, y - 3);
      c.lineTo(x, y + 3);
      c.stroke();
    }
    c.restore();
    c.strokeStyle = this.p().accent;
    c.strokeRect(left, top, width, height);
  }

  @Builder
  Key(label: string, action: () => void, selected: () => boolean = () => false) {
    Button(label)
      .fontSize(10).height(25).padding(0).layoutWeight(1)
      .backgroundColor(selected() ? this.p().accent : this.p().card)
      .fontColor(selected() ? '#000000' : this.p().fg)
      .onClick(action)
  }

  @Builder
  Caption(value: () => string) {
    Text(value()).fontSize(9).fontColor(this.p().fg).textAlign(TextAlign.Center)
  }

  @Builder
  Header(label: string, back: () => void, actionLabel: string = '', action: () => void = () => {}) {
    Row({ space: 5 }) {
      Button('返回').fontSize(9).height(24).width(41).padding(0)
        .fontColor(this.p().accent).backgroundColor(this.p().card).onClick(back)
      Text(label).fontSize(11).fontColor(this.p().accent).textAlign(TextAlign.Center).layoutWeight(1)
      if (actionLabel !== '') {
        Button(actionLabel).fontSize(8).height(24).width(43).padding(0)
          .fontColor(this.p().accent).backgroundColor(this.p().card).onClick(action)
      } else {
        Blank().width(41)
      }
    }.width('100%')
  }

  @Builder
  Setup() {
    this.Header('取景设置', this.onClose)
    Text(this.targetName()).fontSize(13).fontColor(this.p().fg).maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
    Row({ space: 4 }) {
      this.Key('A7R IV', () => { this.customSensor = false; }, () => !this.customSensor)
      this.Key('自定义画幅', () => { this.customSensor = true; }, () => this.customSensor)
    }.width('100%')
    if (this.customSensor) {
      Row({ space: 4 }) {
        this.Key('宽 ' + this.widthMm, () => this.openNumber('传感器宽'))
        this.Key('高 ' + this.heightMm, () => this.openNumber('传感器高'))
      }.width('100%')
    } else {
      this.Caption(() => '全画幅 35.7 × 23.8 mm')
    }
    this.Caption(() => '焦距 ' + this.focal + ' mm')
    Row({ space: 4 }) {
      ForEach(SHORT_FOCALS, (n: number) => {
        this.Key(n.toString(), () => { this.focal = n; }, () => this.focal === n)
      }, (n: number) => n.toString())
    }.width('100%')
    Row({ space: 4 }) {
      ForEach(LONG_FOCALS, (n: number) => {
        this.Key(n.toString(), () => { this.focal = n; }, () => this.focal === n)
      }, (n: number) => n.toString())
      this.Key('自定义', () => this.openNumber('焦距'))
    }.width('100%')
    Button('预览画幅').fontSize(10).height(27).width('100%')
      .backgroundColor(this.p().accent).fontColor('#000000').enabled(this.target !== null)
      .onClick(() => { this.screen = FramingScreen.Preview; })
  }

  @Builder
  Preview() {
    this.Header('画幅预览', () => { this.screen = FramingScreen.Setup; }, '构图',
      () => { this.screen = FramingScreen.Adjust; })
    Text(this.targetName() + ' · ' + this.focal + ' mm').fontSize(10)
      .fontColor(this.p().fg).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
    Canvas(this.canvas).width('100%').height(92).onReady(() => this.draw())
    this.Caption(() => this.frame().widthDeg.toFixed(2) + '° × ' + this.frame().heightDeg.toFixed(2) + '°')
    Text(this.targetPosition()).fontSize(9).fontColor(this.p().accent)
    this.Caption(() => this.sizeNote())
    Text(this.frame().widthDeg > 120 || this.frame().heightDeg > 120 ?
      '广角畸变未模拟' : this.target !== null && this.target.sizeKnown && this.target.sizeA > 0 ?
      '尺寸参考环 · 亮度未模拟' : '几何预览 · 亮度未模拟')
      .fontSize(8).fontColor(this.p().dim).textAlign(TextAlign.Center)
  }

  @Builder
  Adjust() {
    this.Header('构图调整', () => { this.screen = FramingScreen.Preview; })
    Row({ space: 4 }) {
      this.Key('横幅', () => { this.portrait = false; }, () => !this.portrait)
      this.Key('竖幅', () => { this.portrait = true; }, () => this.portrait)
    }.width('100%')
    this.Caption(() => '旋转 ' + this.rotation + '° · 北向东计')
    Row({ space: 4 }) {
      this.Key('−15°', () => this.rotateFrame(-15))
      this.Key('+15°', () => this.rotateFrame(15))
    }.width('100%')
    this.Caption(() => '移动画面中心 · 每步四分之一画幅')
    Row({ space: 4 }) {
      this.Key('左', () => this.pan(-0.5, 0))
      this.Key('右', () => this.pan(0.5, 0))
      this.Key('上', () => this.pan(0, 0.5))
      this.Key('下', () => this.pan(0, -0.5))
    }.width('100%')
    this.Caption(() => 'RA ' + this.center.raHours.toFixed(3) + 'h · Dec ' + this.center.decDeg.toFixed(2) + '°')
    Row({ space: 4 }) {
      this.Key('回到目标', () => this.resetCenter())
      this.Key('查看画幅', () => { this.screen = FramingScreen.Preview; })
    }.width('100%')
  }

  @Builder
  NumberRow(keys: string[]) {
    Row({ space: 4 }) {
      ForEach(keys, (key: string) => { this.Key(key, () => this.inputKey(key)) }, (key: string) => key)
    }.width('100%')
  }

  @Builder
  NumberEditor() {
    this.Header(this.field, () => { this.screen = FramingScreen.Setup; })
    Text(this.digits === '' ? '输入数值' : this.digits).fontSize(16).fontColor(this.p().fg)
    this.Caption(() => '1–' + this.numberLimit() + ' mm')
    this.NumberRow(['1', '2', '3', '4'])
    this.NumberRow(['5', '6', '7', '8'])
    this.NumberRow(['9', '0', '.', '退格'])
    Button('确定').fontSize(10).height(25).width('100%')
      .backgroundColor(this.p().accent).fontColor('#000000')
      .enabled(Number(this.digits) >= 1 && Number(this.digits) <= this.numberLimit())
      .onClick(() => this.saveNumber())
  }

  build() {
    Scroll() {
      Column({ space: 4 }) {
        if (this.screen === FramingScreen.Preview) {
          this.Preview()
        } else if (this.screen === FramingScreen.Adjust) {
          this.Adjust()
        } else if (this.screen === FramingScreen.Number) {
          this.NumberEditor()
        } else {
          this.Setup()
        }
      }.width('100%').padding({ left: 32, right: 32, top: 26, bottom: 22 })
    }.width('100%').height('100%').backgroundColor(this.p().bg).scrollBar(BarState.Off)
  }
}
