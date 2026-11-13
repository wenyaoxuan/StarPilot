import { palette, Palette } from '../common/Theme';
import { CITIES, City } from '../data/Cities';
import { MESSIER, MessierObject } from '../data/Messier';
import { CONSTELLATION_EDGES, CONSTELLATION_STARS, ConstellationStar } from '../data/Constellations';
import { findStaticTarget, targetDisplayName } from '../data/TargetCatalog';
import { SOLAR_BODIES, SolarBody, isSolarId, solarBody, solarHorizontal } from '../common/SolarSystem';
import { Horizontal, jdFromUnixMs, targetHorizontal } from '../common/Astro';
import { AzAlt, Vec3, shortestDelta } from '../common/Fusion';
import { CameraPose, cameraPoseFromQuatTwelve, cameraPoseFromTwelveAngles, twelveTiltFromAcceleration,
  vectorAzAlt, rotatePoseHeading } from '../common/CameraPose';
import { ProjectedPoint, SkySegment, angularSepVec, enuVector, projectPoint, screenDirection,
  visibleSkySegment } from '../common/SkyProjection';
import { sensorHub, AccHandler, GyroHandler } from '../common/SensorHub';
import { orientationHub, OrientationHandler } from '../common/OrientationHub';
import { RotationSample, RotationSampleHandler } from '../common/SensorData';
import { AttitudeFilter, FILTER_ONE_EURO, FilterResult, PointingAngleFilter } from '../common/AttitudeFilter';
import { audit } from '../common/AuditLog';

const FOV: number = 60;
const FRAME_MS: number = 50;

interface SkyMarker {
  direction: Vec3;
  radius: number;
  color: string;
  name: string;
  solar: boolean;
}

interface LabelBounds {
  left: number;
  top: number;
  right: number;
  bottom: number;
}

interface VisibleAnchor {
  x: number;
  y: number;
  star: ConstellationStar;
}

const ANCHOR_IDS: Set<string> = new Set(CONSTELLATION_STARS.map((star) => star.id));
const ANCHORS_BY_BRIGHTNESS: number[] = CONSTELLATION_STARS.map((star, index) => index);
ANCHORS_BY_BRIGHTNESS.sort((a, b) => CONSTELLATION_STARS[a].mag - CONSTELLATION_STARS[b].mag);

const ALTITUDE_RINGS: Vec3[][] = [];
const AZIMUTH_MERIDIANS: Vec3[][] = [];
for (let alt = 0; alt <= 80; alt += 10) {
  const ring: Vec3[] = [];
  for (let az = 0; az <= 360; az += 4) {
    ring.push(enuVector(az, alt));
  }
  ALTITUDE_RINGS.push(ring);
}
for (let az = 0; az < 360; az += 30) {
  const meridian: Vec3[] = [];
  for (let alt = 0; alt <= 85; alt += 5) {
    meridian.push(enuVector(az, alt));
  }
  AZIMUTH_MERIDIANS.push(meridian);
}

const SKY_STARS: MessierObject[] = [];
for (let i = 0; i < MESSIER.length; i++) {
  const o: MessierObject = MESSIER[i];
  if (o.category === 'star' || o.category === 'double' || o.category === 'variable') {
    SKY_STARS.push(o);
  }
}

