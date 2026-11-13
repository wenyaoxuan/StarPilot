import { MessierObject, decText, raText } from '../data/Messier';
import { STATIC_TARGETS, anchorSearchNames, targetDisplayName } from '../data/TargetCatalog';
import { palette, Palette } from '../common/Theme';
import {
  Equatorial,
  Horizontal,
  VisibleWindow,
  horizonMaskAt,
  jdFromUnixMs,
  longestWindow,
  sunAltitude,
  targetHorizontal,
  targetVisibleWindows
} from '../common/Astro';
import {
  SOLAR_BODIES,
  SolarBody,
  SolarPosition,
  isSolarId,
  solarHorizontal,
  solarPosition,
  solarVisibleWindows
} from '../common/SolarSystem';
import { CITIES, City } from '../data/Cities';

function makeSolarTarget(b: SolarBody): MessierObject {
  return {
    id: b.id,
    name: b.name,
    nameEn: b.nameEn,
    aliases: b.aliases,
    type: b.type,
    category: 'solar',
    raHours: 0,
    decDeg: 0,
    epoch: 2000.0,
    mag: 99,
    magKnown: false,
    sizeA: 0,
    sizeB: 0,
    sizeKnown: false,
    surfaceBrightness: 0,
    distanceLy: 0,
    fl: '',
    season: '',
    desc: b.desc,
    source: 'SolarSystem.ets（历算）'
  };
}

function buildSolarTargets(): MessierObject[] {
  const out: MessierObject[] = [];
  for (let i = 0; i < SOLAR_BODIES.length; i++) {
    out.push(makeSolarTarget(SOLAR_BODIES[i]));
  }
  return out;
}

const ALL_TARGETS: MessierObject[] = STATIC_TARGETS.concat(buildSolarTargets());

interface CatalogRow {
  obj: MessierObject;
  altDeg: number;
  status: string;
  catIndex: number;
}

class CatalogDataSource implements IDataSource {
  private data: CatalogRow[] = [];
  private listeners: DataChangeListener[] = [];

  constructor(data: CatalogRow[]) {
    this.data = data;
  }

  totalCount(): number {
    return this.data.length;
  }

  getData(index: number): CatalogRow {
    return this.data[index];
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener);
    }
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const i: number = this.listeners.indexOf(listener);
    if (i >= 0) {
      this.listeners.splice(i, 1);
    }
  }

  setData(data: CatalogRow[]): void {
    this.data = data;
    for (let i = 0; i < this.listeners.length; i++) {
      this.listeners[i].onDataReloaded();
    }
  }
}

@Component
export struct TargetsPage {
  @Prop @Watch('onContextChanged') active: boolean = false;
  @Prop redMode: boolean = false;
  @Prop englishNames: boolean = false;
  @Prop @Watch('onContextChanged') cityIndex: number = 0;
  @Prop @Watch('onContextChanged') horizonMask: number[] = [];
  @Prop @Watch('onCrownStep') crownStep: number = 0;
  onNavigate: (id: string) => void = () => {
  };
  onToggleNames: () => void = () => {};
  onFrame: (id: string) => void = () => {};
  onStarHop: (id: string) => void = () => {};

  @State selected: number = -1;
  @State query: string = '';
  @State searchOpen: boolean = false;
  @State categoryKey: string = 'all';
  @State visibleOnly: boolean = false;
  @State shownCount: number = 0;
  @State windowText: string = '';

  private source: CatalogDataSource = new CatalogDataSource([]);
  private searchBlobs: string[] = [];
  private altArr: number[] = [];
  private statusArr: string[] = [];
  private timerId: number = -1;
  private lastCrownStep: number = 0;
  private listScroller: Scroller = new Scroller();
  private detailScroller: Scroller = new Scroller();

  private p(): Palette {
    return palette(this.redMode);
  }

  private onCrownStep(): void {
    const delta: number = this.crownStep - this.lastCrownStep;
    this.lastCrownStep = this.crownStep;
    if (delta === 0) {
      return;
    }
    const dy: number = delta * 42;
    if (this.selected < 0) {
      this.listScroller.scrollBy(0, dy);
    } else {
      this.detailScroller.scrollBy(0, dy);
    }
  }

