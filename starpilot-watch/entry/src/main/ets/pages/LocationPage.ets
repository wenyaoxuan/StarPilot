import { CITIES, City, GPS_CITY_REGION } from '../data/Cities';
import { palette, Palette } from '../common/Theme';
import { common } from '@kit.AbilityKit';
import { GpsFix, getGpsFix } from '../common/GeoLocation';
import { audit } from '../common/AuditLog';

interface LocRow {
  header: boolean;
  label: string;
  sub: string;
  index: number;
}

@Component
export struct LocationPage {
  @Prop redMode: boolean = false;
  @Prop weatherOnly: boolean = false;
  @Prop gpsAllowed: boolean = false;
  @Prop gpsTimestamp: number = 0;
  @Prop @Watch('onCityChanged') cityIndex: number = 0;
  onSelect: (index: number) => void = () => {
  };
  onGpsFix: (lat: number, lon: number, alt: number, accuracy: number, timestamp: number) => void = () => {
  };
  onClose: () => void = () => {
  };
  onAllowGps: () => boolean = () => false;

  @State region: string = '全部';
  @State rows: LocRow[] = [];
  @State gpsBusy: boolean = false;
  @State gpsStatus: string = '一次性定位，不持续耗电';
  @State showGpsNotice: boolean = false;
  private visible: boolean = false;

  private p(): Palette {
    return palette(this.redMode);
  }

  aboutToAppear(): void {
    this.visible = true;
    if (this.cityIndex >= 0 && this.cityIndex < CITIES.length) {
      const cur: City = CITIES[this.cityIndex];
      this.region = cur.region === GPS_CITY_REGION ? GPS_CITY_REGION : cur.region;
      if (cur.region === GPS_CITY_REGION) {
        this.gpsStatus = this.savedGpsStatus();
      }
    }
    this.rebuildRows();
  }

  private savedGpsStatus(): string {
    if (!Number.isFinite(this.gpsTimestamp) || this.gpsTimestamp <= 0) {
      return '上次 GPS · 时间未知，请重新定位';
    }
    const time: Date = new Date(this.gpsTimestamp);
    const hour: string = time.getHours().toString().padStart(2, '0');
    const minute: string = time.getMinutes().toString().padStart(2, '0');
    return `上次 GPS · ${time.getMonth() + 1}/${time.getDate()} ${hour}:${minute}`;
  }

  aboutToDisappear(): void {
    this.visible = false;
  }

  private onCityChanged(): void {
    if (this.cityIndex >= 0 && this.cityIndex < CITIES.length) {
      const cur: City = CITIES[this.cityIndex];
      this.region = cur.region === GPS_CITY_REGION ? GPS_CITY_REGION : cur.region;
    }
    this.rebuildRows();
  }

  private async locate(): Promise<void> {
    if (this.gpsBusy) {
      return;
    }
    this.gpsBusy = true;
    this.gpsStatus = '请求定位权限…';
    try {
      const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
      if (ctx === undefined) {
        throw new Error('无应用上下文');
      }
      const fix: GpsFix = await getGpsFix(ctx, (text: string) => { this.gpsStatus = text; });
      if (!this.visible) {
        return;
      }
      const accuracy: string = fix.accuracy > 0 ? `±${Math.round(fix.accuracy)}m` : '精度未知';
      this.gpsStatus = `${fix.latitude.toFixed(4)}, ${fix.longitude.toFixed(4)} · ${accuracy}`;
      this.onGpsFix(fix.latitude, fix.longitude, fix.altitude, fix.accuracy, fix.timestamp);
      this.rebuildRows();
      audit('GPS_FIX', 'one-shot location received');
    } catch (err) {
      let msg: string = '未知错误';
      if (err instanceof Error) {
        msg = err.message;
      } else {
        msg = JSON.stringify(err);
      }
      this.gpsStatus = msg;
      audit('GPS_ERR', 'location unavailable');
    } finally {
      this.gpsBusy = false;
    }
  }

  private rebuildRows(): void {
    const out: LocRow[] = [];
    let lastCountry: string = '';
    for (let i = 0; i < CITIES.length; i++) {
      const c: City = CITIES[i];
      if (this.weatherOnly && c.region === GPS_CITY_REGION) {
        continue;
      }
      if (this.region !== '全部' && c.region !== this.region) {
        continue;
      }
      if (c.country !== lastCountry) {
        lastCountry = c.country;
        const h: LocRow = { header: true, label: c.country, sub: '', index: -1 };
        out.push(h);
      }
      const gps: boolean = c.region === GPS_CITY_REGION;
      const r: LocRow = {
        header: false,
        label: gps ? '上次 GPS' : c.name,
        sub: gps ? `${c.lat.toFixed(4)}, ${c.lon.toFixed(4)}` :
          `${c.lat.toFixed(1)}, ${c.lon.toFixed(1)} · B${c.bortle}`,
        index: i
      };
      out.push(r);
    }
    this.rows = out;
  }

  private selectRegion(key: string): void {
    if (this.region === key) {
      return;
    }
    this.region = key;
    this.rebuildRows();
  }

