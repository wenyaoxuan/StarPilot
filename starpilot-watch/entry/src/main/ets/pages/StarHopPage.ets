import { audit } from '../common/AuditLog';
import { HOP_MAX_STEP, HOP_SEARCH_RADIUS, HopField, HopGeometry, HopLimit, HopPoint, HopSite,
  HopStar, defaultHopMagnitude, hopGeometry, makeHopField, planStarHop } from '../common/StarHopEngine';
import { Palette, palette } from '../common/Theme';
import { CITIES, City } from '../data/Cities';
import { MessierObject } from '../data/Messier';
import { asHopStar, hopStarMatches, isHopTarget, referenceHopStars } from '../data/StarHopCatalog';
import { findStaticTarget } from '../data/TargetCatalog';

const PRESETS: string[] = ['M31', 'M42', 'M45', 'M13', 'M57', 'M27'];
const PAGE_SIZE: number = 8;
const RAD: number = Math.PI / 180;

enum HopScreen {
  Targets,
  Start,
  Steps,
  Complete
}

@Component
export struct StarHopPage {
  @Prop targetId: string = '';
  @Prop redMode: boolean = false;
  @Prop englishNames: boolean = false;
  @Prop cityIndex: number = 0;
  @Prop bortle: number = 9;
  @Prop horizonMask: number[] = [];
  onClose: () => void = () => {};
  onBrowse: () => void = () => {};

