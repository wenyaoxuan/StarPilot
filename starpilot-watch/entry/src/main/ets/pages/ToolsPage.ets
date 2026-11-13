import { vibrator } from '@kit.SensorServiceKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { preferences } from '@kit.ArkData';
import { connection } from '@kit.NetworkKit';
import { audit } from '../common/AuditLog';

@Component
export struct ToolsPage {
  @State vibResult: string = '--';
  @State storageValue: string = '--';
  @State netResult: string = '--';
  @State crown: number = 0;
  @State remaining: number = 600;
  @State running: boolean = false;
  @State finishAt: string = '--';
  @State timerNote: string = '--';

  private timerId: number = -1;
  private store: preferences.Preferences | null = null;

  aboutToAppear(): void {
    try {
      const ctx = this.getUIContext().getHostContext();
      if (ctx !== undefined) {
        this.store = preferences.getPreferencesSync(ctx, { name: 'starpilot_s0' });
        this.storageValue = `${this.store.getSync('storage_probe', 0)}`;
        this.crown = this.store.getSync('crown_probe', 0) as number;
      }
    } catch (err) {
      this.storageValue = `prefs err ${JSON.stringify(err)}`;
    }
  }

  aboutToDisappear(): void {
    this.stopTimer();
  }

  private vibratePreset(effectId: string): void {
    try {
      vibrator.isSupportEffect(effectId, (err: BusinessError, state: boolean) => {
        if (err) {
          this.vibResult = `query ${effectId}: ${err.code}，回退 time`;
          audit('VIBRATE', `query ${effectId} err ${err.code} -> time`);
          this.vibrateTime(600);
          return;
        }
        if (!state) {
          this.vibResult = `${effectId} 不支持，回退 time`;
          audit('VIBRATE', `${effectId} unsupported -> time`);
          this.vibrateTime(600);
          return;
        }
        try {
          vibrator.startVibration({
            type: 'preset',
            effectId: effectId,
            count: 1
          }, { usage: 'notification' }, (e: BusinessError) => {
            if (e) {
              this.vibResult = `start ${effectId}: ${e.code}，回退 time`;
              audit('VIBRATE', `start ${effectId} err ${e.code} -> time`);
              this.vibrateTime(600);
            } else {
              this.vibResult = `ok ${effectId}`;
              audit('VIBRATE', `ok ${effectId}`);
            }
          });
        } catch (e2) {
          this.vibResult = `throw ${JSON.stringify(e2)}`;
        }
      });
    } catch (err) {
      this.vibResult = `throw ${JSON.stringify(err)}`;
    }
  }

  private vibrateTime(ms: number): void {
    try {
      vibrator.startVibration({ type: 'time', duration: ms }, { usage: 'notification' },
        (e: BusinessError) => {
          if (e) {
            this.vibResult = `time ${ms}: ${e.code}`;
            audit('VIBRATE', `time ${ms} err ${e.code}`);
          } else {
            this.vibResult = `ok time ${ms}ms`;
            audit('VIBRATE', `time ${ms} ok`);
          }
        });
    } catch (err) {
      this.vibResult = `time throw ${JSON.stringify(err)}`;
    }
  }

  private storageTest(): void {
    try {
      let store: preferences.Preferences | null = this.store;
      if (store === null) {
        const ctx = this.getUIContext().getHostContext();
        if (ctx === undefined) {
          this.storageValue = 'no context';
          return;
        }
        store = preferences.getPreferencesSync(ctx, { name: 'starpilot_s0' });
        this.store = store;
      }
      const prev: number = store.getSync('storage_probe', 0) as number;
      const next: number = prev + 1;
      store.putSync('storage_probe', next);
      store.flush();
      this.storageValue = `${next}`;
      audit('STORAGE', `write=${next}`);
    } catch (err) {
      this.storageValue = `err ${JSON.stringify(err)}`;
      audit('STORAGE', `err ${JSON.stringify(err)}`);
    }
  }

  private async checkNetwork(): Promise<void> {
    this.netResult = '查询中…';
    try {
      const net: connection.NetHandle = await connection.getDefaultNet();
      this.netResult = net.netId > 0 ? '系统有默认网络' : '系统无默认网络';
    } catch (err) {
      this.netResult = '网络状态暂不可读';
    }
  }

  private saveCrown(): void {
    try {
      if (this.store !== null) {
        this.store.putSync('crown_probe', this.crown);
        this.store.flush();
      }
    } catch (err) {
      audit('CROWN', `save err ${JSON.stringify(err)}`);
    }
  }