@Component
export struct ArPage {
  @Prop redMode: boolean = false;
  @Prop @Watch('onNameLanguageChanged') englishNames: boolean = false;
  @Prop targetId: string = '';
  @Prop cityIndex: number = 0;
  @Prop sightingCorrection: number = 0;
  onClose: () => void = () => {
  };
  onToggleNames: () => void = () => {};

  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private ready: boolean = false;
  private listening: boolean = false;
  private centerAz: number = 0;
  private centerAlt: number = 0;
  private lastOriMs: number = 0;
  private oriAlpha: number = 0;
  private lastRotMs: number = 0;
  private frameTimer: number = -1;
  private lastAccMs: number = 0;
  private accAlt: number = 0;
  private rotPose: CameraPose | null = null;
  private lastSkyMs: number = 0;
  private skyMarkers: SkyMarker[] = [];
  private anchors: Vec3[] = [];
  private visibleAnchors: VisibleAnchor[] = [];
  private anchorHintUntil: number = 0;
  private target: Horizontal | null = null;
  private targetName: string = '';
  private labelBounds: LabelBounds[] = [];
  private lastTargetLogMs: number = 0;
  private accX: number = 0;
  private accY: number = 0;
  private accZ: number = 0;
  private cameraForward: Vec3 = new Vec3(0, 0, 1);
  private cameraUp: Vec3 = new Vec3(0, 1, 0);
  private cameraRight: Vec3 = new Vec3(-1, 0, 0);
  private filter: AttitudeFilter = new AttitudeFilter(FILTER_ONE_EURO);
  private headingFilter: PointingAngleFilter = new PointingAngleFilter();
  private altitudeFilter: PointingAngleFilter = new PointingAngleFilter();
  private cw: number = 233;
  private ch: number = 233;
  private ccx: number = 116.5;
  private ccy: number = 116.5;
  @State showLines: boolean = true;
  @State tracking: boolean = false;
  @State hint: string = '等待姿态…';
  @State targetHint: string = '未选择目标';
  @State anchorHintStar: ConstellationStar | null = null;

  private p(): Palette {
    return palette(this.redMode);
  }

  onNameLanguageChanged(): void {
    this.lastSkyMs = 0;
  }

  private oriHandler: OrientationHandler = (alpha: number, beta: number, gamma: number): void => {
    this.lastOriMs = Date.now();
    this.oriAlpha = alpha;
  };

  private rotSampleHandler: RotationSampleHandler = (s: RotationSample): void => {
    if (!s.valid) {
      return;
    }
    const f: FilterResult = this.filter.update(s.x, s.y, s.z, s.w, s.timestamp, s.receivedAt);
    if (!f.valid) {
      return;
    }
    this.rotPose = cameraPoseFromQuatTwelve(f.x, f.y, f.z, f.w);
    this.lastRotMs = s.receivedAt;
  };

  private gyroHandler: GyroHandler = (gx: number, gy: number, gz: number): void => {
    // Keep the ROT stream alive; values are not drawn directly.
  };

  private accHandler: AccHandler = (ax: number, ay: number, az: number): void => {
    const tilt: number | null = twelveTiltFromAcceleration(ax, ay, az);
    if (tilt === null) {
      return;
    }
    this.accX = ax;
    this.accY = ay;
    this.accZ = az;
    this.accAlt = tilt;
    this.lastAccMs = Date.now();
  };

  aboutToAppear(): void {
    this.start();
  }

  aboutToDisappear(): void {
    this.stop();
  }

  private start(): void {
    if (this.listening) {
      return;
    }
    this.listening = true;
    this.targetHint = this.targetId === '' ? '未选择目标' : '等待目标指引';
    sensorHub.subscribeGyro(this.gyroHandler);
    sensorHub.subscribeAcc(this.accHandler);
    sensorHub.subscribeRotSample(this.rotSampleHandler);
    orientationHub.subscribe(this.oriHandler);
    this.frameTimer = setInterval(() => this.frame(), FRAME_MS);
    audit('AR', 'start');
  }

  private stop(): void {
    if (!this.listening) {
      return;
    }
    this.listening = false;
    clearInterval(this.frameTimer);
    this.frameTimer = -1;
    orientationHub.unsubscribe(this.oriHandler);
    sensorHub.unsubscribeRotSample(this.rotSampleHandler);
    sensorHub.unsubscribeGyro(this.gyroHandler);
    sensorHub.unsubscribeAcc(this.accHandler);
    audit('AR', 'stop');
  }

