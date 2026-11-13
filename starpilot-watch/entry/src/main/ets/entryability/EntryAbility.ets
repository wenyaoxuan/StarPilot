import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';

const DOMAIN: number = 0x0000;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
    } catch (err) {
      hilog.error(DOMAIN, 'StarPilotAudit', 'setColorMode failed: %{public}s', JSON.stringify(err));
    }
    hilog.info(DOMAIN, 'StarPilotAudit', 'ABILITY_CREATE');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'StarPilotAudit', 'ABILITY_DESTROY');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'StarPilotAudit', 'loadContent failed: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'StarPilotAudit', 'PAGE_LOADED');
    });
  }
}