  @Builder
  RegionChipView(key: string, label: string) {
    Text(label)
      .fontSize(7)
      .fontColor(this.region === key ? '#000000' : this.p().dim)
      .height(20)
      .padding({ left: 8, right: 8 })
      .backgroundColor(this.region === key ? this.p().accent : this.p().card)
      .borderRadius(10)
      .textAlign(TextAlign.Center)
      .onClick(() => this.selectRegion(key))
  }

  build() {
    if (this.showGpsNotice) {
      Scroll() {
        Column({ space: 8 }) {
          Text('单独同意 · GPS 定位').fontSize(12).fontColor(this.p().accent)
          Text('精确位置可能暴露观测地点。经纬度、海拔用于本地观星计算，精度和定位时间随最新位置保存在手表。天气使用城市坐标。')
            .fontSize(10).fontColor(this.p().fg).textAlign(TextAlign.Center)
          Text('可以手动选城市。可在「隐私」撤回并清除保存的位置。').fontSize(9).fontColor(this.p().fg)
          Button('单独同意并定位').fontSize(9).height(25).width('100%')
            .fontColor(this.p().fg).backgroundColor(this.p().card).onClick(() => {
              if (this.onAllowGps()) {
                this.showGpsNotice = false;
                this.locate();
              } else {
                this.gpsStatus = '无法保存同意，请重试';
              }
            })
          Button('暂不允许').fontSize(9).height(25).width('100%')
            .fontColor(this.p().fg).backgroundColor(this.p().card).onClick(() => { this.showGpsNotice = false; })
          if (this.gpsStatus === '无法保存同意，请重试') {
            Text(this.gpsStatus).fontSize(8).fontColor(this.p().accent)
          }
        }.width('100%').padding({ left: 35, right: 35, top: 30, bottom: 22 })
      }.width('100%').height('100%').backgroundColor(this.p().bg).scrollBar(BarState.Off)
    } else {
    Column() {
      Row() {
        Button('← 返回')
          .fontSize(9)
          .height(26)
          .width(66)
          .backgroundColor(this.p().card)
          .fontColor(this.p().accent)
          .onClick(() => this.onClose())
        Blank()
        Text(this.weatherOnly ? '选择天气城市' : '观测位置')
          .fontSize(10)
          .fontColor(this.p().fg)
        Blank()
        Text(' ')
          .width(40)
      }
      .width('100%')
      .height(30)
      .padding({ left: 36, right: 36 })
      .margin({ top: 26 })

      if (!this.weatherOnly) {
      Row({ space: 6 }) {
        Button(this.gpsBusy ? '定位中…' : 'GPS 定位')
          .fontSize(8)
          .height(26)
          .width(82)
          .backgroundColor(this.p().card)
          .fontColor(this.p().accent)
          .enabled(!this.gpsBusy)
          .onClick(() => {
            if (this.gpsAllowed) {
              this.locate();
            } else {
              this.showGpsNotice = true;
            }
          })
        Text(this.gpsStatus)
          .fontSize(8)
          .fontColor(this.p().dim)
          .layoutWeight(1)
          .maxLines(3)
          .textAlign(TextAlign.Start)
      }
      .width('100%')
      .padding({ left: 36, right: 36, top: 2, bottom: 2 })

      Text('时间按手表时区显示 · 手动城市或 GPS')
        .fontSize(7)
        .fontColor(this.p().dim)
        .width('100%')
        .padding({ left: 36, right: 36, bottom: 2 })
      }

      Row({ space: 3 }) {
        this.RegionChipView('全部', '全部')
        this.RegionChipView('中国', '中国')
        this.RegionChipView('亚洲', '亚洲')
        this.RegionChipView('欧洲', '欧洲')
      }
      .width('100%')
      .padding({ left: 36, right: 36, bottom: 2 })

      Row({ space: 3 }) {
        this.RegionChipView('美洲', '美洲')
        this.RegionChipView('大洋洲', '大洋洲')
        this.RegionChipView('非洲', '非洲')
        if (!this.weatherOnly) {
          this.RegionChipView(GPS_CITY_REGION, '定位')
        }
      }
      .width('100%')
      .padding({ left: 36, right: 36, bottom: 3 })

      List({ space: 2 }) {
        ForEach(this.rows, (r: LocRow) => {
          ListItem() {
            if (r.header) {
              Text(r.label)
                .fontSize(9)
                .fontColor(this.p().accent)
                .width('100%')
                .padding({ left: 4, top: 4, bottom: 2 })
            } else {
              Row() {
                Text(r.label)
                  .fontSize(10)
                  .fontColor(r.index === this.cityIndex ? this.p().accent : this.p().fg)
                Blank()
                Text(r.sub)
                  .fontSize(7)
                  .fontColor(this.p().dim)
                if (r.index === this.cityIndex) {
                  Text(' ✓')
                    .fontSize(9)
                    .fontColor(this.p().accent)
                }
              }
              .width('100%')
              .height(30)
              .padding({ left: 8, right: 8 })
              .backgroundColor(r.index === this.cityIndex ? this.p().card : '#000000')
              .borderRadius(6)
              .onClick(() => {
                this.visible = false;
                this.onSelect(r.index);
              })
            }
          }
        }, (r: LocRow) => `${r.header ? 'h' : 'c'}_${r.index}_${r.label}`)
      }
      .width('100%')
      .layoutWeight(1)
      .padding({ left: 32, right: 32 })
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#000000')
    }
  }
}