  private frame(): void {
    if (!this.ready) {
      return;
    }
    const now: number = Date.now();
    if (this.anchorHintStar !== null && now >= this.anchorHintUntil) {
      this.anchorHintStar = null;
    }
    const fallback: CameraPose | null = now - this.lastRotMs < 1000 ? this.rotPose : null;
    const hasReference: boolean = now - this.lastOriMs < 1500 && now - this.lastAccMs < 500;
    let pose: CameraPose | null = fallback;
    if (hasReference) {
      const az: number = this.headingFilter.update(this.oriAlpha, now);
      const alt: number = this.altitudeFilter.update(this.accAlt, now);
      const angle: number = az * Math.PI / 180;
      const fallbackUp: Vec3 = fallback === null
        ? new Vec3(-Math.sin(angle) * Math.sign(alt), -Math.cos(angle) * Math.sign(alt), 0)
        : fallback.up;
      pose = cameraPoseFromTwelveAngles(az, alt, fallbackUp);
    }
    if (pose === null) {
      if (this.tracking) {
        this.tracking = false;
        this.ctx.clearRect(0, 0, this.cw, this.ch);
        this.hint = '等待新姿态…';
        this.targetHint = this.targetId === '' ? '未选择目标' : '指引暂停';
      }
      return;
    }
    pose = rotatePoseHeading(pose, this.sightingCorrection);
    this.tracking = true;
    this.cameraForward = pose.forward;
    this.cameraUp = pose.up;
    this.cameraRight = pose.right;
    const view: AzAlt = vectorAzAlt(pose.forward);
    this.centerAz = view.az;
    this.centerAlt = view.alt;
    this.draw(now, hasReference);
  }

  private city(): City {
    if (this.cityIndex >= 0 && this.cityIndex < CITIES.length) {
      return CITIES[this.cityIndex];
    }
    return CITIES[0];
  }

  private targetObject(): MessierObject | null {
    return findStaticTarget(this.targetId);
  }

  private targetHorizontalNow(jd: number, city: City): Horizontal | null {
    if (this.targetId.length === 0) {
      return null;
    }
    if (isSolarId(this.targetId)) {
      return solarHorizontal(this.targetId, jd, city.lat, city.lon);
    }
    const o: MessierObject | null = this.targetObject();
    if (o === null) {
      return null;
    }
    return targetHorizontal({ raHours: o.raHours, decDeg: o.decDeg }, jd, city.lat, city.lon);
  }

  private targetLabel(): string {
    if (isSolarId(this.targetId)) {
      const b: SolarBody | null = solarBody(this.targetId);
      return b === null ? this.targetId : targetDisplayName(b.id, b.name, b.nameEn, this.englishNames);
    }
    const o: MessierObject | null = this.targetObject();
    return o === null ? '' : targetDisplayName(o.id, o.name, o.nameEn, this.englishNames);
  }

  private refreshSky(now: number, jd: number, city: City): void {
    if (now - this.lastSkyMs < 2000) {
      return;
    }
    this.lastSkyMs = now;
    this.target = this.targetHorizontalNow(jd, city);
    this.targetName = this.targetLabel();
    this.skyMarkers = [];
    for (const body of SOLAR_BODIES) {
      const h: Horizontal | null = solarHorizontal(body.id, jd, city.lat, city.lon);
      if (h !== null && h.altDeg >= 0) {
        this.skyMarkers.push({
          direction: enuVector(h.azDeg, h.altDeg),
          radius: body.id === 'MOON' ? 4 : 2.4,
          color: body.id === 'MOON' ? '#FFFFFF' : '#FFD60A',
          name: this.englishNames ? body.nameEn : body.name,
          solar: true
        });
      }
    }
    for (const star of SKY_STARS) {
      const h: Horizontal = targetHorizontal({ raHours: star.raHours, decDeg: star.decDeg }, jd, city.lat, city.lon);
      if (h.altDeg >= 0) {
        this.skyMarkers.push({
          direction: enuVector(h.azDeg, h.altDeg),
          radius: star.mag < 1.5 ? 2.2 : (star.mag < 3 ? 1.4 : 0.9),
          color: star.category === 'variable' ? '#FFD60A' : '#D8D8D8',
          name: star.mag < 2.3 && (!this.showLines || !ANCHOR_IDS.has(star.id)) ?
            targetDisplayName(star.id, star.name, star.nameEn, this.englishNames) : '',
          solar: false
        });
      }
    }
    if (this.showLines) {
      this.anchors = CONSTELLATION_STARS.map((star) => {
        const h: Horizontal = targetHorizontal(star, jd, city.lat, city.lon);
        return enuVector(h.azDeg, h.altDeg);
      });
    }
  }

