# StarPilot EXP-01 E1 深空取景模拟

2026-11-09，Asia/Shanghai。设备为 HUAWEI WATCH 5 46 mm（RTS-AL00），HarmonyOS 6.1.0.333，API 23，466 × 466。

## 使用方法

左滑到「天体目录」，打开星云、星系或星团的详情，点「取景模拟」。选择 Sony A7R IV（35.7 × 23.8 mm）或输入自定义传感器宽高，选 20/35/50/85/100/135/200 mm 或输入焦距，再点「预览画幅」。「构图」里可切换横竖幅，以 15° 为步长旋转，以画幅宽或高的四分之一为步长移动中心，或恢复目标居中。传感器尺寸输入范围为 1–100 mm，焦距为 1–3000 mm。预览沿用目录的中英文星名设置和主页红光主题。参数随本次取景会话保留。[Sony 官方规格](https://www.sony.com/electronics/support/e-mount-body-ilce-7-series/ilce-7rm4/specifications)

## 算法与数据

- 每个轴的视场为 `2 × atan(传感器轴长 / (2 × 焦距))`，结果以度显示。画框按物理传感器比例绘制。恒星、目标中心和尺寸环使用同一 J2000 球面切平面和旋转，画面上方向从天球北向东计角。投影裁切到画框内，目标中心出框时明确标注。[TAN 投影参考](https://arxiv.org/abs/astro-ph/0207407)
- 复用应用已有天体目录与恒星数据，绘制星点和目标中心。目录未提供位置角时，用无方向的虚线参考环标出可用长短轴尺寸。角尺寸未知时只标中心。取景为几何预览。任一轴视场超过 120° 时标注广角畸变未模拟。
- E1 无新增网络调用、设备权限、后台任务或持久缓存。进入预览时才绘制星点和参考环。

## 验证

`node tools/photo-test/verify_framing.mjs` 直接转译当前 ArkTS 数学核心，核对三档视场、横竖交换、自定义尺寸和焦距、RA 0h 两侧、高赤纬、画框边缘、背面拒绝、旋转及角尺寸。原摄影数学与画幅脚本也均通过。

| A7R IV 横幅焦距 | 独立视场参考值 | Watch 5 截图 |
| --- | --- | --- |
| 85 mm | 23.72° × 15.94° | [M31 · 85 mm](s0-results/exp_e1_m31_85_20261109.jpeg) |
| 135 mm | 15.06° × 10.07° | [M31 · 135 mm](s0-results/exp_e1_m31_135_20261109.jpeg) |
| 200 mm | 10.20° × 6.81° | [M31 · 200 mm](s0-results/exp_e1_m31_200_20261109.jpeg) |

- M31 可从详情打开取景设置，关闭取景后回到同一目标详情。真机横幅显示完整 3:2 边框，焦距增加时视场收窄，参考环在画框内占比增大。[入口](s0-results/exp_e1_m31_detail_20261109.jpeg) · [设置](s0-results/exp_e1_m31_setup_20261109.jpeg) · [返回](s0-results/exp_e1_return_detail_20261109.jpeg)
- 200 mm 切换竖幅并旋转 15° 后，视场显示 6.81° × 10.20°。连续三次右移后，显示「目标中心已出框」。[构图调整](s0-results/exp_e1_m31_adjust_20261109.jpeg) · [竖幅](s0-results/exp_e1_m31_portrait_20261109.jpeg) · [出框](s0-results/exp_e1_m31_outside_20261109.jpeg)
- 真机自定义 24 × 18 mm 和 120 mm 后，画框为 4:3，视场为 11.42° × 8.58°，与独立计算一致。[输入值](s0-results/exp_e1_custom_values_20261109.jpeg) · [预览](s0-results/exp_e1_custom_preview_20261109.jpeg)
- 煤袋星云 C99 的红光预览显示「角尺寸未知 · 只标中心」，保留周边星点且无目标轮廓。真机静态截图确认红光配色，切换瞬间是否白闪仍待连续录屏。测试保留了无线 HDC 链路，整表断网流程尚未实测。[红光设置](s0-results/exp_e1_c99_red_setup_20261109.jpeg) · [红光预览](s0-results/exp_e1_c99_red_20261109.jpeg)

DevEco CLI `1.3.0-stable` 识别手表，使用 `devecocli build --product default --modules entry --build-mode debug` 签名构建，HDC 覆盖安装并启动。签名 HAP 位于 `starpilot-watch/entry/build/default/outputs/default/entry-default-signed.hap`，大小 2,612,343 B，SHA-256 为 `91aa52986fc275099bd112683a631b543c38ccd0925a6bddbd7794e35bc4c7f5`。与 E0 记录的签名 HAP 总大小相比增加 96,643 B（94.4 KiB，含 ArkTS 调试映射等打包内容），超过 E0 计划的 24 KiB 包内增量。运行内存、功耗和发布包增量待 E6 测量。

调试前使用 HDC 执行 `power-shell timeout -o 1800000` 和 `power-shell wakeup`，设备返回 `Override screen off time to 1800000`。结束后恢复原主题和熄屏设置，`power-shell timeout -r` 返回 `Restore screen off time`。[恢复后的主页](s0-results/exp_e1_home_restored_20261109.jpeg)

## 改动与回滚

- `FramingEngine.ets` 提供独立数学核心，`FramingPage.ets` 提供参数输入、画框预览和构图调整。
- `TargetsPage.ets` 增加取景入口，`Index.ets` 挂载取景页并保留原目标详情，`tools/photo-test/verify_framing.mjs` 提供数学回归验证。
- 回滚时只撤销上述取景入口和挂载逻辑，移除本阶段的页面、数学核心和回归脚本，再重新构建。既有本地数据无需迁移。
