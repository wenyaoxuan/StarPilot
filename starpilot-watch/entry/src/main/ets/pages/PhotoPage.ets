import { preferences } from '@kit.ArkData';
import { window } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { palette, Palette } from '../common/Theme';
import { vibrateAlert } from '../common/Vibrate';
import { audit } from '../common/AuditLog';
import {
  APERTURES,
  CAMERAS,
  COUNTS,
  CameraSpec,
  ExposureResult,
  FOCALS,
  FovResult,
  ISOS,
  LensSpec,
  SUB_SECONDS,
  TARGET_MINUTES,
  cameraMegapixels,
  clampAperture,
  equivalentFocalMm,
  exposureFor,
  fovFor,
  formatDuration,
  stackPlan
} from '../common/Photo';
import { findStaticTarget } from '../data/TargetCatalog';
import { isSolarId, solarPosition, SolarPosition } from '../common/SolarSystem';
import { jdFromUnixMs } from '../common/Astro';
import { SkyModel, skyModel } from '../common/LightPollution';

const LEGACY_FOCALS: number[] = [85, 135, 180, 200, 300, 300];
const APERTURE_PRESETS: number[] = [1.8, 2.8, 4.0, 5.6, 8.0, 11.0];
const TOTAL_PRESETS: number[] = [15, 30, 60, 120, 240];
const CAMERA_BRANDS: string[] = ['全部', 'Sony', 'Canon', 'Nikon', 'Fujifilm',
  'Panasonic', 'OM System', 'Leica', 'Hasselblad', 'Pentax', 'Apple'];

enum PhotoPicker {
  Main,
  Camera,
  Focal,
  CustomFocal,
  CustomIso,
  CustomTotal
}

@Component
export struct PhotoPage {
  @Prop @Watch('onActiveChanged') active: boolean = false;
  @Prop redMode: boolean = false;
  @Prop @Watch('onTargetChanged') targetId: string = '';
  @Prop @Watch('onBortleChanged') bortle: number = 9;

  @State remaining: number = 0;
  @State running: boolean = false;
  @State timerExpanded: boolean = false;
  @State note: string = '选一个时长开始';
  @State keepNote: string = '';

  @State cameraIndex: number = 0;
  @State cameraBrand: string = '全部';
  @State focalIndex: number = 6;
  @State focalMm: number = 85;
  @State lensMax: number = 1.8;
  @State aperture: number = 1.8;
  @State isoValue: number = 800;
  @State totalMinutes: number = 120;
  @State trackedMode: number = 0;
  @State subIndex: number = 2;
  @State countIndex: number = 2;
  @State fovText: string = '';
  @State expText: string = '';
  @State durationText: string = '';
  @State planWarning: string = '';
  @State detailText: string = '';
  @State picker: PhotoPicker = PhotoPicker.Main;
  @State digits: string = '';
  private mainScroller: Scroller = new Scroller();

  private endMs: number = 0;
  private timerId: number = -1;
  private store: preferences.Preferences | null = null;

  private p(): Palette {
    return palette(this.redMode);
  }

  private camera(): CameraSpec {
    return CAMERAS[this.cameraIndex];
  }

  private focalName(): string {
    if (this.focalIndex >= 0 && this.focalIndex < FOCALS.length) {
      return FOCALS[this.focalIndex].name;
    }
    return `${this.focalMm}mm 自定义`;
  }

  private filteredCameras(): CameraSpec[] {
    if (this.cameraBrand === '全部') {
      return CAMERAS;
    }
    const out: CameraSpec[] = [];
    for (let i = 0; i < CAMERAS.length; i++) {
      if (CAMERAS[i].brand === this.cameraBrand) {
        out.push(CAMERAS[i]);
      }
    }
    return out;
  }

  private exactFocalIndex(mm: number): number {
    for (let i = 0; i < FOCALS.length; i++) {
      if (FOCALS[i].focalMm === mm) {
        return i;
      }
    }
    return -1;
  }

  aboutToAppear(): void {
    this.loadState();
    this.recompute();
  }

