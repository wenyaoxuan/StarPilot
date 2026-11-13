# StarPilot EXP-01 E3 ISS 卫星过境

2026-11-09，Asia/Shanghai。设备为 HUAWEI WATCH 5 46 mm（RTS-AL00，HarmonyOS 6.1.0.333，API 23，466 × 466）。

## 使用方法

在手表打开「主页 → 天文工具 → ISS 卫星过境」。先导入 NORAD 25544 的单条 OMM JSON。允许 JSON 对象或单元素数组，文件上限 4 KiB。可以粘贴 JSON，支持系统文档选择器的设备也可选择文件。Watch 5 的导入页未出现系统文件选择按钮，真机验收使用下列 HDC 调试文件入口。天气之外的模块遵循项目离线约束，轨道下载在手表外进行。[CelesTrak GP 格式](https://celestrak.org/NORAD/documentation/gp-data-formats.php) · [CelesTrak 使用政策](https://celestrak.org/usage-policy.php) · [HarmonyOS 应用沙箱访问](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-device-file-explorer/)

```powershell
$hdc = 'E:/DevEco Studio/sdk/default/openharmony/toolchains/hdc.exe'
& $hdc list targets
& $hdc -t '<watch-ip>:<port>' file send -b com.starpilot.audit 'C:/path/to/iss-omm.json' './data/storage/el2/base/haps/entry/files/iss-omm.json'
```

送入后，在手表选择「导入 → 读取调试文件」。轨道缓存记录 NORAD ID、UTC 历元、导入方式和时间、数据版本、元素集编号及圈次。OMM 提供发布源时也会显示。新文件经格式、范围、历元及 SGP4 初始传播验证后，写入同目录临时文件，再原子替换缓存。无效文件或旧于缓存的数据不会覆盖现有轨道。

页面以手表时间显示预计进入和离开所选仰角的时刻、首末方位、最高仰角及持续时间，提供 0°／10°／20° 和自定义整数 0–89°。进入页面时重算，前台倒计时按分钟显示。采用已有位置和可用的 GPS 海拔，缺少海拔时明确按 0 m 计算。流星雨也移入「天文工具」。[华为后台任务概览](https://developer.huawei.com/consumer/en/doc/harmonyos-guides/background-task-overview/) · [华为代理提醒](https://developer.huawei.com/consumer/en/doc/harmonyos-guides/agent-powered-reminder/)

## 算法与限制

- 近地 SGP4 移植自固定版本 satellite.js 6.0.1，使用 WGS-72。算法输出 TEME，使用 GMST 旋转至近似地固系，再按 WGS-84 站点构造 ENU。UT1 以 UTC 近似，省略极移和大气折射。第三方 MIT 许可随 HAP 分发。[satellite.js](https://github.com/shashwatak/satellite-js/tree/6.0.1) · [Vallado 坐标转换](https://celestrak.org/publications/AIAA/2006-6753/faq.php)
- 用 20 秒采样定位局部最高点，再细化峰值与两侧仰角交点，即使窄过境未覆盖粗采样点也可检出。前看最多 24 小时，保留正在进行的过境，界面时刻只显示到分钟。当地建筑、地形和云量未计入。
- 可见性用观测点太阳高度 ≤ −6° 与卫星日照重合估计。地影按日地视圆判定，半影也归入遮挡。结果是几何提示，没有亮度估计。
- ISS 历元超过 24 小时会标记偏旧，达到 48 小时停止预测。预测区间也截在历元后 48 小时内。该限制是 ISS 首版保守策略，参考 CelesTrak 频繁发布的近地轨道与本阶段对照跨度。轨道机动、阻力及资料偏差需要实测才能估计，不同卫星不能沿用此限制。[CelesTrak 更新政策](https://celestrak.org/usage-policy.php)
- 本阶段无新增联网、定位、通知或后台权限。SDK 有后台和通知接口，本次仅验证了前台流程，回到页面时重新计算。系统文档选择器依据系统能力显示。[文件选择 API](https://developer.huawei.com/consumer/en/doc/harmonyos-references/js-apis-file-picker/) · [通知授权 API](https://developer.huawei.com/consumer/en/doc/harmonyos-references/js-apis-notificationmanager/)

## 独立验证

- Vallado 00005 在 0 和 360 分钟的 TEME 位置与速度通过固定向量断言。使用 CelesTrak ISS 样本（UTC 历元 `2026-11-09T04:58:46.240896`，元素集 999，圈次 59423）对照 Python sgp4 2.25。0–48 小时六个样本中，最大位置差 `2.76e-11 km`，最大速度差 `3.13e-14 km/s`，最大方位或高度差 `3.14e-8°`。北京、圣地亚哥和跨 UTC 午夜用例的最大进出或峰值时刻差 `0.997 s`，独立参考按 1 秒取样。另测北极无过境、已开始过境、临界仰角、地影、失效历元、错误参考系与损坏输入。这些数值衡量同一元素下的实现一致性。实际过境时刻未用现场观测验证。[Vallado 测试资料](https://celestrak.org/publications/AIAA/2006-6753/) · [Python sgp4 2.25](https://pypi.org/project/sgp4/2.25/)
- 可复现命令如下。Python 依赖仅用于桌面测试，轨道源文件不打包进应用。

```powershell
python tools/astro-test/satellite-reference.py iss-omm.json | Set-Content -Encoding utf8 reference.json
node tools/astro-test/satellite-verify.mjs iss-omm.json reference.json
```

## 真机验证

- DevEco CLI `1.3.0-stable` 构建成功，HDC 覆盖安装。最终签名调试包为 2,866,672 B，SHA-256 `4ce46cad7eca17f820ad466e8d9679b7b6ec0b2ed33fb33321d8418158284158`。相对 E2 增加 167.2 KiB，含调试映射。E0 计划目标为 192 KiB。
- 从空状态导入真实 ISS 轨道。应用重新启动后直接从缓存显示预测。10° 和 20° 门限下看到同一次最高约 51° 的过境，时段分别约 7 分钟和 4 分钟。自定义 89° 显示搜索范围内无完整过境。[入口](s0-results/exp_e3_menu_20261109.jpeg) · [无数据](s0-results/exp_e3_empty_20261109.jpeg) · [10° 缓存预测](s0-results/exp_e3_cache_20261109.jpeg) · [20° 预测](s0-results/exp_e3_20deg_20261109.jpeg) · [89° 无过境](s0-results/exp_e3_no_pass_20261109.jpeg)
- 损坏 JSON 和过期历元均被拒绝，两次操作前后的缓存 SHA-256 一致。成功导入后的单次计算日志为 59 ms。无线 HDC 在测试期间保持连接，整表断网和文本粘贴未在真机实测。[损坏数据](s0-results/exp_e3_bad_20261109.jpeg) · [过期历元](s0-results/exp_e3_old_20261109.jpeg)
- 截图确认红光预报和导入结果，调试时临时开启 30 分钟长亮，结束后恢复原红光偏好与熄屏设置。入口回归确认流星雨可从天文工具打开。[红光](s0-results/exp_e3_red_20261109.jpeg) · [重新导入](s0-results/exp_e3_reimport_20261109.jpeg) · [流星雨入口回归](s0-results/exp_e3_meteor_menu_20261109.jpeg) · [设备日志](s0-results/exp_e3_audit_20261109.txt)

## 回滚

撤销 `HomePage.ets` 和 `Index.ets` 的 E3 入口、位置海拔和前台状态接线。恢复 E2 的流星雨直达入口。移除 E3 页面、轨道缓存封装、SGP4 核心及随附许可，再重新构建。E3 缓存独立存放，既有设置和观测数据无需迁移。