  private drawCurve(c: CanvasRenderingContext2D, pose: CameraPose, pts: Vec3[],
                    color: string, width: number): void {
    c.strokeStyle = color;
    c.lineWidth = width;
    c.beginPath();
    let started: boolean = false;
    for (const point of pts) {
      const p: ProjectedPoint = projectPoint(pose, FOV, this.cw, this.ch, point);
      if (!p.insideCircle) {
        started = false;
      } else if (!started) {
        c.moveTo(p.x, p.y);
        started = true;
      } else {
        c.lineTo(p.x, p.y);
      }
    }
    c.stroke();
  }

  private drawConstellations(c: CanvasRenderingContext2D, pose: CameraPose): void {
    c.save();
    c.beginPath();
    c.arc(this.ccx, this.ccy, Math.min(this.cw, this.ch) / 2 - 16, 0, 2 * Math.PI);
    c.clip();
    c.strokeStyle = this.redMode ? '#842E28' : '#657EA6';
    c.lineWidth = 0.9;
    c.beginPath();
    for (const edge of CONSTELLATION_EDGES) {
      const segment: SkySegment | null = visibleSkySegment(this.anchors[edge[0]], this.anchors[edge[1]], pose.forward);
      if (segment !== null) {
        const a: ProjectedPoint = projectPoint(pose, FOV, this.cw, this.ch, segment.start);
        const b: ProjectedPoint = projectPoint(pose, FOV, this.cw, this.ch, segment.end);
        c.moveTo(a.x, a.y);
        c.lineTo(b.x, b.y);
      }
    }
    c.stroke();
    c.restore();

    c.fillStyle = this.redMode ? '#A0443E' : '#8096B7';
    c.beginPath();
    for (const i of ANCHORS_BY_BRIGHTNESS) {
      const star: Vec3 = this.anchors[i];
      if (star.z >= 0) {
        const p: ProjectedPoint = projectPoint(pose, FOV, this.cw, this.ch, star);
        if (p.insideCircle) {
          this.visibleAnchors.push({ x: p.x, y: p.y, star: CONSTELLATION_STARS[i] });
          c.moveTo(p.x + 0.8, p.y);
          c.arc(p.x, p.y, 0.8, 0, 2 * Math.PI);
        }
      }
    }
    c.fill();
  }

  private drawLabel(c: CanvasRenderingContext2D, name: string, x: number, y: number, size: number,
                    toLeft: boolean = false): boolean {
    c.textAlign = 'left';
    c.textBaseline = 'alphabetic';
    c.font = size.toString() + 'px sans-serif';
    const width: number = c.measureText(name).width;
    if (toLeft) {
      x -= width;
    }
    const bounds: LabelBounds = { left: x - 2, top: y - size, right: x + width + 2, bottom: y + 3 };
    const farX: number = Math.max(Math.abs(bounds.left - this.ccx), Math.abs(bounds.right - this.ccx));
    const farY: number = Math.max(Math.abs(bounds.top - this.ccy), Math.abs(bounds.bottom - this.ccy));
    const radius: number = Math.min(this.cw, this.ch) / 2 - 15;
    if (bounds.top < 53 || bounds.bottom > this.ch - 42 || farX * farX + farY * farY > radius * radius) {
      return false;
    }
    for (const other of this.labelBounds) {
      if (bounds.left < other.right && bounds.right > other.left &&
          bounds.top < other.bottom && bounds.bottom > other.top) {
        return false;
      }
    }
    c.fillText(name, x, y);
    this.labelBounds.push(bounds);
    return true;
  }

