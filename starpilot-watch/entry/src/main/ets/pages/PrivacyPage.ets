import { util } from '@kit.ArkTS';
import { palette, Palette } from '../common/Theme';

const POLICY: string = '版本 1 · 2026-11-10\n\n' +
  'StarPilot 在手表上提供离线观星和摄影计算。首次可选择开启城市天气或仅离线使用，之后可在主页「隐私」更改。\n\n' +
  '城市天气开启后，应用会通过 HTTPS 向 Open-Meteo 和 7Timer 发送所选城市的目录经纬度，用于天气和天文预报。服务端可看到请求的网络 IP；服务可能在境外处理。天气城市可单独修改。关闭后停止请求。\n\n' +
  'GPS 定位需要单独同意和系统权限。精确位置可能暴露观测地点，按敏感位置处理。每次点按获取一次，最新位置保存在手表，用于本地天文计算。天气使用独立城市，GPS 坐标留在手表。可在此撤回并清除位置，也可在系统设置撤回权限。\n\n' +
  '调试版。正式发布者及隐私联系渠道待发布时公示。';
const COLLECTION: string = 'GPS 定位（可选）\n经纬度、海拔、定位精度和定位时间。最新一组保存在手表，撤回时清除。旧版无时间的记录需重新定位。\n\n' +
  '城市天气（可选）\n所选城市目录经纬度与预报请求参数发往两家天气服务。服务可看到网络 IP。天气结果和城市设置在手表缓存，按后续更新覆盖。\n\n' +
  '设备与操作\nAR 和导航按需在手表使用姿态传感器。电量用于主页显示，震动用于提醒。偏好、观测记录和导入的 ISS 元素保存在手表。应用未接入广告或统计 SDK。调试日志保留功能状态。';
const SERVICES: string = 'Open-Meteo（OpenMeteo GmbH）\nHTTPS 天气 API，使用城市经纬度获取云量、温湿度、风速和降水概率。\nopen-meteo.com/en/terms\n\n' +
  '7Timer\nHTTPS ASTRO API，使用城市经纬度获取云量、视宁度和透明度预报。公开 API 文档提供请求说明，服务端保留期限未核实。\nwww.7timer.info/doc.php?lang=en\n\n' +
  'HarmonyOS 系统能力\n位置服务（按需定位）、网络服务（天气请求与链路检测）、传感器与震动、存储和电量。使用系统能力按各功能执行。\n\n' +
  '本地依赖\nsatellite.js 的 SGP4 算法移植及各离线星表仅在手表本地使用，详见开源许可。';
const CREDITS: string = 'OpenNGC · Mattia Verga\nCC BY-SA 4.0。用于深空目标数据，已筛选、转换并合并别名。\ngithub.com/mattiaverga/OpenNGC\n\n' +
  'HYG Database · David Nash / Astronexus\nHYG v3.5 的恒星坐标、星等和标识，已筛选并匹配。衍生星表按 CC BY-SA 4.0 分发。\ngithub.com/astronexus/HYG-Database\n\n' +
  'Stellarium Modern / Chinese\nCC BY-SA 4.0。现代星座线段由 Stellarium 团队提供，中文星名由 Karrie Berglund 和 Sun Shuwei 贡献，已按 HIP 号匹配和去重。\ngithub.com/Stellarium/stellarium\n\n' +
  'CC BY-SA 4.0 许可\ncreativecommons.org/licenses/by-sa/4.0/\n\n' +
  'Caldwell 元数据 · Paul Spinelli（Astro Catalogue Viewer）· MIT\ngithub.com/thebioguy/Astro-Catalogue-Viewer\n\n' +
  'satellite.js 6.0.1 · Shashwat Kandadai / UCSC Jack Baskin School of Engineering · MIT\n已移植近地 SGP4 到 ArkTS。\ngithub.com/shashwatak/satellite-js\n\n' +
  '流星雨参数来源\nInternational Meteor Organization (IMO)，2026/2027 年历。www.imo.net';

@Component
export struct PrivacyPage {
  @Prop first: boolean = false;
  @Prop weatherAllowed: boolean = false;
  @Prop gpsAllowed: boolean = false;
  @Prop city: string = '';
  @Prop redMode: boolean = false;
  onWeatherChoice: (allowed: boolean) => boolean = () => false;
  onClearGps: () => boolean = () => false;
  onChooseCity: () => void = () => {};
  onClose: () => void = () => {};
  @State section: number = 0;
  @State license: string = '';
  @State confirmClear: boolean = false;
  @State notice: string = '';
  private scroller: Scroller = new Scroller();
  private resetTimer: number = -1;

  aboutToDisappear(): void {
    clearTimeout(this.resetTimer);
  }

  private p(): Palette {
    return palette(this.redMode);
  }

