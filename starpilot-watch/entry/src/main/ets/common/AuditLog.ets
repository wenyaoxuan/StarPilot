import { hilog } from '@kit.PerformanceAnalysisKit';

/**
 * Every audit line is written with a fixed tag so the whole S0 session can be
 * captured on a PC with:
 *   hdc hilog | grep StarPilotAudit
 */
export function audit(tag: string, payload: string): void {
  hilog.info(0x0000, 'StarPilotAudit', '%{public}s|%{public}s', tag, payload);
}