  private drawAnchorLabels(c: CanvasRenderingContext2D): void {
    c.fillStyle = this.redMode ? '#FF6B5E' : '#D1D1D6';
    let drawn: number = 0;
    for (const anchor of this.visibleAnchors) {
      if (drawn >= 12) {
        break;
      }
      const size: number = anchor.star.mag <= 2.3 ? 11 : 10;
      const name: string = this.englishNames ? anchor.star.nameEn : anchor.star.name;
      if (this.drawLabel(c, name, anchor.x + 4, anchor.y - 3, size) ||
        this.drawLabel(c, name, anchor.x - 4, anchor.y - 3, size, true)) {
        drawn++;
      }
    }
  }

  private inspectAnchor(x: number, y: number): void {
    if (!this.tracking || !this.showLines || y < 53 || y > this.ch - 42) {
      return;
    }
    let nearest: VisibleAnchor | null = null;
    let nearestDistance: number = 14 * 14;
    for (const anchor of this.visibleAnchors) {
      const dx: number = anchor.x - x;
      const dy: number = anchor.y - y;
      const distance: number = dx * dx + dy * dy;
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearest = anchor;
      }
    }
    if (nearest !== null) {
      const star: ConstellationStar = nearest.star;
      this.anchorHintStar = star;
      this.anchorHintUntil = Date.now() + 5000;
      audit('AR_STAR', star.id);
    }
  }

  private anchorCaption(star: ConstellationStar): string {
    const name: string = this.englishNames ? star.nameEn : star.name;
    return name === star.id ? star.id : name + ' · ' + star.id;
  }

  private draw(now: number, reference: boolean): void {
    const c: CanvasRenderingContext2D = this.ctx;
    const city: City = this.city();
    const jd: number = jdFromUnixMs(now);
    this.refreshSky(now, jd, city);
    const pose: CameraPose = { forward: this.cameraForward, up: this.cameraUp, right: this.cameraRight };
    c.fillStyle = '#000000';
    c.fillRect(0, 0, this.cw, this.ch);
    this.labelBounds.length = 0;
    this.visibleAnchors.length = 0;

    for (let i = 0; i < ALTITUDE_RINGS.length; i++) {
      this.drawCurve(c, pose, ALTITUDE_RINGS[i], i === 0 ? '#FF453A' : '#242424', i === 0 ? 1.5 : 1);
    }
    for (const meridian of AZIMUTH_MERIDIANS) {
      this.drawCurve(c, pose, meridian, '#202020', 1);
    }
    if (this.showLines) {
      this.drawConstellations(c, pose);
    }

    const cardinals: string[] = ['N', 'E', 'S', 'W'];
    c.fillStyle = this.p().fg;
    for (let k = 0; k < cardinals.length; k++) {
      const p: ProjectedPoint = projectPoint(pose, FOV, this.cw, this.ch, enuVector(k * 90, 0));
      if (p.insideCircle) {
        this.drawLabel(c, cardinals[k], p.x - 3, p.y - 4, 12);
      }
    }

    for (const star of this.skyMarkers) {
      const p: ProjectedPoint = projectPoint(pose, FOV, this.cw, this.ch, star.direction);
      if (p.insideCircle) {
        c.fillStyle = this.redMode ? '#FF6B5E' : star.color;
        c.beginPath();
        c.arc(p.x, p.y, star.radius, 0, 2 * Math.PI);
        c.fill();
        if (star.name !== '') {
          c.fillStyle = this.redMode ? '#FF6B5E' : '#D1D1D6';
          this.drawLabel(c, star.name, p.x + star.radius + 3, p.y - 3, star.solar ? 12 : 11);
        }
      }
    }
    this.drawAnchorLabels(c);

    // Center crosshair.
    c.strokeStyle = '#FF453A';
    c.lineWidth = 1;
    c.beginPath();
    c.moveTo(this.ccx - 8, this.ccy);
    c.lineTo(this.ccx + 8, this.ccy);
    c.moveTo(this.ccx, this.ccy - 8);
    c.lineTo(this.ccx, this.ccy + 8);
    c.stroke();

    // Target: normal marker only when in front and inside the safe circle.
    const th: Horizontal | null = this.target;
    let targetHint: string = '未选择目标';
    if (th !== null && th.altDeg < 0) {
      targetHint = `${this.targetName} · 在地平线下`;
    } else if (th !== null) {
      const tv: Vec3 = enuVector(th.azDeg, th.altDeg);
      const p: ProjectedPoint = projectPoint(pose, FOV, this.cw, this.ch, tv);
      const name: string = this.targetName;
      const sep: number = angularSepVec(tv, this.cameraForward);
      if (p.visible && p.insideCircle && sep <= FOV / 2) {
        c.strokeStyle = '#FF453A';
        c.lineWidth = 1.5;
        c.beginPath();
        c.arc(p.x, p.y, 11, 0, Math.PI * 2);
        c.stroke();
        c.beginPath();
        c.moveTo(p.x - 16, p.y);
        c.lineTo(p.x + 16, p.y);
        c.moveTo(p.x, p.y - 16);
        c.lineTo(p.x, p.y + 16);
        c.stroke();
        targetHint = sep <= 2 ? `${name} · 接近目标` : `${name} · 已进入视场`;
      } else if (!p.visible) {
        // Behind the camera: never project a fake position onto the sky.
        targetHint = `${name} · 在指向后方`;
      } else {
        // Separate edge indicator; do not mix with a normal sky position.
        const dir: Vec3 = screenDirection(p, this.cw, this.ch);
        const radius: number = Math.min(this.cw, this.ch) / 2 - 22;
        const ex: number = this.ccx + dir.x * radius;
        const ey: number = this.ccy + dir.y * radius;
        c.save();
        c.translate(ex, ey);
        c.rotate(Math.atan2(dir.y, dir.x));
        c.fillStyle = '#FF453A';
        c.beginPath();
        c.moveTo(12, 0);
        c.lineTo(-8, -8);
        c.lineTo(-8, 8);
        c.closePath();
        c.fill();
        c.restore();
        const dAz: number = shortestDelta(this.centerAz, th.azDeg);
        const dAlt: number = th.altDeg - this.centerAlt;
        const turn: string = dAz > 0 ? `右转 ${Math.abs(dAz).toFixed(0)}°` : `左转 ${Math.abs(dAz).toFixed(0)}°`;
        const lift: string = dAlt > 0 ? `抬高 ${Math.abs(dAlt).toFixed(0)}°` : `降低 ${Math.abs(dAlt).toFixed(0)}°`;
        targetHint = `${name}\n${turn} · ${lift}`;
      }
    }

    const nowDate: Date = new Date();
    const hh: number = nowDate.getHours();
    const mm: number = nowDate.getMinutes();
    const clock: string = `${hh < 10 ? '0' : ''}${hh}:${mm < 10 ? '0' : ''}${mm}`;
    const modeLabel: string = '12点';
    this.targetHint = targetHint;
    this.hint = `12 点 ${(Math.round(this.centerAz) % 360)}° · 高度 ${this.centerAlt.toFixed(0)}°` +
      (reference ? '' : ' · ROT 回退');
    if (Date.now() - this.lastTargetLogMs > 1000) {
      this.lastTargetLogMs = Date.now();
      audit('AR_POSE', `source=${reference ? 'ORI_ACC' : 'ROT'};raw=${this.oriAlpha.toFixed(2)}/` +
        `${this.accAlt.toFixed(2)};view=${this.centerAz.toFixed(2)}/${this.centerAlt.toFixed(2)};` +
        `lines=${this.showLines};anchors=${this.showLines ? this.anchors.length : 0}`);
      if (th !== null) {
        audit('AR_TARGET', `mode=${modeLabel};clock=${clock};jd=${jd.toFixed(6)};center=${this.centerAz.toFixed(1)}/` +
          `${this.centerAlt.toFixed(1)};ori=${this.oriAlpha.toFixed(2)};target=${this.targetId};az=${th.azDeg.toFixed(2)};` +
          `alt=${th.altDeg.toFixed(2)};acc=${this.accX.toFixed(2)}/${this.accY.toFixed(2)}/` +
          `${this.accZ.toFixed(2)};site=${city.name}`);
      } else {
        audit('AR_TARGET', `mode=${modeLabel};clock=${clock};jd=${jd.toFixed(6)};target=${this.targetId};target=none;` +
          `acc=${this.accX.toFixed(2)}/${this.accY.toFixed(2)}/${this.accZ.toFixed(2)};` +
          `site=${city.name}`);
      }
    }
  }

  build() {
    Stack() {
      Canvas(this.ctx)
        .width('100%')
        .height('100%')
        .onClick((event: ClickEvent) => this.inspectAnchor(event.x, event.y))
        .onReady(() => {
          this.cw = this.ctx.width > 0 ? this.ctx.width : 233;
          this.ch = this.ctx.height > 0 ? this.ctx.height : 233;
          this.ccx = this.cw / 2;
          this.ccy = this.ch / 2;
          this.ready = true;
          this.frame();
        })

      Column() {
        Row() {
          Button('← 返回')
            .fontSize(10)
            .height(26)
            .width(62)
            .padding(0)
            .backgroundColor('#1C1C1E')
            .fontColor('#FF453A')
            .onClick(() => this.onClose())
          Blank()
          Text('AR 星图')
            .fontSize(12)
            .fontColor('#FF453A')
          Blank()
          Button(this.showLines ? '连线 开' : '连线 关')
            .fontSize(9)
            .height(26)
            .width(58)
            .padding(0)
            .backgroundColor(this.showLines ? this.p().accent : this.p().card)
            .fontColor(this.showLines ? '#000000' : this.p().fg)
            .onClick(() => {
              this.showLines = !this.showLines;
              this.anchorHintStar = null;
              this.lastSkyMs = 0;
            })
        }
        .width('100%')
        .padding({ left: 30, right: 30, top: 26 })

        Blank()

        Column({ space: 2 }) {
          if (this.sightingCorrection !== 0) {
            Text('实物校准 ' + this.sightingCorrection.toFixed(1) + '° · 本次有效')
              .fontSize(8).fontColor(this.p().accent)
          }
          if (this.anchorHintStar !== null) {
            Text(this.anchorCaption(this.anchorHintStar))
              .fontSize(11)
              .fontColor(this.p().fg)
              .textAlign(TextAlign.Center)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          Text(this.targetHint)
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.targetId === '' ? this.p().fg : this.p().accent)
            .textAlign(TextAlign.Center)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          if (this.targetId === 'SUN') {
            Text('须使用合格太阳滤镜，严禁直视')
              .fontSize(9)
              .fontColor(this.p().accent)
              .textAlign(TextAlign.Center)
          }
          Row({ space: 4 }) {
            Text(this.hint)
              .fontSize(9)
              .fontColor(this.p().fg)
              .textAlign(TextAlign.Center)
              .layoutWeight(1)
            Button(this.englishNames ? '星名 EN' : '星名 中')
              .fontSize(8)
              .height(20)
              .width(43)
              .padding(0)
              .backgroundColor(this.p().card)
              .fontColor(this.p().accent)
              .onClick(() => this.onToggleNames())
          }
          .width('86%')
        }
          .width('100%')
          .padding({ left: 34, right: 34, top: 4, bottom: 17 })
          .backgroundColor('#D9000000')
      }
      .width('100%')
      .height('100%')
      .hitTestBehavior(HitTestMode.Transparent)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#000000')
  }
}
