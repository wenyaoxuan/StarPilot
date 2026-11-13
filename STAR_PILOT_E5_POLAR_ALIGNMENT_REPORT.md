# StarPilot EXP-01 E5 赤道仪极轴辅助

2026-11-09 至 2026-11-10，Asia/Shanghai。目标设备为 HUAWEI WATCH 5 46 mm（RTS-AL00，HarmonyOS 6.1.0.333，API 23，466 × 466）。

## 功能

- 「主页 → 天文工具 → 极轴辅助」包含粗对准、漂移法和观测记录。粗对准按已选地点显示数学天极方位和高度，赤道处保留两个半球选择。SDK 地磁模型提供带查询时刻的磁偏角参考，现场磁场和手表航向基准仍待外部校验。页面不会从手表姿态推定架台轴向。[HarmonyOS 传感器文档](https://developer.huawei.com/consumer/en/doc/harmonyos-references/js-apis-sensor/) · [北向审计](AR_FIX_F5_NORTH_REFERENCE.md)
- 漂移法先确认半球、赤道仪或楔式、相机/目镜成像翻转、侧位、视野、恒星跟踪和关闭自动导星修正。用户自行辨认目标并在相机画面或目镜中观察。60／120／180 秒计时结束后可记录屏幕方向和目测幅度，单轴试调后复测。
- 方位组以可见子午圈和近天赤道星为主。高度组在视野开放时优先东或西向适用区。南／西南限制下只显示符合条件的西南替代星，标记两轴耦合和几何较弱。无适用星时保留已完成的记录，等待刷新或换场地。候选与地平遮挡以本地星表和既有地平线配置计算。[PHD2 漂移法](https://openphdguiding.org/man/Tutorials.htm)
- 记录使用版本化本地文件，最多保留 96 轮，支持二次确认清除和 UTF-8 文本导出。导出文本通过调试沙箱取回，流程见实地指南。计时用绝对截止时间，后台时停止 UI 定时刷新；返回时重算剩余时间。后台过的轮次需额外确认持续观测，进程结束后可从已保存记录继续。

## 精度边界与验证

当前采用定性漂移趋势。比较需要同一会话、同一星、相同时间长度、成像和侧位、相近时角、且两轮都有可比较的方向和幅度。P-C 定量拟合需要实测像素比例、赤纬方向和两组独立几何，本阶段未接入。屏幕方向原样保存，螺丝方向由用户的小幅试调和复测建立。

`node tools/astro-test/polar-verify.mjs` 通过南北半球、赤道和两极、无效纬度、时区和经度、参考星几何、遮挡、跨日计时、换星、光学翻转、侧位变化和噪声拒绝。其他阶段的数学回归脚本继续通过。

- [几何与合成测试](POLAR_ALIGNMENT_GEOMETRY_TESTS.md)
- [无北极星实地操作指南](POLAR_ALIGNMENT_FIELD_GUIDE.md)

## Watch 5 验证

- DevEco CLI `1.3.0-stable` 构建成功并通过 HDC 安装。最终签名调试包为 3,218,182 B，SHA-256 为 `e871c3eee0d9381607520df0b7668005bb6764f9317f27baa9ec07300d4090c5`。较 E4 增加 188,035 B（183.6 KiB，含调试映射），超过 E0 的 64 KiB 增量目标。
- 红光粗对准页显示北天极、数学真方位 0°、当前地点的纬度高度和带时间的 SDK 地磁模型参考。方位组列出可见窗口内的候选星，并在确认跟踪和导星条件后进入计时。[粗对准](s0-results/exp_e5_coarse_20261109.jpeg) · [条件](s0-results/exp_e5_conditions_20261109.jpeg) · [方位组选星](s0-results/exp_e5_az_stars_20261109.jpeg)
- 60 秒流程经 HDC 到时进入漂移录入。日志记录实际前台间隔 60.236 秒，震动 SDK 返回 `VIBRATE|time 300 ok`。操作使用合成漂移输入，未通过相机或架台测量。[倒计时](s0-results/exp_e5_timer_20261109.jpeg) · [到时](s0-results/exp_e5_timer_done_20261109.jpeg) · [演示保存](s0-results/exp_e5_review_20261109.jpeg)
- 11 月 10 日重新进入页面，前一日记录仍可读取。通过 HDC 取回 UTF-8 文本，核对时间、参考星、成像、侧位、幅度和试调次数。二次确认清除后，手表的历史文件为空数组。桌面测试覆盖 96 条记录、导出及损坏和超限输入拒绝。[重开记录](s0-results/exp_e5_history_reload_20261110.jpeg) · [文本导出](s0-results/exp_e5_test_export_20261110.txt) · [清除结果](s0-results/exp_e5_cleared_20261110.jpeg)
- 计时中打开系统设置并返回。日志记录 `paused_ui_background`，界面由 59 秒恢复到 51 秒，到期记录 `continuous=false` 并要求确认连续观察。[返回倒计时](s0-results/exp_e5_switch_resumed_20261110.jpeg) · [到时确认](s0-results/exp_e5_switch_done_20261110.jpeg) · [真机日志](s0-results/exp_e5_audit_20261110.txt)
- 「仅南/西南」下真机高度组列出西南替代候选，界面标明标准东西视野受限。最终包从方位结果页进入高度组时，列表回到页首，提示完整可见。实际架台漂移、整表断网和震动体感尚未实测，SDK 震动成功以日志为准。[最终包高度组](s0-results/exp_e5_final_height_20261110.jpeg)
- 最终包仍能读取 E3 的 ISS 缓存并显示历元状态。E5 演示轮次均已清除，HDC 确认熄屏超时恢复。[ISS 回归](s0-results/exp_e5_iss_regression_20261110.jpeg) · [最终记录状态](s0-results/exp_e5_final_cleared_20261110.jpeg)

## 回滚

移除 `Index.ets` 的极轴入口和路由、`PolarAlignPage.ets`、`PolarAlignEngine.ets`、`PolarStore.ets` 与 E5 测试，再重建。共用的 `BoundedTextFile.ets` 保留给 E3 缓存。E5 记录和导出使用单独文件。