  @State screen: HopScreen = HopScreen.Targets;
  @State magnitude: number = 2.5;
  @State candidates: HopPoint[] = [];
  @State shownCount: number = PAGE_SIZE;
  @State searchOpen: boolean = false;
  @State query: string = '';
  @State step: number = 0;
  @State errorText: string = '';
  @State route: HopPoint[] = [];
  private stars: HopStar[] = [];
  private target: HopStar | null = null;
  private field: HopField | null = null;
  private canvas: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    this.magnitude = defaultHopMagnitude(this.bortle);
    this.stars = referenceHopStars();
    if (this.targetId !== '') {
      this.pickTarget(this.targetId);
    }
  }

  private p(): Palette {
    return palette(this.redMode);
  }

  private name(star: HopStar): string {
    return this.englishNames ? star.nameEn : star.name;
  }

  private presetName(id: string): string {
    const entry: MessierObject | null = findStaticTarget(id);
    if (entry === null) {
      return id;
    }
    return id + ' · ' + this.name(asHopStar(entry));
  }

  private city(): City {
    return CITIES[this.cityIndex];
  }

  private site(): HopSite {
    return { lat: this.city().lat, lon: this.city().lon, horizon: this.horizonMask, bortle: this.bortle };
  }

  private changeScreen(screen: HopScreen): void {
    this.scroller.scrollTo({ xOffset: 0, yOffset: 0 });
    this.screen = screen;
  }

  private pickTarget(id: string): void {
    const entry: MessierObject | null = findStaticTarget(id);
    if (entry === null || entry.epoch !== 2000 || !isHopTarget(entry.category)) {
      this.errorText = '目标缺少可用的 J2000 坐标';
      return;
    }
    this.target = asHopStar(entry);
    this.searchOpen = false;
    this.query = '';
    this.refreshField();
    if (this.targetId === '') {
      this.changeScreen(HopScreen.Start);
    } else {
      this.screen = HopScreen.Start;
    }
  }

  private fieldMessage(field: HopField): string {
    switch (field.limit) {
      case HopLimit.TargetBelow:
        return '目标目前在地平线下';
      case HopLimit.TargetObstructed:
        return '目标低于该方向的地平遮挡';
      case HopLimit.TargetLow:
        return '目标高度低于 5°';
      case HopLimit.StarsTooFaint:
        return '附近没有符合极限星等的参考星';
      case HopLimit.StarsObstructed:
        return '附近亮星过低或被地平遮挡';
      default:
        return '';
    }
  }

  private refreshField(): void {
    if (this.target === null) {
      return;
    }
    this.field = makeHopField(this.target, this.stars, this.site(), this.magnitude, Date.now());
    this.errorText = this.fieldMessage(this.field);
    this.filterStarts();
  }

  private filterStarts(): void {
    if (this.field === null || this.field.limit !== HopLimit.Ready) {
      this.candidates = [];
      return;
    }
    const key: string = this.query.toLowerCase().replace(/\s/g, '');
    this.candidates = key === '' ? this.field.candidates :
      this.field.candidates.filter((point: HopPoint) => hopStarMatches(point.star, key));
    this.shownCount = PAGE_SIZE;
  }

  private adjustMagnitude(delta: number): void {
    this.magnitude = Math.max(1, Math.min(6, this.magnitude + delta));
    this.refreshField();
  }

  private plan(id: string): void {
    this.refreshField();
    if (this.field === null || this.field.limit !== HopLimit.Ready) {
      this.changeScreen(HopScreen.Start);
      return;
    }
    if (!this.field.candidates.some((point: HopPoint) => point.star.id === id)) {
      this.errorText = '当前起点已过低、被遮挡或超出极限星等';
      this.changeScreen(HopScreen.Start);
      return;
    }
    const started: number = Date.now();
    const route: HopPoint[] = planStarHop(this.field, id);
    audit('STAR_HOP', 'target=' + this.field.target.star.id + ';nodes=' + this.field.candidates.length +
      ';steps=' + Math.max(0, route.length - 1) + ';elapsedMs=' + (Date.now() - started));
    if (route.length < 2) {
      this.errorText = '每跳 ≤ ' + HOP_MAX_STEP + '° 时路线不连通，请换近些的起点或调整极限星等';
      this.changeScreen(HopScreen.Start);
      return;
    }
    this.route = route;
    this.step = 0;
    if (this.screen === HopScreen.Steps) {
      this.draw();
    } else {
      this.changeScreen(HopScreen.Steps);
    }
  }

  private backFromStart(): void {
    if (this.targetId !== '') {
      this.onClose();
    } else {
      this.errorText = '';
      this.changeScreen(HopScreen.Targets);
    }
  }

  private changeStep(delta: number): void {
    const next: number = this.step + delta;
    if (next === this.route.length - 1) {
      this.changeScreen(HopScreen.Complete);
    } else if (next >= 0) {
      this.step = next;
      this.draw();
    }
  }

  private geometry(): HopGeometry {
    return hopGeometry(this.route[this.step].star, this.route[this.step + 1].star);
  }

  private orientationText(): string {
    const g: HopGeometry = this.geometry();
    const angle: string = g.angle === null ? '—' : (Math.round(g.angle) % 360).toString() + '°';
    return '角距 ' + g.distance.toFixed(1) + '° · 位置角 ' + angle;
  }

  private nextAltAz(): string {
    const next: HopPoint = this.route[this.step + 1];
    return '下一点 高度 ' + Math.round(next.alt) + '° · 方位 ' + (Math.round(next.az) % 360) + '°';
  }

  private fieldText(): string {
    if (this.field === null) {
      return '';
    }
    const site: string = this.city().name + ' · Bortle ' + this.bortle;
    return this.field.sunAlt > -6 ? site + ' · 暮光/白天预演' : site;
  }

  private draw(): void {
    if (this.field === null || this.route.length < 2) {
      return;
    }
    const c: CanvasRenderingContext2D = this.canvas;
    const cx: number = c.width / 2;
    const cy: number = c.height / 2;
    const radius: number = Math.min(cx, cy) - 6;
    if (radius <= 0) {
      return;
    }
    const from: HopStar = this.route[this.step].star;
    const next: HopStar = this.route[this.step + 1].star;
    const geometry: HopGeometry = this.geometry();
    const scale: number = radius / Math.max(3, geometry.distance * 1.3);
    const p: Palette = this.p();
    c.clearRect(0, 0, c.width, c.height);
    c.strokeStyle = this.redMode ? '#69241D' : '#55555A';
    c.fillStyle = p.card;
    c.lineWidth = 1;
    c.beginPath();
    c.arc(cx, cy, radius, 0, 2 * Math.PI);
    c.fill();
    c.stroke();
    c.fillStyle = this.redMode ? '#B45044' : '#B4BBC6';
    for (const point of this.field.candidates) {
      if (point.star.id === from.id || point.star.id === next.id) {
        continue;
      }
      const g: HopGeometry = hopGeometry(from, point.star);
      if (g.angle !== null && g.distance * scale < radius - 2) {
        c.beginPath();
        c.arc(cx + g.distance * scale * Math.sin(g.angle * RAD),
          cy - g.distance * scale * Math.cos(g.angle * RAD), point.star.mag <= 2 ? 1.4 : 0.8, 0, 2 * Math.PI);
        c.fill();
      }
    }
    const angle: number = (geometry.angle ?? 0) * RAD;
    const x: number = cx + geometry.distance * scale * Math.sin(angle);
    const y: number = cy - geometry.distance * scale * Math.cos(angle);
    c.strokeStyle = p.accent;
    if (geometry.angle !== null) {
      c.setLineDash([3, 2]);
      c.beginPath();
      c.moveTo(cx, cy);
      c.lineTo(x, y);
      c.stroke();
      c.setLineDash([]);
    }
    c.fillStyle = p.fg;
    c.beginPath();
    c.arc(cx, cy, 2, 0, 2 * Math.PI);
    c.fill();
    if (geometry.angle !== null || geometry.distance < 0.02) {
      if (this.step + 1 === this.route.length - 1) {
        c.strokeRect(x - 4, y - 4, 8, 8);
      } else {
        c.beginPath();
        c.arc(x, y, 4, 0, 2 * Math.PI);
        c.stroke();
      }
    }
    c.font = '11px sans-serif';
    c.fillText('N', cx - 3, 11);
    c.fillText('E', cx + radius + 5, cy + 3);
  }

  @Builder
  Header(title: string, back: () => void, actionLabel: string = '', action: () => void = () => {}) {
    Row() {
      Button('返回').fontSize(9).height(24).width(42).padding(0)
        .fontColor(this.p().accent).backgroundColor(this.p().card).onClick(back)
      Text(title).fontSize(11).fontColor(this.p().accent).layoutWeight(1).textAlign(TextAlign.Center)
      if (actionLabel !== '') {
        Button(actionLabel).fontSize(9).height(24).width(42).padding(0)
          .fontColor(this.p().accent).backgroundColor(this.p().card).onClick(action)
      } else {
        Blank().width(42)
      }
    }.width('100%')
  }

  @Builder
  Action(label: string, action: () => void, accent: boolean = false) {
    Button(label).fontSize(9).height(25).padding(0).layoutWeight(1)
      .backgroundColor(accent ? this.p().accent : this.p().card)
      .fontColor(accent ? '#000000' : this.p().fg).onClick(action)
  }

  @Builder
  TargetList() {
    this.Header('选择星桥目标', this.onClose)
    Text('手动星桥 · 选择深空目标').fontSize(9).fontColor(this.p().fg)
    ForEach(PRESETS, (id: string) => {
      Button(this.presetName(id)).height(29).width('100%').padding({ left: 9, right: 9 })
        .fontSize(10).fontColor(this.p().fg).backgroundColor(this.p().card)
        .onClick(() => this.pickTarget(id))
    }, (id: string) => id)
    Row() {
      this.Action('天体目录 · 更多目标', this.onBrowse)
    }.width('100%')
    if (this.errorText !== '') {
      Text(this.errorText).fontSize(9).fontColor(this.p().accent)
    }
  }

  @Builder
  StartList() {
    this.Header('选择起点亮星', () => this.backFromStart(), '刷新', () => this.refreshField())
    if (this.target !== null) {
      Text(this.target.id + ' · ' + this.name(this.target)).fontSize(12).fontColor(this.p().fg)
        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    Text(this.fieldText()).fontSize(9).fontColor(this.p().fg)
    Row({ space: 4 }) {
      this.Action('−0.5', () => this.adjustMagnitude(-0.5))
      Text('极限 ' + this.magnitude.toFixed(1) + ' 等').fontSize(9).fontColor(this.p().fg)
        .layoutWeight(1.6).textAlign(TextAlign.Center)
      this.Action('+0.5', () => this.adjustMagnitude(0.5))
      Button(this.searchOpen ? '收起' : '搜索').fontSize(9).height(25).padding(0).layoutWeight(1)
        .backgroundColor(this.p().card).fontColor(this.p().fg).onClick(() => {
          this.searchOpen = !this.searchOpen;
          if (!this.searchOpen) {
            this.query = '';
            this.filterStarts();
          }
        })
    }.width('100%')
    if (this.searchOpen) {
      TextInput({ placeholder: '亮星名、星座或 HIP', text: this.query })
        .maxLength(40).height(29).width('100%').fontSize(9)
        .fontColor(this.p().fg).placeholderColor(this.p().fg).backgroundColor(this.p().card)
        .onChange((value: string) => { this.query = value; this.filterStarts(); })
    }
    if (this.errorText !== '') {
      Text(this.errorText).fontSize(9).fontColor(this.p().accent).textAlign(TextAlign.Center)
    } else if (this.candidates.length === 0) {
      Text('没有匹配且满足条件的起点').fontSize(9).fontColor(this.p().accent)
    }
    ForEach(this.candidates.slice(0, this.shownCount), (point: HopPoint) => {
      Row({ space: 4 }) {
        Text(this.name(point.star)).fontSize(10).fontColor(this.p().fg).maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
        Text(point.star.mag.toFixed(1) + ' 等 · 距 ' + point.distanceToTarget.toFixed(0) + '°')
          .fontSize(8).fontColor(this.p().fg)
      }.height(28).width('100%').padding({ left: 9, right: 9 }).borderRadius(12)
        .backgroundColor(this.p().card).onClick(() => this.plan(point.star.id))
    }, (point: HopPoint) => point.star.id)
    if (this.candidates.length > this.shownCount) {
      Row() {
        this.Action('更多起点', () => { this.shownCount += PAGE_SIZE; })
      }.width('100%')
    }
    Text('搜索目标周围 ' + HOP_SEARCH_RADIUS + '° · 星等为规划参考')
      .fontSize(8).fontColor(this.p().fg)
  }

  @Builder
  Steps() {
    this.Header('手动星桥', () => { this.refreshField(); this.changeScreen(HopScreen.Start); }, '重规划',
      () => this.plan(this.route[this.step].star.id))
    Text('第 ' + (this.step + 1) + ' / ' + (this.route.length - 1) + ' 跳 · ' +
      this.route[this.route.length - 1].star.id).fontSize(9).fontColor(this.p().accent)
    Text(this.name(this.route[this.step].star) + ' → ' + this.name(this.route[this.step + 1].star))
      .fontSize(11).fontColor(this.p().fg).maxLines(2).textAlign(TextAlign.Center)
    Canvas(this.canvas).width('100%').height(70).onReady(() => this.draw())
    Text(this.orientationText()).fontSize(9).fontColor(this.p().fg)
    Text('上北右东 · 位置角从天球北向东').fontSize(8).fontColor(this.p().fg)
    Text(this.nextAltAz()).fontSize(9).fontColor(this.p().fg)
    Row({ space: 5 }) {
      if (this.step > 0) {
        this.Action('上一步', () => this.changeStep(-1))
      }
      Button(this.step + 2 === this.route.length ? '确认最后一跳' : '确认下一星')
        .fontSize(9).height(25).padding(0).layoutWeight(1)
        .backgroundColor(this.p().accent).fontColor('#000000').onClick(() => this.changeStep(1))
    }.width('100%')
    if (this.field !== null) {
      Text('高度/方位为规划时刻 · 重新规划可更新').fontSize(8).fontColor(this.p().fg)
      if (this.field.sunAlt > -6) {
        Text('暮光/白天 · 仅预演').fontSize(8).fontColor(this.p().accent)
      }
    }
  }

  @Builder
  Complete() {
    this.Header('最后一跳已确认', () => this.changeScreen(HopScreen.Steps))
    if (this.target !== null) {
      Text(this.target.id + ' · ' + this.name(this.target)).fontSize(13).fontColor(this.p().fg)
    }
    Text('按最后一步星图核对目标位置').fontSize(9).fontColor(this.p().fg)
    Row({ space: 5 }) {
      this.Action('查看最后一步', () => this.changeScreen(HopScreen.Steps))
      this.Action('结束', this.onClose, true)
    }.width('100%')
  }

  build() {
    Scroll(this.scroller) {
      Column({ space: 4 }) {
        if (this.screen === HopScreen.Steps) {
          this.Steps()
        } else if (this.screen === HopScreen.Complete) {
          this.Complete()
        } else if (this.screen === HopScreen.Start) {
          this.StartList()
        } else {
          this.TargetList()
        }
      }.width('100%').padding({ left: 33, right: 33, top: 26, bottom: 25 })
    }.width('100%').height('100%').backgroundColor(this.p().bg).scrollBar(BarState.Off)
  }
}