  aboutToAppear(): void {
    this.buildSearchBlobs();
    this.computeStatuses();
    this.applyFilter();
    this.timerId = setInterval(() => {
      if (this.active) {
        this.computeStatuses();
        this.applyFilter();
        if (this.selected >= 0) {
          this.computeWindow(this.selected);
        }
      }
    }, 60000);
  }

  aboutToDisappear(): void {
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
    }
  }

  onContextChanged(): void {
    if (this.active) {
      this.computeStatuses();
      this.applyFilter();
    }
    if (this.selected >= 0) {
      this.computeWindow(this.selected);
    }
  }

  private buildSearchBlobs(): void {
    const out: string[] = [];
    for (let i = 0; i < ALL_TARGETS.length; i++) {
      const o: MessierObject = ALL_TARGETS[i];
      let s: string = `${o.id} ${o.name} ${o.nameEn} ${o.type}`;
      for (let j = 0; j < o.aliases.length; j++) {
        s += ` ${o.aliases[j]}`;
      }
      s += ' ' + anchorSearchNames(o.id).join(' ');
      out.push(s.toLowerCase());
    }
    this.searchBlobs = out;
  }

  private searchTokens(): string[] {
    let q: string = this.query.trim().toLowerCase();
    q = q.replace(/([a-z]+)\s+(\d+)/g, '$1$2');
    const raw: string[] = q.split(' ');
    const out: string[] = [];
    for (let i = 0; i < raw.length; i++) {
      if (raw[i] !== '') {
        out.push(raw[i]);
      }
    }
    return out;
  }

  private hasExactToken(blob: string, tok: string): boolean {
    return ` ${blob} `.indexOf(` ${tok} `) >= 0;
  }

  private computeStatuses(): void {
    if (this.cityIndex < 0 || this.cityIndex >= CITIES.length) {
      return;
    }
    const city: City = CITIES[this.cityIndex];
    const jd: number = jdFromUnixMs(Date.now());
    const sunAlt: number = sunAltitude(jd, city.lat, city.lon);
    const alts: number[] = [];
    const states: string[] = [];
    for (let i = 0; i < ALL_TARGETS.length; i++) {
      const o: MessierObject = ALL_TARGETS[i];
      let h: Horizontal;
      if (isSolarId(o.id)) {
        const sh: Horizontal | null = solarHorizontal(o.id, jd, city.lat, city.lon);
        h = sh === null ? { azDeg: 0, altDeg: -90 } : sh;
      } else {
        const eq: Equatorial = { raHours: o.raHours, decDeg: o.decDeg };
        h = targetHorizontal(eq, jd, city.lat, city.lon);
      }
      let s: string = '';
      if (o.id === 'SUN') {
        if (h.altDeg < 0) {
          s = '已落';
        } else if (h.altDeg < horizonMaskAt(this.horizonMask, h.azDeg)) {
          s = '遮挡';
        } else {
          s = '可见';
        }
      } else if (sunAlt > -18) {
        s = '白天';
      } else if (h.altDeg < 0) {
        s = '已落';
      } else if (h.altDeg < horizonMaskAt(this.horizonMask, h.azDeg)) {
        s = '遮挡';
      } else {
        s = '可拍';
      }
      alts.push(h.altDeg);
      states.push(s);
    }
    this.altArr = alts;
    this.statusArr = states;
  }

  private applyFilter(): void {
    const toks: string[] = this.searchTokens();
    const rows: CatalogRow[] = [];
    for (let i = 0; i < ALL_TARGETS.length; i++) {
      const o: MessierObject = ALL_TARGETS[i];
      if (this.categoryKey !== 'all' && o.category !== this.categoryKey) {
        continue;
      }
      const st: string = i < this.statusArr.length ? this.statusArr[i] : '';
      if (this.visibleOnly && st !== '可拍') {
        continue;
      }
      let ok: boolean = true;
      const blob: string = i < this.searchBlobs.length ? this.searchBlobs[i] : '';
      for (let j = 0; j < toks.length; j++) {
        const tok: string = toks[j];
        const isId: boolean = /^(m|c|ngc|ic|hip|hr|hyg|mel)\d+$/.test(tok);
        const hit: boolean = isId ? this.hasExactToken(blob, tok) : blob.indexOf(tok) >= 0;
        if (!hit) {
          ok = false;
          break;
        }
      }
      if (!ok) {
        continue;
      }
      const row: CatalogRow = {
        obj: o,
        altDeg: i < this.altArr.length ? this.altArr[i] : 0,
        status: st,
        catIndex: i
      };
      rows.push(row);
    }
    this.shownCount = rows.length;
    this.source.setData(rows);
  }

  private fmt(ms: number): string {
    const d: Date = new Date(ms);
    return `${d.getHours()}:${d.getMinutes() < 10 ? '0' : ''}${d.getMinutes()}`;
  }

  private computeWindow(index: number): void {
    const o: MessierObject = ALL_TARGETS[index];
    const city: City = CITIES[this.cityIndex];
    const now: Date = new Date();
    const midnight: number = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
    let wins: VisibleWindow[];
    if (isSolarId(o.id)) {
      wins = solarVisibleWindows(o.id, midnight, city.lat, city.lon, this.horizonMask, 10);
    } else {
      const eq: Equatorial = { raHours: o.raHours, decDeg: o.decDeg };
      wins = targetVisibleWindows(eq, midnight, city.lat, city.lon, this.horizonMask, 10);
    }
    const best: VisibleWindow | null = longestWindow(wins);
    if (best === null) {
      this.windowText = '当前无可见窗口（遮挡/天光）';
      return;
    }
    const hours: number = (best.endMs - best.startMs) / 3600000;
    this.windowText = `可见 ${this.fmt(best.startMs)}–${this.fmt(best.endMs)} · ${hours.toFixed(1)}h · 最高 ${best.peakAltDeg.toFixed(0)}°`;
  }

  private altText(alt: number): string {
    return `${alt >= 0 ? '+' : ''}${alt.toFixed(0)}°`;
  }

  private statusColor(status: string): string {
    return status === '可拍' ? this.p().accent : this.p().dim;
  }

  private categoryLabel(cat: string): string {
    if (cat === 'nebula') {
      return '星云';
    }
    if (cat === 'galaxy') {
      return '星系';
    }
    if (cat === 'cluster') {
      return '星团';
    }
    if (cat === 'star') {
      return '恒星';
    }
    if (cat === 'double') {
      return '双星';
    }
    if (cat === 'variable') {
      return '变星';
    }
    if (cat === 'solar') {
      return '太阳系';
    }
    return '天体';
  }

  private solarPos(o: MessierObject): SolarPosition | null {
    if (this.cityIndex < 0 || this.cityIndex >= CITIES.length) {
      return null;
    }
    const city: City = CITIES[this.cityIndex];
    return solarPosition(o.id, jdFromUnixMs(Date.now()), city.lat, city.lon);
  }

  private fmtRa(raHours: number): string {
    const h: number = Math.floor(raHours);
    let m: number = Math.round((raHours - h) * 60);
    if (m === 60) {
      m = 0;
    }
    return `${h}h ${m < 10 ? '0' : ''}${m}m`;
  }

  private fmtDec(decDeg: number): string {
    const sign: string = decDeg >= 0 ? '+' : '-';
    const abs: number = Math.abs(decDeg);
    const d: number = Math.floor(abs);
    const m: number = Math.round((abs - d) * 60);
    return `${sign}${d}° ${m < 10 ? '0' : ''}${m}′`;
  }

  private raTextFor(o: MessierObject): string {
    if (isSolarId(o.id)) {
      const p: SolarPosition | null = this.solarPos(o);
      return p === null ? '—' : this.fmtRa(p.raHours);
    }
    return raText(o);
  }

  private decTextFor(o: MessierObject): string {
    if (isSolarId(o.id)) {
      const p: SolarPosition | null = this.solarPos(o);
      return p === null ? '—' : this.fmtDec(p.decDeg);
    }
    return decText(o);
  }

  private magText(o: MessierObject): string {
    if (isSolarId(o.id)) {
      const p: SolarPosition | null = this.solarPos(o);
      return p !== null && p.magKnown ? `约 m${p.magnitude.toFixed(1)}` : '—';
    }
    return o.magKnown ? `m${o.mag.toFixed(1)}` : '未收录';
  }

  private sizeText(o: MessierObject): string {
    if (isSolarId(o.id)) {
      const p: SolarPosition | null = this.solarPos(o);
      return p === null ? '—' : `${p.angularSizeArcmin.toFixed(1)}′`;
    }
    if (!o.sizeKnown || o.sizeA <= 0) {
      return '未收录';
    }
    const b: number = o.sizeB > 0 ? o.sizeB : o.sizeA;
    return `${o.sizeA.toFixed(1)}′ × ${b.toFixed(1)}′`;
  }

  private flText(o: MessierObject): string {
    if (isSolarId(o.id)) {
      const p: SolarPosition | null = this.solarPos(o);
      if (p === null) {
        return '—';
      }
      const s: number = p.angularSizeArcmin;
      if (s >= 60) {
        return '135–300mm';
      }
      if (s >= 20) {
        return '300–600mm';
      }
      if (s >= 5) {
        return '600–1200mm';
      }
      return '1200–2000mm';
    }
    return o.fl !== '' ? o.fl : '—';
  }

  private sbText(o: MessierObject): string {
    if (isSolarId(o.id)) {
      return '—';
    }
    return o.surfaceBrightness > 0 ? `${o.surfaceBrightness.toFixed(1)} mag/arcsec²` : '—';
  }

  private distText(o: MessierObject): string {
    if (isSolarId(o.id)) {
      const p: SolarPosition | null = this.solarPos(o);
      if (p === null) {
        return '—';
      }
      if (o.id === 'MOON') {
        return `${Math.round(p.distanceKm)} km`;
      }
      return `${p.distanceAu.toFixed(2)} AU`;
    }
    if (o.distanceLy <= 0) {
      return '—';
    }
    if (o.distanceLy >= 1000000) {
      return `${(o.distanceLy / 1000000).toFixed(1)} Mly`;
    }
    if (o.distanceLy >= 1000) {
      return `${(o.distanceLy / 1000).toFixed(1)} kly`;
    }
    return `${o.distanceLy.toFixed(0)} ly`;
  }

  private phaseText(o: MessierObject): string {
    if (!isSolarId(o.id)) {
      return '—';
    }
    const p: SolarPosition | null = this.solarPos(o);
    if (p === null) {
      return '—';
    }
    const pct: string = `${(p.illumination * 100).toFixed(0)}%`;
    return p.phaseName !== '' ? `${pct} ${p.phaseName}` : pct;
  }

  private epochText(o: MessierObject): string {
    return isSolarId(o.id) ? '实时' : 'J2000.0';
  }

  private aliasText(o: MessierObject): string {
    const out: string[] = [];
    for (let i = 0; i < o.aliases.length; i++) {
      const a: string = o.aliases[i];
      if (a === o.id || a === o.name || a === o.nameEn) {
        continue;
      }
      if (out.indexOf(a) < 0) {
        out.push(a);
      }
      if (out.length >= 6) {
        break;
      }
    }
    return out.length > 0 ? out.join(' · ') : '—';
  }

  @Builder
  SearchChip() {
    Text('搜索')
      .fontSize(8)
      .fontColor(this.searchOpen || this.query !== '' ? '#000000' : this.p().dim)
      .height(22)
      .padding({ left: 8, right: 8 })
      .backgroundColor(this.searchOpen || this.query !== '' ? this.p().accent : this.p().card)
      .borderRadius(11)
      .textAlign(TextAlign.Center)
      .onClick(() => {
        this.searchOpen = !this.searchOpen;
      })
  }

  @Builder
  CatChipView(key: string, label: string) {
    Text(label)
      .fontSize(8)
      .fontColor(this.categoryKey === key ? '#000000' : this.p().dim)
      .height(22)
      .padding({ left: 8, right: 8 })
      .backgroundColor(this.categoryKey === key ? this.p().accent : this.p().card)
      .borderRadius(11)
      .textAlign(TextAlign.Center)
      .onClick(() => {
        this.categoryKey = key;
        this.applyFilter();
      })
  }

  @Builder
  VisibleChip() {
    Text('仅可见')
      .fontSize(8)
      .fontColor(this.visibleOnly ? '#000000' : this.p().dim)
      .height(22)
      .padding({ left: 8, right: 8 })
      .backgroundColor(this.visibleOnly ? this.p().accent : this.p().card)
      .borderRadius(11)
      .textAlign(TextAlign.Center)
      .onClick(() => {
        this.visibleOnly = !this.visibleOnly;
        this.applyFilter();
      })
  }

  @Builder
  ClearChip() {
    if (this.query !== '') {
      Text('清除')
        .fontSize(8)
        .fontColor(this.p().dim)
        .height(22)
        .padding({ left: 8, right: 8 })
        .backgroundColor(this.p().card)
        .borderRadius(11)
        .textAlign(TextAlign.Center)
        .onClick(() => {
          this.query = '';
          this.applyFilter();
        })
    }
  }

  @Builder
  InfoRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(8)
        .fontColor(this.p().dim)
        .width(62)
      Text(value)
        .fontSize(9)
        .fontColor(this.p().fg)
        .layoutWeight(1)
        .textAlign(TextAlign.End)
        .maxLines(2)
    }
    .width('100%')
    .padding({ top: 2, bottom: 2 })
  }

  private nameFor(o: MessierObject, english: boolean): string {
    return targetDisplayName(o.id, o.name, o.nameEn, english);
  }

  @Builder
  NameLanguageButton() {
    Button(this.englishNames ? '星名 EN' : '星名 中')
      .fontSize(8)
      .height(22)
      .width(44)
      .padding(0)
      .backgroundColor(this.p().card)
      .fontColor(this.p().accent)
      .onClick(() => this.onToggleNames())
  }

  @Builder
  DetailBody(o: MessierObject) {
    Row() {
      Button('← 返回')
        .fontSize(9)
        .height(24)
        .backgroundColor(this.p().card)
        .fontColor(this.p().accent)
        .onClick(() => {
          this.selected = -1;
        })
      Blank()
      this.NameLanguageButton()
      Text(`${this.selected + 1}/${ALL_TARGETS.length}`)
        .fontSize(8)
        .fontColor(this.p().dim)
        .margin({ left: 4 })
    }
    .width('100%')

    Text(o.id)
      .fontSize(26)
      .fontColor(this.p().accent)
      .fontWeight(FontWeight.Bold)
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
    Text(this.nameFor(o, this.englishNames))
      .fontSize(14)
      .fontColor(this.p().fg)
      .maxLines(2)
    if (this.nameFor(o, !this.englishNames) !== this.nameFor(o, this.englishNames) &&
      this.nameFor(o, !this.englishNames) !== o.id) {
      Text(this.nameFor(o, !this.englishNames))
        .fontSize(9)
        .fontColor(this.p().dim)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    Text(`${o.type} · ${this.categoryLabel(o.category)}`)
      .fontSize(8)
      .fontColor(this.p().accent)

    Row({ space: 5 }) {
      Button('导航到目标')
        .fontSize(10)
        .height(28)
        .padding(0)
        .layoutWeight(1)
        .backgroundColor(this.p().card)
        .fontColor(this.p().accent)
        .onClick(() => {
          this.selected = -1;
          this.onNavigate(o.id);
        })
      if (o.category === 'nebula' || o.category === 'galaxy' || o.category === 'cluster') {
        Button('取景模拟')
          .fontSize(10)
          .height(28)
          .padding(0)
          .layoutWeight(1)
          .backgroundColor(this.p().card)
          .fontColor(this.p().accent)
          .onClick(() => this.onFrame(o.id))
        Button('星桥')
          .fontSize(10)
          .height(28)
          .padding(0)
          .layoutWeight(1)
          .backgroundColor(this.p().card)
          .fontColor(this.p().accent)
          .onClick(() => this.onStarHop(o.id))
      }
    }.width('100%').margin({ top: 3 })

    Column() {
      this.InfoRow('赤经', this.raTextFor(o))
      this.InfoRow('赤纬', this.decTextFor(o))
      this.InfoRow('历元', this.epochText(o))
      this.InfoRow('星等', this.magText(o))
      this.InfoRow('角尺寸', this.sizeText(o))
      this.InfoRow('推荐焦段', this.flText(o))
      this.InfoRow('表面亮度', this.sbText(o))
      this.InfoRow('距离', this.distText(o))
      if (isSolarId(o.id)) {
        this.InfoRow('相位', this.phaseText(o))
      }
      this.InfoRow('最佳季节', o.season !== '' ? o.season : '—')
    }
    .width('100%')
    .padding({ left: 8, right: 8, top: 4, bottom: 4 })
    .backgroundColor(this.p().card)
    .borderRadius(8)
    .margin({ top: 2 })

    Text(`别名：${this.aliasText(o)}`)
      .fontSize(7)
      .fontColor(this.p().dim)
      .width('100%')
      .maxLines(2)
      .margin({ top: 2 })

    Text(this.windowText)
      .fontSize(8)
      .fontColor(this.p().accent)
      .width('100%')
      .margin({ top: 2 })

    if (o.desc !== '') {
      Text(o.desc)
        .fontSize(8)
        .fontColor(this.p().fg)
        .width('100%')
        .margin({ top: 2 })
    }

    Text(`数据源：${o.source}`)
      .fontSize(6)
      .fontColor(this.p().dim)
      .width('100%')
      .margin({ top: 2 })
    Text(' ')
      .height(8)
  }

  build() {
    if (this.selected < 0) {
      Column({ space: 3 }) {
        Row() {
          Text('天体目录')
            .fontSize(12)
            .fontColor(this.p().accent)
            .fontWeight(FontWeight.Bold)
          Blank()
          this.NameLanguageButton()
          Text(`${this.shownCount}/${ALL_TARGETS.length}`)
            .fontSize(8)
            .fontColor(this.p().dim)
            .margin({ left: 4 })
        }
        .width('100%')

        if (this.searchOpen) {
          TextInput({ placeholder: '名称或编号', text: this.query })
            .fontSize(8)
            .fontColor(this.p().fg)
            .placeholderColor(this.p().dim)
            .placeholderFont({ size: 7 })
            .height(32)
            .width('100%')
            .padding({ left: 8, right: 8, top: 0, bottom: 0 })
            .backgroundColor(this.p().card)
            .borderRadius(8)
            .onChange((value: string) => {
              this.query = value;
              this.applyFilter();
            })
        }

        Column({ space: 4 }) {
          Row({ space: 4 }) {
            this.SearchChip()
            this.CatChipView('all', '全部')
            this.CatChipView('nebula', '星云')
            this.CatChipView('galaxy', '星系')
            this.CatChipView('cluster', '星团')
          }
          Row({ space: 4 }) {
            this.CatChipView('star', '恒星')
            this.CatChipView('double', '双星')
            this.CatChipView('variable', '变星')
            this.CatChipView('solar', '太阳系')
            this.VisibleChip()
            this.ClearChip()
          }
        }
        .width('100%')

        if (this.shownCount === 0) {
          Column() {
            Text('没有匹配目标')
              .fontSize(10)
              .fontColor(this.p().dim)
            Text('清除搜索或切换分类')
              .fontSize(7)
              .fontColor(this.p().dim)
              .margin({ top: 4 })
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else {
          List({ space: 2, scroller: this.listScroller }) {
            LazyForEach(this.source, (row: CatalogRow) => {
              ListItem() {
                Row() {
                  Column({ space: 0 }) {
                    Text(this.nameFor(row.obj, this.englishNames))
                      .fontSize(10)
                      .fontColor(this.p().fg)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                    Text(`${row.obj.id} · ${row.obj.type}`)
                      .fontSize(7)
                      .fontColor(this.p().dim)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Start)

                  Column({ space: 0 }) {
                    Text(this.altText(row.altDeg))
                      .fontSize(9)
                      .fontColor(this.statusColor(row.status))
                    Text(row.status !== '' ? row.status : '--')
                      .fontSize(7)
                      .fontColor(this.statusColor(row.status))
                  }
                  .width(48)
                  .alignItems(HorizontalAlign.End)
                }
                .width('100%')
                .height(38)
                .padding({ left: 8, right: 8 })
                .backgroundColor(this.p().card)
                .borderRadius(8)
              }
              .onClick(() => {
                this.selected = row.catIndex;
                this.computeWindow(row.catIndex);
              })
            }, (row: CatalogRow) => row.obj.id)
          }
          .width('100%')
          .layoutWeight(1)
          .scrollBar(BarState.Off)
        }
      }
      .width('100%')
      .height('100%')
      .padding({ left: 32, right: 32, top: 24, bottom: 10 })
    } else {
      Scroll(this.detailScroller) {
        Column({ space: 3 }) {
          this.DetailBody(ALL_TARGETS[this.selected])
        }
        .width('100%')
        .padding({ left: 34, right: 34, top: 30, bottom: 16 })
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
    }
  }
}