  private openSection(section: number): void {
    this.section = section;
    clearTimeout(this.resetTimer);
    this.resetTimer = setTimeout((): void => {
      this.scroller.scrollTo({ xOffset: 0, yOffset: 0 });
    }, 120);
  }

  private showLicense(file: string, section: number): void {
    try {
      const ctx = this.getUIContext().getHostContext();
      if (ctx !== undefined) {
        this.license = util.TextDecoder.create('utf-8').decodeToString(ctx.resourceManager.getRawFileContentSync(file));
        this.openSection(section);
      }
    } catch (err) {
      this.notice = '许可文本暂不可读';
    }
  }

  @Builder
  Key(title: string, action: () => void) {
    Button(title).height(25).width('100%').padding(0).fontSize(9)
      .fontColor(this.p().fg).backgroundColor(this.p().card).onClick(action)
  }

  @Builder
  Paragraph(value: string) {
    Text(value).fontSize(9).lineHeight(14).fontColor(this.p().fg).width('100%')
  }

  build() {
    Column() {
      Row() {
        if (this.section !== 0 || !this.first) {
          Button('返回').height(24).width(42).padding(0).fontSize(9)
            .backgroundColor(this.p().card).fontColor(this.p().accent)
            .onClick(() => {
              if (this.section === 0) {
                this.onClose();
              } else {
                this.openSection(this.section >= 5 ? 4 : 0);
              }
            })
        } else {
          Blank().width(42)
        }
        Text(['隐私与许可', '隐私政策', '收集清单', '第三方 API', '开源许可', 'Caldwell MIT', 'satellite.js MIT'][this.section])
          .fontSize(11).fontColor(this.p().accent).layoutWeight(1).textAlign(TextAlign.Center)
        Blank().width(42)
      }.width('100%').padding({ left: 33, right: 33, top: 26, bottom: 4 })
      Scroll(this.scroller) {
        Column({ space: 5 }) {
          if (this.section === 0) {
            Text('离线工具可直接使用。城市天气会把城市目录坐标发送给 Open-Meteo 和 7Timer。GPS 另行授权，位置只保存在手表。')
              .fontSize(9).fontColor(this.p().fg).textAlign(TextAlign.Center)
            Text('天气城市 · ' + this.city).fontSize(9).fontColor(this.p().accent)
            Button(this.first ? '同意并开启城市天气' : (this.weatherAllowed ? '关闭城市天气' : '开启城市天气'))
              .height(25).width('100%').fontSize(9).fontColor(this.p().fg).backgroundColor(this.p().card)
              .onClick(() => {
                this.notice = this.onWeatherChoice(this.first || !this.weatherAllowed) ? '' : '无法保存选择，请重试';
              })
            if (this.first) {
              this.Key('仅离线使用', () => {
                this.notice = this.onWeatherChoice(false) ? '' : '无法保存选择，请重试';
              })
            } else {
              this.Key('更改天气城市', this.onChooseCity)
            }
            this.Key('隐私政策', () => this.openSection(1))
            this.Key('个人信息收集清单', () => this.openSection(2))
            this.Key('第三方 SDK / API 清单', () => this.openSection(3))
            this.Key('开源许可与数据署名', () => this.openSection(4))
            if (!this.first) {
              Text(this.gpsAllowed ? 'GPS 本地授权已开启' : 'GPS 本地授权未开启')
                .fontSize(9).fontColor(this.p().fg)
              if (this.confirmClear) {
                this.Key('确认撤回并清除位置', () => {
                  const ok: boolean = this.onClearGps();
                  this.confirmClear = false;
                  this.notice = ok ? '已撤回并清除 GPS 位置' : '无法保存更改，请重试';
                })
                this.Key('取消', () => { this.confirmClear = false; })
              } else {
                this.Key('撤回并清除 GPS 位置', () => { this.confirmClear = true; })
              }
            }
          } else if (this.section === 1) {
            this.Paragraph(POLICY)
          } else if (this.section === 2) {
            this.Paragraph(COLLECTION)
          } else if (this.section === 3) {
            this.Paragraph(SERVICES)
          } else if (this.section === 4) {
            this.Key('查看 Caldwell MIT 全文', () => this.showLicense('caldwell-mit-license.txt', 5))
            this.Key('查看 satellite.js MIT 全文', () => this.showLicense('satellite-js-license.txt', 6))
            this.Paragraph(CREDITS)
          } else {
            Text(this.license).fontSize(9).lineHeight(13).fontColor(this.p().fg).width('100%')
          }
          if (this.notice !== '') {
            Text(this.notice).fontSize(9).fontColor(this.p().accent)
          }
        }.width('100%').padding({ left: 35, right: 35, bottom: 28 })
      }.width('100%').layoutWeight(1).align(Alignment.Top).scrollBar(BarState.Off)
    }.width('100%').height('100%').backgroundColor(this.p().bg)
  }
}