  aboutToDisappear(): void {
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  onActiveChanged(): void {
    // The timer keeps its own interval.
  }

  onTargetChanged(): void {
    this.recompute();
  }

  onBortleChanged(): void {
    this.recompute();
  }

  private loadState(): void {
    try {
      const ctx = this.getUIContext().getHostContext();
      if (ctx === undefined) {
        return;
      }
      this.store = preferences.getPreferencesSync(ctx, { name: 'starpilot_s1' });
      this.cameraIndex = this.clampIndex(this.store.getSync('camera_index', 0) as number, CAMERAS.length);

      const savedFocal: number = this.store.getSync('focal_index', -1) as number;
      if (savedFocal >= 0 && savedFocal < FOCALS.length) {
        this.focalIndex = savedFocal;
      } else {
        const oldIndex: number = this.clampIndex(this.store.getSync('lens_index', 0) as number,
          LEGACY_FOCALS.length);
        this.focalIndex = this.findFocalIndex(LEGACY_FOCALS[oldIndex]);
      }
      this.focalMm = FOCALS[this.focalIndex].focalMm;
      this.lensMax = FOCALS[this.focalIndex].maxAperture;
      const savedMm: number = this.store.getSync('focal_mm', -1) as number;
      if (savedMm >= 1) {
        this.focalMm = Math.max(1, Math.min(3000, Math.round(savedMm)));
        const savedMax: number = this.store.getSync('focal_max_ap', this.lensMax) as number;
        this.focalIndex = savedMax === 0 ? -1 : this.exactFocalIndex(this.focalMm);
        this.lensMax = savedMax === 0 || savedMax >= 0.7 ? savedMax : this.lensMax;
      }

      const savedAp: number = this.store.getSync('aperture_value', -1) as number;
      if (savedAp >= 0) {
        this.aperture = clampAperture(savedAp);
      } else {
        const oldAp: number = this.clampIndex(this.store.getSync('aperture_index', 0) as number,
          APERTURES.length);
        this.aperture = clampAperture(APERTURES[oldAp]);
      }

      const savedIso: number = this.store.getSync('iso_value', -1) as number;
      if (savedIso >= 50) {
        this.isoValue = this.clampIso(savedIso);
      } else {
        const oldIso: number = this.clampIndex(this.store.getSync('iso_index', 3) as number, ISOS.length);
        this.isoValue = ISOS[oldIso];
      }

      this.trackedMode = this.store.getSync('photo_mode', 0) as number;
      this.subIndex = this.clampIndex(this.store.getSync('sub_index', 2) as number, SUB_SECONDS.length);
      this.countIndex = this.clampIndex(this.store.getSync('count_index', 2) as number, COUNTS.length);
      const savedTotal: number = this.store.getSync('total_minutes', -1) as number;
      if (savedTotal >= 1) {
        this.totalMinutes = this.clampTotal(savedTotal);
      } else {
        const oldTotal: number = this.clampIndex(this.store.getSync('total_index', 2) as number,
          TARGET_MINUTES.length);
        this.totalMinutes = TARGET_MINUTES[oldTotal];
      }
      this.trackedMode = this.trackedMode === 1 ? 1 : 0;

      const end: number = this.store.getSync('timer_end', 0) as number;
      if (end > 0) {
        const left: number = Math.ceil((end - Date.now()) / 1000);
        if (left > 0) {
          this.endMs = end;
          this.remaining = left;
          this.running = true;
          this.note = `已恢复，结束于 ${this.clockOf(end)}`;
          this.setKeepOn(true);
          this.startTick();
          audit('TIMER', `resume left=${left}s`);
        } else {
          this.store.putSync('timer_end', 0);
          this.store.flush();
          this.remaining = 0;
          this.running = false;
          this.note = '上次计时已结束';
          vibrateAlert(800);
          audit('TIMER', 'catch-up alert');
        }
      }
    } catch (err) {
      audit('PHOTO_ERR', `load ${JSON.stringify(err)}`);
    }
  }

  private clampIndex(v: number, n: number): number {
    if (v < 0 || v >= n) {
      return 0;
    }
    return v;
  }

  private clampIso(v: number): number {
    return Math.max(50, Math.min(409600, Math.round(v)));
  }

  private clampTotal(v: number): number {
    return Math.max(1, Math.min(1440, Math.round(v)));
  }

  private findFocalIndex(focalMm: number): number {
    for (let i = 0; i < FOCALS.length; i++) {
      if (FOCALS[i].focalMm === focalMm) {
        return i;
      }
    }
    return 6;
  }

  private clockOf(ms: number): string {
    const d: Date = new Date(ms);
    return `${d.getHours()}:${d.getMinutes() < 10 ? '0' : ''}${d.getMinutes()}`;
  }

  private fmt(sec: number): string {
    const m: number = Math.floor(sec / 60);
    const s: number = sec % 60;
    return `${m < 10 ? '0' : ''}${m}:${s < 10 ? '0' : ''}${s}`;
  }

  private start(seconds: number): void {
    this.stopTick();
    this.remaining = seconds;
    this.running = true;
    this.endMs = Date.now() + seconds * 1000;
    this.note = `结束于 ${this.clockOf(this.endMs)}`;
    try {
      if (this.store !== null) {
        this.store.putSync('timer_end', this.endMs);
        this.store.putSync('timer_total', seconds);
        this.store.flush();
      }
    } catch (err) {
      audit('TIMER_ERR', `save ${JSON.stringify(err)}`);
    }
    this.setKeepOn(true);
    this.startTick();
    audit('TIMER', `start=${seconds}s end=${this.endMs}`);
  }

  private startTick(): void {
    this.timerId = setInterval(() => {
      const left: number = Math.ceil((this.endMs - Date.now()) / 1000);
      this.remaining = left > 0 ? left : 0;
      if (left <= 0) {
        this.finish();
      }
    }, 1000);
  }

  private stopTick(): void {
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  private finish(): void {
    this.stopTick();
    this.running = false;
    this.remaining = 0;
    this.note = '计时结束';
    this.setKeepOn(false);
    try {
      if (this.store !== null) {
        this.store.putSync('timer_end', 0);
        this.store.flush();
      }
    } catch (err) {
      audit('TIMER_ERR', `clear ${JSON.stringify(err)}`);
    }
    vibrateAlert(800);
    audit('TIMER', 'done');
  }

  private stop(): void {
    this.stopTick();
    this.running = false;
    this.note = '已停止';
    this.setKeepOn(false);
    try {
      if (this.store !== null) {
        this.store.putSync('timer_end', 0);
        this.store.flush();
      }
    } catch (err) {
      audit('TIMER_ERR', `stop ${JSON.stringify(err)}`);
    }
    audit('TIMER', `stopped at ${this.remaining}s`);
  }

  private setKeepOn(on: boolean): void {
    const ctx = this.getUIContext().getHostContext();
    if (ctx === undefined) {
      this.keepNote = '无上下文';
      return;
    }
    window.getLastWindow(ctx).then((win: window.Window) => {
      win.setWindowKeepScreenOn(on).then(() => {
        this.keepNote = on ? '计时期间常亮' : '';
        audit('SCREEN', on ? 'keep on' : 'keep off');
      }).catch((e: BusinessError) => {
        this.keepNote = `常亮失败 ${e.code}`;
        audit('SCREEN', `keep ${on} err ${e.code}`);
      });
    }).catch((e: BusinessError) => {
      this.keepNote = `窗口失败 ${e.code}`;
      audit('SCREEN', `window err ${e.code}`);
    });
  }

  private targetDec(): number {
    if (isSolarId(this.targetId)) {
      const p: SolarPosition | null = solarPosition(this.targetId, jdFromUnixMs(Date.now()));
      return p === null ? 0 : p.decDeg;
    }
    return findStaticTarget(this.targetId)?.decDeg ?? 0;
  }

  private saveConfig(): void {
    try {
      if (this.store !== null) {
        this.store.putSync('camera_index', this.cameraIndex);
        this.store.putSync('focal_index', this.focalIndex);
        this.store.putSync('focal_mm', this.focalMm);
        this.store.putSync('focal_max_ap', this.lensMax);
        this.store.putSync('aperture_value', this.aperture);
        this.store.putSync('iso_value', this.isoValue);
        this.store.putSync('photo_mode', this.trackedMode);
        this.store.putSync('sub_index', this.subIndex);
        this.store.putSync('count_index', this.countIndex);
        this.store.putSync('total_minutes', this.totalMinutes);
        this.store.flush();
      }
    } catch (err) {
      audit('PHOTO_ERR', `save ${JSON.stringify(err)}`);
    }
  }

  private formatPlanDuration(seconds: number): string {
    const minutes: number = Math.round(seconds / 60);
    if (minutes < 60) {
      return formatDuration(seconds);
    }
    const hours: number = Math.floor(minutes / 60);
    const rest: number = minutes % 60;
    return rest > 0 ? `${hours}h ${rest}m` : `${hours}h`;
  }

  private recompute(): void {
    const camera: CameraSpec = this.camera();
    const dec: number = this.targetDec();
    const fov: FovResult = fovFor(camera, this.focalMm);
    const exp: ExposureResult = exposureFor(camera, this.focalMm, this.aperture, dec);
    const equiv: number = equivalentFocalMm(camera, this.focalMm);
    const mp: number = cameraMegapixels(camera);
    const sky: SkyModel = skyModel(camera, this.aperture, this.bortle, this.isoValue);
    this.fovText = `${camera.format} · 视场 ${fov.hDeg.toFixed(1)}° × ${fov.vDeg.toFixed(1)}° · ` +
      `${fov.pixelScaleArcsec.toFixed(2)}″/px · 等效 ${equiv.toFixed(0)} mm`;
    this.detailText = `${mp.toFixed(1)}MP · ${camera.sensorW.toFixed(1)}×${camera.sensorH.toFixed(1)} mm · ` +
      `${camera.pixelPitchUm.toFixed(2)}µm · 裁切 ${camera.cropFactor.toFixed(2)}×`;

    let sub: number = SUB_SECONDS[this.subIndex];
    let count: number = COUNTS[this.countIndex];
    let gap: number = 2;
    this.planWarning = '';
    if (this.trackedMode === 0) {
      const upper: number = Math.min(exp.npfSec, sky.saturationSec);
      // Round down to the precision shown on the watch before calculating the stack.
      const scale: number = upper < 1 ? 1000 : 10;
      sub = Math.floor(upper * scale) / scale;
      count = stackPlan(this.totalMinutes * 60, sub).count;
      gap = 3;
      this.detailText += `\nNPF ${exp.npfSec.toFixed(2)}s · 500 法则 ${exp.rule500Sec.toFixed(2)}s · ` +
        `1px 拖线 ${exp.pixelDragSec.toFixed(2)}s`;
      if (sky.saturationSec < exp.npfSec) {
        this.planWarning = '单张受估算饱和阈值限制';
      }
    } else if (sub > sky.saturationSec) {
      this.planWarning = '设定超过估算饱和阈值';
    }
    if (sub < sky.skyLimitedSec) {
      this.detailText += '\n单张短于读噪参考时长';
    }
    const exposure: number = sub * count;
    this.expText = `${sub}s × ${count} 张`;
    const elapsed: number = exposure + (count - 1) * gap;
    this.durationText = `曝光 ${this.formatPlanDuration(exposure)} · 耗时约 ${this.formatPlanDuration(elapsed)}`;
    this.detailText += `\nBortle ${this.bortle.toFixed(1)} · SQM ${sky.sqm.toFixed(2)} · 间隔 ${gap}s` +
      `\n读噪参考 ${sky.skyLimitedSec.toFixed(2)}s · 饱和预警 ${sky.saturationSec.toFixed(2)}s` +
      `\n天光 ${sky.skyRate.toFixed(2)}e/px/s · 读出噪声 ${sky.readNoiseE.toFixed(1)}e`;
    if (this.aperture < this.lensMax) {
      this.detailText += `\n注意：F${this.aperture.toFixed(1)} 超过 ${this.focalName()} 的最大光圈 F${this.lensMax}`;
    }
    audit('PHOTO', `camera=${camera.brand} ${camera.name};focal=${this.focalMm};f=${this.aperture};` +
      `iso=${this.isoValue};bortle=${this.bortle};sqm=${sky.sqm.toFixed(2)};` +
      `skyRate=${sky.skyRate.toFixed(2)};noiseRef=${sky.skyLimitedSec.toFixed(2)};sat=${sky.saturationSec.toFixed(2)};` +
      `total=${this.totalMinutes}min;dec=${dec};mode=${this.trackedMode};${this.expText}`);
  }

  private selectCamera(index: number): void {
    if (index < 0 || index >= CAMERAS.length) {
      return;
    }
    this.cameraIndex = index;
    this.picker = PhotoPicker.Main;
    this.recompute();
    this.saveConfig();
  }

  private selectFocal(index: number): void {
    if (index < 0 || index >= FOCALS.length) {
      return;
    }
    this.focalIndex = index;
    this.focalMm = FOCALS[index].focalMm;
    this.lensMax = FOCALS[index].maxAperture;
    if (this.aperture < this.lensMax) {
      this.aperture = this.lensMax;
    }
    this.picker = PhotoPicker.Main;
    this.recompute();
    this.saveConfig();
  }

  private bumpAperture(delta: number): void {
    this.aperture = clampAperture(this.aperture + delta);
    this.recompute();
    this.saveConfig();
  }

  private chooseAperture(value: number): void {
    this.aperture = clampAperture(value);
    this.recompute();
    this.saveConfig();
  }

  private setIso(value: number): void {
    this.isoValue = this.clampIso(value);
    this.recompute();
    this.saveConfig();
  }

  private setMode(mode: number): void {
    if (mode === this.trackedMode) {
      return;
    }
    this.trackedMode = mode;
    this.recompute();
    this.saveConfig();
  }

  private cycleSub(): void {
    this.subIndex = (this.subIndex + 1) % SUB_SECONDS.length;
    this.recompute();
    this.saveConfig();
  }

  private cycleCount(): void {
    this.countIndex = (this.countIndex + 1) % COUNTS.length;
    this.recompute();
    this.saveConfig();
  }

  private setTotal(value: number): void {
    this.totalMinutes = this.clampTotal(value);
    this.recompute();
    this.saveConfig();
  }

  private openEditor(picker: PhotoPicker): void {
    this.digits = '';
    this.picker = picker;
  }

  private backFromEditor(): void {
    this.picker = this.picker === PhotoPicker.CustomFocal ? PhotoPicker.Focal : PhotoPicker.Main;
  }

  private applyNumber(min: number, max: number): void {
    const value: number = Number(this.digits);
    if (value < min || value > max) {
      return;
    }
    if (this.picker === PhotoPicker.CustomFocal) {
      this.focalMm = value;
      this.focalIndex = -1;
      this.lensMax = 0;
      this.recompute();
      this.saveConfig();
    } else if (this.picker === PhotoPicker.CustomIso) {
      this.setIso(value);
    } else {
      this.setTotal(value);
    }
    this.picker = PhotoPicker.Main;
  }

  @Builder
  Preset(label: string, seconds: number) {
    Button(label)
      .fontSize(9)
      .height(28)
      .layoutWeight(1)
      .backgroundColor(this.p().card)
      .fontColor(this.p().fg)
      .onClick(() => this.start(seconds))
  }

  @Builder
  ApChip(value: number) {
    Text(`F${value}`)
      .fontSize(7)
      .height(22)
      .layoutWeight(1)
      .textAlign(TextAlign.Center)
      .backgroundColor(this.aperture === value ? this.p().accent : this.p().card)
      .fontColor(this.aperture === value ? '#000000' : this.p().dim)
      .borderRadius(11)
      .onClick(() => this.chooseAperture(value))
  }

  @Builder
  IsoChip(value: number) {
    Text(`${value}`)
      .fontSize(8)
      .height(26)
      .layoutWeight(1)
      .textAlign(TextAlign.Center)
      .backgroundColor(this.isoValue === value ? this.p().accent : this.p().card)
      .fontColor(this.isoValue === value ? '#000000' : this.p().fg)
      .borderRadius(13)
      .onClick(() => this.setIso(value))
  }

  @Builder
  TotalChip(value: number) {
    Text(`${value}m`)
      .fontSize(8)
      .height(26)
      .layoutWeight(1)
      .textAlign(TextAlign.Center)
      .backgroundColor(this.totalMinutes === value ? this.p().accent : this.p().card)
      .fontColor(this.totalMinutes === value ? '#000000' : this.p().fg)
      .borderRadius(13)
      .onClick(() => this.setTotal(value))
  }

  @Builder
  PickerHeader(title: string, onBack: () => void) {
    Row() {
      Button('← 返回')
        .fontSize(9)
        .height(26)
        .width(66)
        .backgroundColor(this.p().card)
        .fontColor(this.p().accent)
        .onClick(onBack)
      Blank()
      Text(title)
        .fontSize(10)
        .fontColor(this.p().fg)
      Blank()
      Text(' ')
        .width(40)
    }
    .width('100%')
    .height(30)
    .padding({ left: 30, right: 30 })
    .margin({ top: 26 })
  }

  @Builder
  CameraPicker() {
    Column({ space: 3 }) {
      this.PickerHeader('选择相机', () => { this.picker = PhotoPicker.Main; })
      Scroll() {
        Row({ space: 3 }) {
          ForEach(CAMERA_BRANDS, (b: string) => {
            Text(b)
              .fontSize(7)
              .height(20)
              .padding({ left: 8, right: 8 })
              .borderRadius(10)
              .textAlign(TextAlign.Center)
              .backgroundColor(this.cameraBrand === b ? this.p().accent : this.p().card)
              .fontColor(this.cameraBrand === b ? '#000000' : this.p().dim)
              .onClick(() => {
                this.cameraBrand = b;
              })
          }, (b: string) => b)
        }
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
      .height(24)
      .padding({ left: 28, right: 28 })

      List({ space: 2 }) {
        ForEach(this.filteredCameras(), (c: CameraSpec) => {
          ListItem() {
            Row() {
              Column({ space: 0 }) {
                Text(`${c.brand} ${c.name}`)
                  .fontSize(9)
                  .fontColor(c === this.camera() ? this.p().accent : this.p().fg)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(`${c.format} · ${cameraMegapixels(c).toFixed(0)}MP · ` +
                  `${c.sensorW.toFixed(1)}×${c.sensorH.toFixed(1)}mm` +
                  (c.note !== undefined && c.note.length > 0 ? ` · ${c.note}` : ''))
                  .fontSize(6)
                  .fontColor(this.p().dim)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
              if (c === this.camera()) {
                Text('✓')
                  .fontSize(9)
                  .fontColor(this.p().accent)
              }
            }
            .width('100%')
            .height(34)
            .padding({ left: 8, right: 8 })
            .backgroundColor(c === this.camera() ? this.p().card : '#000000')
            .borderRadius(8)
            .onClick(() => this.selectCamera(CAMERAS.indexOf(c)))
          }
        }, (c: CameraSpec) => `${c.brand}_${c.name}`)
      }
      .width('100%')
      .layoutWeight(1)
      .padding({ left: 28, right: 28 })
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#000000')
  }

  @Builder
  FocalPicker() {
    Column({ space: 3 }) {
      this.PickerHeader('选择焦段', () => { this.picker = PhotoPicker.Main; })
      this.SettingButton('自定义焦段', () => this.focalMm.toString() + ' mm', () => this.openEditor(PhotoPicker.CustomFocal))
      List({ space: 2 }) {
        ForEach(FOCALS, (l: LensSpec, i: number) => {
          ListItem() {
            Row() {
              Column({ space: 0 }) {
                Text(l.name)
                  .fontSize(9)
                  .fontColor(i === this.focalIndex ? this.p().accent : this.p().fg)
                Text(`等效 ${equivalentFocalMm(this.camera(), l.focalMm).toFixed(0)}mm · ` +
                  `${this.camera().format}`)
                  .fontSize(6)
                  .fontColor(this.p().dim)
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
              if (i === this.focalIndex) {
                Text('✓')
                  .fontSize(9)
                  .fontColor(this.p().accent)
              }
            }
            .width('100%')
            .height(34)
            .padding({ left: 8, right: 8 })
            .backgroundColor(i === this.focalIndex ? this.p().card : '#000000')
            .borderRadius(8)
            .onClick(() => this.selectFocal(i))
          }
        }, (l: LensSpec) => l.name)
      }
      .width('100%')
      .layoutWeight(1)
      .padding({ left: 28, right: 28 })
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#000000')
  }

  @Builder
  SettingButton(label: string, value: () => string, onTap: () => void) {
    Row({ space: 6 }) {
      Text(label)
        .fontSize(9)
        .fontColor(this.p().fg)
      Text(value())
        .fontSize(9)
        .fontColor(this.p().accent)
        .layoutWeight(1)
        .textAlign(TextAlign.End)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text('›')
        .fontSize(12)
        .fontColor(this.p().accent)
    }
    .width('100%')
    .height(28)
    .padding({ left: 9, right: 9 })
    .backgroundColor(this.p().card)
    .borderRadius(14)
    .onClick(onTap)
  }

  @Builder
  NumberKey(label: string, onTap: () => void) {
    Button(label)
      .fontSize(12)
      .height(27)
      .layoutWeight(1)
      .padding(0)
      .backgroundColor(this.p().card)
      .fontColor(this.p().fg)
      .onClick(onTap)
  }

  @Builder
  DigitRow(row: string[], maxDigits: number) {
    Row({ space: 4 }) {
      ForEach(row, (digit: string) => {
        this.NumberKey(digit, () => {
          if (this.digits.length < maxDigits) {
            this.digits += digit;
          }
        })
      }, (digit: string) => digit)
    }
    .width('100%')
  }

  @Builder
  NumberEditor(title: string, current: number, min: number, max: number, unit: string) {
    Column({ space: 2 }) {
      this.PickerHeader(title, () => this.backFromEditor())
      Text(this.digits === '' ? '当前 ' + current.toString() : this.digits)
        .fontSize(16)
        .fontColor(this.p().fg)
      Text(min.toString() + '–' + max.toString() + unit)
        .fontSize(8)
        .fontColor(this.p().dim)

      Column({ space: 3 }) {
        this.DigitRow(['1', '2', '3'], max.toString().length)
        this.DigitRow(['4', '5', '6'], max.toString().length)
        this.DigitRow(['7', '8', '9'], max.toString().length)
        Row({ space: 4 }) {
          this.NumberKey('退格', () => { this.digits = this.digits.slice(0, -1); })
          this.NumberKey('0', () => {
            if (this.digits.length > 0 && this.digits.length < max.toString().length) {
              this.digits += '0';
            }
          })
          Button('确定')
            .fontSize(10)
            .height(27)
            .layoutWeight(1)
            .padding(0)
            .backgroundColor(this.p().accent)
            .fontColor('#000000')
            .enabled(Number(this.digits) >= min && Number(this.digits) <= max)
            .onClick(() => this.applyNumber(min, max))
        }
        .width('100%')
      }
      .width('100%')
      .padding({ left: 41, right: 41 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.p().bg)
  }

  @Builder
  ModeButton(label: string, mode: number) {
    Button(label)
      .fontSize(9)
      .height(26)
      .layoutWeight(1)
      .backgroundColor(this.trackedMode === mode ? this.p().accent : this.p().card)
      .fontColor(this.trackedMode === mode ? '#000000' : this.p().fg)
      .onClick(() => this.setMode(mode))
  }

  @Builder
  TimerPanel() {
    if (this.timerExpanded || this.running) {
      Column({ space: 4 }) {
        Text(this.fmt(this.remaining))
          .fontSize(28)
          .fontColor(this.p().fg)
        Text(this.note)
          .fontSize(8)
          .fontColor(this.p().fg)
        if (this.running) {
          this.SettingButton('停止计时', () => '', () => this.stop())
          Text(this.keepNote)
            .fontSize(8)
            .fontColor(this.p().dim)
        } else {
          Row({ space: 5 }) {
            this.Preset('30s', 30)
            this.Preset('1m', 60)
            this.Preset('3m', 180)
          }
          .width('100%')
          Row({ space: 5 }) {
            this.Preset('5m', 300)
            this.Preset('10m', 600)
            this.Preset('20m', 1200)
          }
          .width('100%')
          Text('点预设开始 · 计时期间屏幕常亮')
            .fontSize(8)
            .fontColor(this.p().dim)
          this.SettingButton('收起计时器', () => '', () => { this.timerExpanded = false; })
        }
      }
      .width('100%')
    } else {
      this.SettingButton('计时器', () => this.note === '选一个时长开始' ? '30s–20min' : this.note, () => {
        this.timerExpanded = true;
      })
    }
  }

  @Builder
  PlanSummary() {
    Column({ space: 3 }) {
      Text(this.expText)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.p().fg)
        .textAlign(TextAlign.Center)
      Text(this.durationText)
        .fontSize(9)
        .fontColor(this.p().fg)
        .textAlign(TextAlign.Center)
      if (this.planWarning !== '') {
        Text(this.planWarning)
          .fontSize(8)
          .fontColor(this.p().accent)
          .textAlign(TextAlign.Center)
      }
    }
    .width('100%')
    .padding({ top: 8, bottom: 8, left: 4, right: 4 })
    .backgroundColor(this.p().card)
    .borderRadius(12)
  }

  @Builder
  ApertureStep(label: string, delta: number) {
    Button(label)
      .fontSize(13)
      .height(26)
      .width(35)
      .padding(0)
      .backgroundColor(this.p().card)
      .fontColor(this.p().accent)
      .onClick(() => this.bumpAperture(delta))
  }

  @Builder
  IsoPresets(values: number[]) {
    Row({ space: 3 }) {
      ForEach(values, (value: number) => {
        this.IsoChip(value)
      }, (value: number) => value.toString())
    }
    .width('100%')
  }

  @Builder
  MainView() {
    Scroll(this.mainScroller) {
      Column({ space: 5 }) {
        Text('摄影助手')
          .fontSize(12)
          .fontColor(this.p().accent)
          .fontWeight(FontWeight.Bold)
        if (this.targetId === 'SUN') {
          Text('太阳：必须使用合格太阳滤镜，严禁直视')
            .fontSize(8)
            .fontColor(this.p().accent)
            .textAlign(TextAlign.Center)
        }
        this.PlanSummary()
        Row({ space: 5 }) {
          this.ModeButton('无赤道仪', 0)
          this.ModeButton('有赤道仪', 1)
        }
        .width('100%')
        this.TimerPanel()

        Text('拍摄参数')
          .fontSize(10)
          .fontColor(this.p().fg)
          .fontWeight(FontWeight.Bold)
          .width('100%')
        .margin({ top: 2 })

        this.SettingButton('相机', () => this.camera().brand + ' ' + this.camera().name, () => {
          this.cameraBrand = this.camera().brand;
          this.picker = PhotoPicker.Camera;
        })
        this.SettingButton('焦段', () => this.focalName(), () => { this.picker = PhotoPicker.Focal; })

        Row({ space: 5 }) {
          Text('光圈')
            .fontSize(9)
            .fontColor(this.p().fg)
          Blank()
          this.ApertureStep('−', -0.1)
          Text('F' + this.aperture.toFixed(1))
            .fontSize(10)
            .fontColor(this.p().accent)
            .width(40)
            .textAlign(TextAlign.Center)
          this.ApertureStep('+', 0.1)
        }
        .width('100%')
        Row({ space: 3 }) {
          ForEach(APERTURE_PRESETS, (value: number) => {
            this.ApChip(value)
          }, (value: number) => value.toString())
        }
        .width('100%')

        this.SettingButton('ISO', () => this.isoValue.toString(), () => this.openEditor(PhotoPicker.CustomIso))
        this.IsoPresets(ISOS.slice(0, 4))
        this.IsoPresets(ISOS.slice(4))

        if (this.trackedMode === 0) {
          this.SettingButton('目标总曝光', () => this.totalMinutes.toString() + ' min',
            () => this.openEditor(PhotoPicker.CustomTotal))
          Row({ space: 3 }) {
            ForEach(TOTAL_PRESETS, (value: number) => {
              this.TotalChip(value)
            }, (value: number) => value.toString())
          }
          .width('100%')
        } else {
          this.SettingButton('设定单张', () => SUB_SECONDS[this.subIndex].toString() + 's', () => this.cycleSub())
          this.SettingButton('设定张数', () => COUNTS[this.countIndex].toString() + ' 张', () => this.cycleCount())
        }

        Text('计算详情')
          .fontSize(10)
          .fontColor(this.p().fg)
          .fontWeight(FontWeight.Bold)
          .width('100%')
          .margin({ top: 5 })
        Text(this.fovText)
          .fontSize(8)
          .fontColor(this.p().fg)
          .width('100%')
        Text(this.detailText)
          .fontSize(8)
          .fontColor(this.p().dim)
          .width('100%')
        Text('曝光为估算，拖线与饱和请以试拍为准')
          .fontSize(8)
          .fontColor(this.p().dim)
          .width('100%')
      }
      .width('100%')
      .padding({ left: 36, right: 36, top: 27, bottom: 28 })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .visibility(this.picker === PhotoPicker.Main ? Visibility.Visible : Visibility.Hidden)
  }

  build() {
    Stack() {
      this.MainView()
      if (this.picker === PhotoPicker.Camera) {
        this.CameraPicker()
      } else if (this.picker === PhotoPicker.Focal) {
        this.FocalPicker()
      } else if (this.picker === PhotoPicker.CustomFocal) {
        this.NumberEditor('自定义焦段', this.focalMm, 1, 3000, ' mm')
      } else if (this.picker === PhotoPicker.CustomIso) {
        this.NumberEditor('自定义 ISO', this.isoValue, 50, 409600, '')
      } else if (this.picker === PhotoPicker.CustomTotal) {
        this.NumberEditor('自定义总曝光', this.totalMinutes, 1, 1440, ' min')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.p().bg)
  }
}