  private startTimer(seconds: number): void {
    this.stopTimer();
    this.remaining = seconds;
    this.running = true;
    const end: Date = new Date(Date.now() + seconds * 1000);
    this.finishAt = `${end.getHours()}:${end.getMinutes() < 10 ? '0' : ''}${end.getMinutes()}`;
    this.timerNote = `开始 ${seconds}s，结束于 ${this.finishAt}`;
    audit('TIMER', `start=${seconds}s finishAt=${this.finishAt}`);
    this.timerId = setInterval(() => {
      this.remaining--;
      if (this.remaining <= 0) {
        this.remaining = 0;
        this.running = false;
        this.clearTimerHandle();
        this.timerNote = '计时结束，振动中';
        audit('TIMER', `done at ${new Date().toISOString()}`);
        this.vibratePreset('haptic.notice.success');
      }
    }, 1000);
  }

  private clearTimerHandle(): void {
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  private stopTimer(): void {
    this.clearTimerHandle();
    if (this.running) {
      this.running = false;
      this.timerNote = '已手动停止';
      audit('TIMER', `stopped at ${this.remaining}s`);
    }
  }

  private fmt(sec: number): string {
    const m: number = Math.floor(sec / 60);
    const s: number = sec % 60;
    return `${m < 10 ? '0' : ''}${m}:${s < 10 ? '0' : ''}${s}`;
  }

  private dumpAll(): void {
    audit('TOOLS', `vib=${this.vibResult};storage=${this.storageValue};net=${this.netResult};` +
      `crown=${this.crown};remaining=${this.remaining};finishAt=${this.finishAt}`);
  }

  build() {
    Scroll() {
      Column({ space: 5 }) {
        Text('执行器 / 存储 / 网络')
          .fontSize(12)
          .fontColor('#FF453A')
          .fontWeight(FontWeight.Bold)

        Text(`振动: ${this.vibResult}`)
          .fontSize(9)
          .fontColor('#FFD60A')
          .width('100%')
        Row({ space: 6 }) {
          Button('通知')
            .fontSize(10)
            .height(26)
            .backgroundColor('#1C1C1E')
            .onClick(() => this.vibratePreset('haptic.notice.success'))
          Button('300ms')
            .fontSize(10)
            .height(26)
            .backgroundColor('#1C1C1E')
            .onClick(() => this.vibrateTime(300))
          Button('1s')
            .fontSize(10)
            .height(26)
            .backgroundColor('#1C1C1E')
            .onClick(() => this.vibrateTime(1000))
        }

        Text(`存储: ${this.storageValue}`)
          .fontSize(9)
          .fontColor('#C7C7CC')
          .width('100%')
          .margin({ top: 4 })
        Button('写入并重启后核对')
          .fontSize(10)
          .height(26)
          .backgroundColor('#1C1C1E')
          .onClick(() => this.storageTest())

        Text(`网络: ${this.netResult}`)
          .fontSize(9)
          .fontColor('#C7C7CC')
          .width('100%')
          .margin({ top: 4 })
        Button('检查本机网络状态')
          .fontSize(10)
          .height(26)
          .backgroundColor('#1C1C1E')
          .onClick(() => { this.checkNetwork(); })

        Text(`表冠: ${this.crown}  (点我后旋转)`)
          .fontSize(10)
          .fontColor('#30D158')
          .width('100%')
          .margin({ top: 6 })
          .padding(4)
          .focusable(true)
          .focusOnTouch(true)
          .onDigitalCrown((event: CrownEvent) => {
            if (event.action === CrownAction.UPDATE) {
              this.crown += Math.round(event.degree);
            }
            if (event.action === CrownAction.END) {
              this.saveCrown();
            }
          })

        Text(`计时 ${this.fmt(this.remaining)}  ${this.running ? '运行中' : ''}`)
          .fontSize(12)
          .fontColor('#FFFFFF')
          .width('100%')
          .margin({ top: 6 })
        Row({ space: 6 }) {
          Button('10min')
            .fontSize(10)
            .height(26)
            .backgroundColor('#1C1C1E')
            .onClick(() => this.startTimer(600))
          Button('1min')
            .fontSize(10)
            .height(26)
            .backgroundColor('#1C1C1E')
            .onClick(() => this.startTimer(60))
          Button('停')
            .fontSize(10)
            .height(26)
            .backgroundColor('#1C1C1E')
            .fontColor('#FF453A')
            .onClick(() => this.stopTimer())
        }
        Text(this.timerNote)
          .fontSize(8)
          .fontColor('#8E8E93')
          .width('100%')

        Button('输出工具日志')
          .fontSize(10)
          .height(26)
          .backgroundColor('#1C1C1E')
          .fontColor('#FF453A')
          .margin({ top: 4 })
          .onClick(() => this.dumpAll())

        Text(' ')
          .height(8)
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
