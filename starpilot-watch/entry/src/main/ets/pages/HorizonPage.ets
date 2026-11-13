import { SECTOR_NAMES, SECTOR_COUNT, clampHeight, defaultSectors } from '../common/Horizon';
import { audit } from '../common/AuditLog';

@Component
export struct HorizonPage {
  @Prop sectors: number[] = [];
  @Prop bortle: number = 9;
  onSave: (sectors: number[], bortle: number) => void = () => {
  };
  onClose: () => void = () => {
  };

  @State local: number[] = [];
  @State selected: number = 0;
  @State bortleLocal: number = 9;
  private indices: number[] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15];

  aboutToAppear(): void {
    this.local = [];
    if (this.sectors.length === SECTOR_COUNT) {
      for (let i = 0; i < this.sectors.length; i++) {
        this.local.push(clampHeight(this.sectors[i]));
      }
    } else {
      this.local = defaultSectors();
    }
    this.bortleLocal = Math.max(1, Math.min(9, this.bortle));
  }

  private barHeight(h: number): number {
    return 8 + h / 90 * 44;
  }

  private adjust(delta: number): void {
    const copy: number[] = [];
    for (let i = 0; i < this.local.length; i++) {
      copy.push(this.local[i]);
    }
    copy[this.selected] = clampHeight(copy[this.selected] + delta);
    this.local = copy;
    audit('HORIZON', `${SECTOR_NAMES[this.selected]}=${this.local[this.selected]}`);
  }

  private adjustBortle(delta: number): void {
    this.bortleLocal = Math.max(1, Math.min(9, this.bortleLocal + delta));
  }

  private save(): void {
    const copy: number[] = [];
    for (let i = 0; i < this.local.length; i++) {
      copy.push(this.local[i]);
    }
    audit('HORIZON_SAVE', `bortle=${this.bortleLocal};${copy.join(',')}`);
    this.onSave(copy, this.bortleLocal);
  }

  build() {
    Scroll() {
      Column({ space: 4 }) {
        Row() {
          Button('← 返回')
            .fontSize(9)
            .height(22)
            .backgroundColor('#1C1C1E')
            .fontColor('#FF453A')
            .onClick(() => this.onClose())
          Blank()
          Text('阳台遮挡')
            .fontSize(9)
            .fontColor('#8E8E93')
        }
        .width('100%')

        Text('方位 0°=北，顺时针；每个扇区 22.5°')
          .fontSize(7)
          .fontColor('#8E8E93')
          .width('100%')

        Row({ space: 2 }) {
          ForEach(this.indices, (i: number) => {
            Column() {
              Row()
                .width('70%')
                .height(this.barHeight(this.local[i]))
                .backgroundColor(i === this.selected ? '#FF453A' : '#5A1A16')
                .borderRadius(2)
            }
            .height(56)
            .layoutWeight(1)
            .justifyContent(FlexAlign.End)
            .onClick(() => {
              this.selected = i;
            })
          }, (i: number) => i.toString())
        }
        .width('100%')
        .height(58)

        Row({ space: 10 }) {
          Text('◀')
            .fontSize(16)
            .fontColor('#FF5A4E')
            .width(40)
            .height(28)
            .textAlign(TextAlign.Center)
            .backgroundColor('#1C1C1E')
            .borderRadius(6)
            .onClick(() => {
              this.selected = (this.selected + SECTOR_COUNT - 1) % SECTOR_COUNT;
            })
          Text(`${SECTOR_NAMES[this.selected]} ${this.local[this.selected]}°`)
            .fontSize(14)
            .fontColor('#FF5A4E')
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
          Text('▶')
            .fontSize(16)
            .fontColor('#FF5A4E')
            .width(40)
            .height(28)
            .textAlign(TextAlign.Center)
            .backgroundColor('#1C1C1E')
            .borderRadius(6)
            .onClick(() => {
              this.selected = (this.selected + 1) % SECTOR_COUNT;
            })
        }
        .width('100%')

        Row({ space: 6 }) {
          Button('-5°')
            .fontSize(10)
            .height(26)
            .layoutWeight(1)
            .backgroundColor('#1C1C1E')
            .onClick(() => this.adjust(-5))
          Button('+5°')
            .fontSize(10)
            .height(26)
            .layoutWeight(1)
            .backgroundColor('#1C1C1E')
            .onClick(() => this.adjust(5))
        }
        .width('100%')

        Row({ space: 6 }) {
          Text('Bortle')
            .fontSize(9)
            .fontColor('#8E8E93')
            .width(46)
          Text('-')
            .fontSize(16)
            .fontColor('#FF5A4E')
            .width(36)
            .height(28)
            .textAlign(TextAlign.Center)
            .backgroundColor('#1C1C1E')
            .borderRadius(6)
            .onClick(() => this.adjustBortle(-1))
          Text(`${this.bortleLocal}`)
            .fontSize(14)
            .fontColor('#FF5A4E')
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
          Text('+')
            .fontSize(16)
            .fontColor('#FF5A4E')
            .width(36)
            .height(28)
            .textAlign(TextAlign.Center)
            .backgroundColor('#1C1C1E')
            .borderRadius(6)
            .onClick(() => this.adjustBortle(1))
        }
        .width('100%')

        Button('保存遮挡')
          .fontSize(10)
          .height(28)
          .width('100%')
          .backgroundColor('#FF453A')
          .fontColor('#000000')
          .onClick(() => this.save())

        Text('示例：北向 30° = 前方建筑遮挡到 30° 高度')
          .fontSize(7)
          .fontColor('#8E8E93')
          .width('100%')
        Text(' ')
          .height(6)
      }
      .width('100%')
      .padding({ left: 36, right: 36, top: 34, bottom: 18 })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .backgroundColor('#000000')
  }
}
