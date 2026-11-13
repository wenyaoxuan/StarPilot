# StarPilot V1 — Codex 交接文档

日期：2026-11-13
仓库：`C:\Users\32966\.zcode\workspace\682492f7-7293-40bc-87a9-dbe58d28cb56`  
分支：`master`（远端主分支名是 `main`，但当前工作分支是 `master`）  
设备：HUAWEI WATCH 5 46mm（RTS-AL00），HarmonyOS 6.1.0.333，API 23，466×466

> 先读 `AGENTS.md` 的硬规则。本文是项目状态的权威交接；不要只根据早期报告判断当前状态。
>
> `AGENTS.md` 和 `CODEX_HANDOFF.md` 当前是**未跟踪文件**；转交/打包时必须包含它们，但不要包含 `build-profile.json5`、`*.p12/*.cer/*.p7b` 或签名密码。

---

## 1. 项目是什么

StarPilot V1 是手表端观星/深空摄影辅助工具：

- 手表：现场指向、目标目录、AR 星空 HUD、摄影计算、天气、GPS、光污染/Bortle；
- 手机：只做重计算/配置（本仓库没有手机端代码）；
- 相机：Sony A7R IV 全程手动，**不控制相机**；
- 核心约束：离线可用、不依赖持续网络、不伪造 API/测试结果。

当前目标不是“通用天文 App”，而是 Bortle 9 城市阳台 + 出行暗空点的腕上辅助。

---

## 2. 当前构建与安装

最新源码构建：

```text
HAP: starpilot-watch/entry/build/default/outputs/default/entry-default-signed.hap
SHA256: 50a38ebae27af20dbe31b8d4392778b3285912e3cda72f90090955186a2768c8
```

最后一次安装：2026-11-11，导航实物对准校准已用 DevEco Hvigor 构建并通过 HDC 覆盖安装。「主页 → 天文工具」包含流星雨、ISS 过境、手动星桥和极轴辅助。星桥也可从深空目标详情进入。  
当日上一版验证天气恢复修复。蓝牙默认链路（`bearers=2`）真机四轮刷新均取得 Open-Meteo 和 7Timer 数据。天气请求使用系统默认网络，短暂传输失败时单次重试，链路恢复后补刷需要更新的数据。[设备日志](s0-results/wx_bluetooth_20261110.txt)  
HDC 目标（会变）：`<watch-ip>:<port>`。先用 `hdc list targets`，连不上就用 `hdc tconn <ip>:<port>`。

EXP-01 阶段证据见 [E0 审计](STAR_PILOT_EXP_E0_AUDIT.md)、[E1 深空取景报告](STAR_PILOT_E1_FRAMING_REPORT.md)、[E2 流星雨报告](STAR_PILOT_E2_METEOR_REPORT.md)、[E3 ISS 卫星过境报告](STAR_PILOT_E3_SATELLITE_REPORT.md)、[E4 手动星桥报告](STAR_PILOT_E4_STAR_HOP_REPORT.md) 和 [E5 极轴辅助报告](STAR_PILOT_E5_POLAR_ALIGNMENT_REPORT.md)。本机已安装 DevEco CLI `1.3.0-stable`，可在 `starpilot-watch` 下运行 `devecocli build --product default --modules entry --build-mode debug`。

```bash
HDC="E:/DevEco Studio/sdk/default/openharmony/toolchains/hdc.exe"
"$HDC" list targets
"$HDC" -t <ip>:<port> install -r \
  starpilot-watch/entry/build/default/outputs/default/entry-default-signed.hap
```

构建：

```bash
cd starpilot-watch
PATH="E:/DevEco Studio/tools/node:$PATH" \
DEVECO_SDK_HOME="E:/DevEco Studio/sdk" \
"E:/DevEco Studio/tools/hvigor/bin/hvigorw" assembleHap \
  --mode module -p product=default -p buildMode=debug --no-daemon
```

注意：

- `build-profile.json5` 被 `.gitignore` 忽略，含签名路径/密码，**不要复制、提交或写进交接文档**。
- 新机器从 `build-profile.example.json5` 复制，用 DevEco 自动签名。
- 项目内没有 `hvigorw`，用 DevEco 的 `tools/hvigor/bin/hvigorw`。
- 签名 HAP 才可安装；不要提交 `*.p12/*.cer/*.p7b`。

---

## 3. 必须优先阅读的文件

1. `AGENTS.md` — Codex 工作规则
2. `README.md` — 产品现状/入口/交付物
3. `AR_POINTING_MODES.md` — **当前 AR 只保留 12 点模式**
4. `AR_FIX_TEST_REPORT.md` — AR 真机测试状态（含未执行项）
5. `AR_FIX_CHANGED_FILES.md` / `AR_FIX_ROLLBACK.md` — 改动与回滚
6. `GPS_LOCATION_REPORT.md` — 一次性 GPS/城市持久化
7. `SUN_AND_PHOTO_UPDATE.md` — 太阳 + 49 台相机/焦段/光圈/ISO/总时长
8. `LIGHT_POLLUTION_REPORT.md` — 157 城市 Bortle、天光/ISO 模型
9. `AR_FIX_F5_NORTH_REFERENCE.md` — 北向基准仍**未确认**
10. `TECH_AUDIT.md` — 平台/SDK/设备能力审计

历史报告（`AR_REPORT.md`、`AR_ASTRONOMY_AUDIT.md`、`AR_PROJECTION_AUDIT.md` 等）描述的是修复前状态，不要当成当前实现。

---

## 4. 当前功能状态

### 4.1 页面

`pages/Index.ets` 是入口：

- 4 页 Swiper：Home / Nav / Targets / Photo
- 覆盖层：Location / Weather / Horizon / AR / Diagnostics / Privacy
- Preferences 名称：`starpilot_s1`

页面：

| 页面 | 内容 |
|---|---|
| Home | 时间/日期/电量、拍摄条件、暮光、月相、天气卡、红光、诊断、城市入口 |
| Nav | 12 点方位与高度、目标状态、分轴转向提示、目标目录／AR／遮挡入口 |
| Targets | 1,198 个目标，支持搜索、分类、仅可见、详情和导航 |
| Photo | 49 机身、品牌筛选、常用/自定义焦段、光圈、ISO、总时长、Bortle/天光模型、计时 |
| Location | 157 城市 + GPS“当前位置”；地区筛选；Bortle 显示 |
| AR | 12 点指向、星空/太阳系/地平线/目标/边缘箭头 |
| Diagnostics | 6 页：设备、传感器、罗盘、系统方向、传感器审计、工具 |
| Horizon | 16 扇区遮挡 + Bortle 手动覆盖 |
| Weather | Open-Meteo + 7Timer 双源 |
| Privacy | 首次选择、隐私政策、个人信息收集清单、第三方 SDK/API 清单、开源许可、撤回授权 |

### 4.2 天体目录

- 669 个 D1 静态目标、520 颗新增连线恒星、9 个太阳系目标，共 **1,198** 条。710 个连线端点中有 190 个已在 D1 目录收录。
- 太阳已加入，带“必须使用巴德膜”警告；太阳可见窗口按白天高度判断。
- 静态目录由 `data/TargetCatalog.ets` 合并 D1 数据和连线恒星。太阳系历算见 `common/SolarSystem.ets`。
- 太阳/行星/月球对拍 astronomy-engine：太阳 ≤0.30′，整体 ≤1.34′。

### 4.3 AR

- **只有 12 点指向模式**：屏幕朝自己，用表盘 12 点边缘指目标。
- 表背模式、MAG 订阅、模式切换、`AR_QDIR` 日志已删除。
- 导航与 AR 优先使用 `ORIENTATION alpha` 方位和同一个 `ACC_Y / |ACC|` 高度计算。姿态数据过期时使用有效 ROT 回退；导航在磁场异常时暂停转向，可继续显示有效的高度提示。相对归零在诊断的罗盘页。
- 投影：`SkyProjection.projectPoint`，60° FOV、z>0 背面剔除、圆屏安全区。
- AR 主路径对方位和高度做随转动速度变化的平滑。ROT 回退仍按硬件时间戳做 1€ 滤波。绘制目标周期 50ms，星历每 2s 刷新。
- AR 放大界面和星名文字，避开重叠标签。默认显示 Stellarium Modern 的 88 个星座连线，可从右上角关闭。数据随 HAP 打包，见 `tools/catalog/DATA_SOURCES.md`。
- 710 个端点均有名称或星表编号，AR 优先放置亮星标签，点按端点可看名称和 HIP 编号。
- 按 HIP 编号匹配 Stellarium Chinese v26.3 后，663 个连线端点有中文显示名。AR 底部和天体目录顶部可切换星名中英文，导航目标名同步。默认中文，偏好键为 `english_sky_names`。真机确认跨页面切换和重启后保留，英文显示时搜索「鹤五」仍返回 γ Tuc。证据见 `s0-results/ar_star_names_chinese_20261108.jpeg`、`ar_star_names_english_20261108.jpeg`、`catalog_chinese_search_english_names_20261108.jpeg`。
- 2026-11-08 真机确认点按 γ Tuc 可查看 HIP114996，目录按该编号返回唯一结果，设为目标后导航识别，AR 显示目标红圈。见 `s0-results/ar_constellation_star_name_20261108.jpeg`、`catalog_constellation_star_20261108.jpeg` 和 `ar_constellation_star_target_20261108.jpeg`。
- 目标：视场内红圈；视场外边缘箭头；背后只提示“在指向后方”。
- 当前限制：北向基准（磁北/真北）未确认；A–F 动作测试未全部完成。
- 2026-11-11 用户报告实际月球在 12 点指向右侧约 20°，现场暂不能复测，根因和补偿数值仍未确认。增加「对准目标校准」，由用户实际瞄准后测得当次方位差，导航与 AR 共用，重启、改变观测位置或清除 GPS 后清除。该实物参考独立于未确认的磁北/真北基准。拒绝异常传感器、隐藏目标、太阳、过大高度差、接近天顶和超过 45° 的校准。数学验证包括补偿符号、跨北、重复校准替换、完整姿态旋转和拒绝条件。真机已验证入口，尚未验证现场对月校准精度。[导航入口](s0-results/nav_sighting_20261111.jpeg)
- 同轮截图出现「磁场异常」，尚不能据此断定此前偏差的根因。最后一次成功的常亮操作已恢复原息屏时间，随后无线调试断开。[磁场提示](s0-results/nav_sighting_confirm_20261111.jpeg)
- 2026-11-08 新版真机证据见 `s0-results/nav_guidance_20261108.jpeg`、`nav_sun_warning_20261108.jpeg`、`ar_constellations_on_20261108.jpeg`、`ar_constellations_off_20261108.jpeg` 和 `nav_ar_updates_20261108.hilog`。实测 M2 暮光状态与磁场异常时分轴指引，导航与 AR 同次切换高度均显示 +22°，连线开关有效。AR 24 个日志样本中高度标准差由原始 0.145° 降至绘图 0.080°。该结果来自短时间真机采样，转腕跟手性和现场指向精度仍待确认。

### 4.4 GPS

- 一次性定位，不持续 GPS。
- 首次点「GPS 定位」先取得应用内单独同意，再按需请求系统权限。精确位置仅用于表端观测计算；用户可在「隐私」撤回并清除保存的定位。旧版 GPS 记录在单独同意前不加载。
- `getCurrentLocation` + `APPROXIMATELY_LOCATION/LOCATION` 权限。
- 使用系统精确权限和 `ACCURACY`，单次最多 45 秒。仅有粗略权限时提示允许精确位置或手选城市。拒绝系统报告误差超过 100 米、时间缺失或请求前超过 15 秒的结果。
- 最新合格结果作为 GPS 观测位置保存，定位时间随坐标保存。主页区分「默认」「城市」和「上次 GPS」。旧版无时间的记录需要重新定位；清除 GPS 后回到上次手选的观测城市。
- 2026-11-10 模拟验证新鲜点、粗略授权、系统定位关闭、过旧/缺失/未来时间、低精度、无效坐标和超时。真机截图确认旧 GPS 停用后标记「默认 · 北京」。随后真机重新定位，通过 HDC 界面树确认系统报告精度 ±19 米，定位点距目录中的深圳参考点不足 50 公里。测试未保留本次原始经纬度，已恢复原息屏时间。[主页截图](s0-results/gps_home_20261110.jpeg)
- 实测：`22.7673, 113.8005 ±10m`；重启保留。
- 移动后需再点“GPS 定位”。
- 2026-11-08 复测。旧版报 `3301200`，消息为系统网络定位不可达。新版日志显示两项权限已授予，约 31 秒取到位置，系统报告精度约 ±20m。见 `s0-results/gps_weather_update_20261108.hilog`。

### 4.4.1 天气来源与回退

- 首次启动或升级后，用户可开启城市天气或仅离线使用。开启后两个天气源只接收城市目录坐标，独立于 GPS 观测位置。「隐私」可单独更改天气城市或关闭天气。诊断只查询系统网络状态。
- Open-Meteo 正常时优先显示其常规天气。失败或数据超过 30 分钟时，如果有当前 7Timer ASTRO 时次，首页显示标明来源的 7Timer 预报。两源失败时缓存标注时效。新缓存按坐标和城市名匹配，旧请求不能覆盖新位置。
- 7Timer 的云量、湿度、风速按原始预报区间显示，视宁与透明等级越小越好。降水类型单独标注。
- 旧版真机复现 Open-Meteo 超时 `2300028`、7Timer 成功。新版两源真机刷新成功，回退和恢复用模拟响应验证。见 `s0-results/gps_weather_update_20261108.hilog`、`weather_astro_details_20261108.jpeg`。

### 4.4.2 隐私与许可

- 「主页 → 隐私」提供政策、个人信息收集清单和第三方 SDK/API 清单。正式发布需补充真实发布主体与隐私联系渠道。开源许可页列出 OpenNGC、HYG、Stellarium 的 CC BY-SA 4.0 署名和改动，并可离线查看 Caldwell 元数据和 satellite.js 的 MIT 全文。
- 2026-11-10 真机确认首次选择、离线主页、GPS 单独告知和拒绝、许可入口和 Caldwell MIT 全文。最终包覆盖安装后，表上显示「城市天气已关闭」，可在「主页 → 隐私」重新选择。已恢复原息屏设置。授权后的 GPS 和天气请求本轮未触发。[首次选择](s0-results/privacy_first_20261110.jpeg) · [离线主页](s0-results/privacy_offline_20261110.jpeg) · [GPS 告知](s0-results/privacy_gps_consent_20261110.jpeg) · [开源许可](s0-results/privacy_licenses_20261110.jpeg) · [Caldwell MIT](s0-results/privacy_caldwell_mit_20261110.jpeg)

### 4.5 摄影助手

- 49 台机身，品牌筛选（Sony/Canon/Nikon/Fujifilm/Panasonic/OM System/Leica/Hasselblad/Pentax/Apple）。
- 15 个常用焦段 + 1–3000mm 自定义（数字键盘输入）。
- 光圈 0.7–22 自定义（步进 0.1）。
- ISO 50–409600、目标总曝光 1–1440min 支持预设与数字键盘输入。
- FOV/像素比例/NPF/500/1px 拖线按所选机身/焦段计算。
- 首屏显示单张 × 张数、总曝光和预计拍摄耗时。计时器闲置时可收起，运行时展开。
- 无赤道仪方案按 NPF 和估算饱和阈值中的较短值算堆栈。有赤道仪方案按用户设定的单张和张数计算，超过估算饱和阈值时提示。读噪参考时长在详情单独显示。
- 2026-11-08 通过 HDC 确认两种模式、同模式重复点按、品牌筛选选机身、自定义焦段／ISO／总曝光，以及 30s 计时启动、停止和常亮开关日志。证据见 `s0-results/photo_assistant_*_20261108.jpeg`。本轮尚未验证到时振动或相机实拍。
- 机型参数：A7 V、A7R VI、R6 III、S1R II、Pentax K-3 III 已按官方规格核对；其余为公开规格四舍五入。

### 4.6 Bortle/光污染

- `data/Cities.ets` 的 157 个城市都有 `bortle` 字段。
- 当前 GPS 位置默认 B9；切换城市自动换成城市值；Horizon 页可手动覆盖。
- Bortle 是城市中心近似值，不是阳台实测；没有 VIIRS 栅格。
- 天光模型是规划估算，不是传感器标定；详见 `LIGHT_POLLUTION_REPORT.md`。

### 4.7 表冠

- 主页面切页：`Index.onDigitalCrown`，20° 一页。
- 天体目录滚动：`TargetsPage` 接收 `crownStep`，列表/详情滚动 42px/步。
- **真机未确认**最新表冠行为；Location/Weather 列表尚未接表冠滚动。

---

## 5. 测试状态（必须如实保留）

`AR_FIX_TEST_REPORT.md` 是当前 AR 测试记录。

| 项 | 状态 | 证据/说明 |
|---|---|---|
| S10 静止 60s | 完成，有环境 caveat | center-ORI σ 0.023°，高度 RMS 0.169°；方位 4° 漂移来自 ORI 环境 |
| S15 重启恢复 | 通过 | GPS/AR/传感器恢复 |
| S17 月球对准 | 部分通过 | 用户确认 12 点模式可用；定量最终对准未做 |
| S18 背后/边缘 | 部分通过 | 背后提示、左上边缘箭头 |
| S11/S12 360° | **未执行** | 用户暂不做动作测试 |
| S13 俯仰 30/60/90 | **未执行** | — |
| S14 roll | **未执行** | — |
| S16 异常数据 | **未执行** | 遮挡/晃动/磁铁/UNRELIABLE 注入未做 |
| 表冠 | 已实现，未确认 | 主页面 + 天体目录 |
| 摄影数学 | PASS | A7R IV 基线 + APS-C/M4/3/中画幅/像素比例/等效焦距 |
| 光污染模型 | PASS（单点校准） | SharpCap 14.5 e/px/s 校准点；B1/B9 趋势 |

**不能**在交接/提交里写“AR A–F 全部通过”或“已对准土星”。用户确认的是 12 点模式可用 + 月球方向可对。

---

## 6. 已知问题/风险（按优先级）

### P0 — 不要误判

1. **北向基准未确认**：ORIENTATION alpha 是磁北还是真北没有外部证据；当前没有应用 declination，也没有固定偏移。不要为了“对准”写死城市偏移。
2. **A–F 动作测试缺失**：360°、俯仰、roll、异常数据未做。不能宣称完整验收。
3. **传感器恢复**：从系统设置返回应用可能出现 ORIENTATION UNRELIABLE / ROT q=0；`aa force-stop` 可恢复，自动恢复未实现。

### P1 — 功能风险

4. **表冠未真机确认**：主页面/目录逻辑已加；如果仍无响应，需要把 `onDigitalCrown` 挂到根节点或检查焦点。
5. **只有 12 点模式**：表背模式已删除；如果用户要求恢复，需要重新设计，不能直接把旧代码贴回。
6. **Bortle 是估算**：157 城市城市中心值，不是阳台实测；真实点位应手动改 Bortle。
7. **天光模型是估算**：全阱/读出噪声/QE 近似，单点 SharpCap 校准；没有完整 SNR/滤镜/月光模型。
8. **相机参数**：49 台中部分为公开规格四舍五入；A7 V/A7R VI/R6 III/S1R II/Pentax K-3 III 已核对，其余发布后复核。

### P2 — 产品待办

9. **太阳安全**：只有文字警告，没有滤镜检测；不要鼓励无滤镜观测/拍摄。
10. **真实阳台遮挡**：Horizon 只有合成/手动数据；真实阳台待录入。
11. **S3 现场指向**：Nav/AR 现场精度验收未完成。
12. **G4 Wear Engine**：历史阻塞，未解决；不要假设手机通信可用。
13. **Location/Weather 表冠滚动**：未实现。

---

## 7. 代码地图

```text
starpilot-watch/entry/src/main/ets/
├─ pages/
│  ├─ Index.ets            # 入口、4 页 Swiper、覆盖层、Preferences、GPS 城市
│  ├─ HomePage.ets         # 首页/天气/暮光/月相
│  ├─ NavPage.ets          # ORIENTATION 导航、AR/遮挡入口
│  ├─ TargetsPage.ets      # 目录、搜索/筛选/详情/窗口/表冠滚动
│  ├─ PhotoPage.ets        # 摄影助手、计时、相机/焦段/光圈/ISO/总时长
│  ├─ ArPage.ets           # 12 点 AR、Canvas、目标/边缘箭头
│  ├─ LocationPage.ets     # 157 城市 + GPS
│  ├─ WeatherPage.ets      # 双源天气
│  ├─ HorizonPage.ets      # 16 扇区 + Bortle 手动覆盖
│  ├─ DiagnosticsPage.ets  # 6 页诊断
│  └─ SensorAuditPage.ets  # F1/F5 诊断
├─ common/
│  ├─ SensorHub.ets        # ACC/GYRO/MAG/ROT 订阅、校验、统计
│  ├─ OrientationHub.ets   # ORIENTATION 共享订阅/校验
│  ├─ SensorData.ets       # 样本/统计类型
│  ├─ AttitudeFilter.ets   # OFF/SLERP/1€
│  ├─ CameraPose.ets       # 12 点姿态、回退四元数
│  ├─ SkyProjection.ets    # 透视/背面/圆屏
│  ├─ Fusion.ets           # 向量/四元数/坐标
│  ├─ Astro.ets            # 历算/坐标
│  ├─ SolarSystem.ets      # 太阳/月球/行星
│  ├─ Photo.ets            # 49 机身、焦段、FOV/NPF/堆栈
│  ├─ LightPollution.ets   # Bortle/SQM/天光/ISO 模型
│  ├─ GeoLocation.ets      # 一次性 GPS
│  ├─ Weather/Weather7     # 双源天气
│  └─ AuditLog.ets         # hilog 固定 tag
└─ data/
   ├─ Cities.ets           # 157 城市 + bortle + GPS 伪城市
   ├─ Messier.ets          # 669 个 D1 静态目标
   ├─ Constellations.ets   # 710 个具名或有编号的连线端点
   └─ TargetCatalog.ets    # 合并并索引静态目标
```

关键数据流：

```text
ROT/ACC/ORI
  → SensorHub/OrientationHub 校验
  → AttitudeFilter (1€)
  → CameraPose (ORI alpha + ACC_Y 12点; q fallback)
  → SkyProjection.projectPoint
  → ArPage Canvas

城市/GPS
  → CITIES[cityIndex] (lat/lon/bortle)
  → Astro/SolarSystem / Weather / Photo
```

Preferences 关键 key：

```text
city_index, bortle, gps_active, gps_lat, gps_lon, gps_alt, gps_acc,
target_id, red_mode, horizon_sectors,
camera_index, focal_index, focal_mm, focal_max_ap,
aperture_value, iso_value, photo_mode, sub_index, count_index, total_minutes,
timer_end, timer_total
```

---

## 8. 测试/验证命令

```bash
# 摄影
cd tools/photo-test
npx esbuild ../../starpilot-watch/entry/src/main/ets/common/Photo.ets \
  --loader:.ets=ts --format=esm --outfile=photo.mjs
node verify.mjs
node verify_formats.mjs

# 光污染
npx esbuild ../../starpilot-watch/entry/src/main/ets/common/LightPollution.ets \
  --bundle --loader:.ets=ts --resolve-extensions=.ets,.ts,.js \
  --format=esm --outfile=lightpollution.mjs
node verify_light.mjs

# 天文
cd ../astro-test
npx esbuild ../../starpilot-watch/entry/src/main/ets/common/SolarSystem.ets \
  --bundle --loader:.ets=ts --resolve-extensions=.ets,.ts,.js \
  --format=esm --outfile=solar.mjs
node solar-verify.mjs

# AR 数学
cd ../ar-audit
node pose_test.mjs
node projection_f3_test.mjs
node filter_test2.mjs
```

真机截图：

```bash
HDC="E:/DevEco Studio/sdk/default/openharmony/toolchains/hdc.exe"
T="<ip>:<port>"
"$HDC" -t "$T" shell snapshot_display -f /data/local/tmp/shot.jpeg
"$HDC" -t "$T" file recv /data/local/tmp/shot.jpeg s0-results/shot.jpeg
```

日志：

```bash
"$HDC" -t "$T" shell "hilog -x | grep StarPilotAudit | tail -50"
```

常用 UI 自动化：

```bash
"$HDC" -t "$T" shell uitest uiInput click <x> <y>
"$HDC" -t "$T" shell uitest uiInput swipe 380 200 80 200 800
"$HDC" -t "$T" shell uitest dumpLayout -p /data/local/tmp/layout.json
```

---

## 9. 仓库卫生/安全

- 工作区有大量未提交改动和未跟踪证据；**不要 `git clean` / 不要盲目 `git add -A`**。
- `AR_AUDIT/baseline/` 是审计基线副本和哈希；不要覆盖。
- `s0-results/` 是截图/日志证据；可新增，不要删除。
- `tools/*/node_modules`、`*.mjs` 生成物被 gitignore。
- `starpilot-watch/build-profile.json5` 含签名材料引用和密码，已忽略；**不要提交/转发**。
- 提交前检查：

```bash
git status --short
git diff --stat
git check-ignore -v starpilot-watch/build-profile.json5
```

---

## 10. 建议的下一步

推荐顺序（先确认用户意图，不要擅自大改）：

1. **表冠真机确认**：Home/Nav/Targets/Photo 切页；天体目录滚动；看 `CROWN` 日志。必要时把 `onDigitalCrown` 挂根节点/修焦点。
2. **补 A–F 动作测试**：按 `AR_TEST_PLAN.md` 做 360°、俯仰、roll、异常数据；更新 `AR_FIX_TEST_REPORT.md`，未做项保持“未执行”。
3. **北向基准**：用系统指南针/已知地理方位确认 alpha 是磁北/真北；只有确认后才考虑 `deflectionAngle`，禁止写死偏移。
4. **Bortle 校准**：用户实际点位可手动覆盖；若要自动，需离线 VIIRS/World Atlas 栅格，当前没有。
5. **真实阳台遮挡 + S3 现场指向**：产品级待办。
6. **整理提交**：只提交源码/文档/必要证据，排除签名和生成物；用户确认后再 commit。

---

## 11. 交接验收清单

Codex 接手后先做：

- [ ] 读 `AGENTS.md` + 本文
- [ ] `git status --short` 确认工作区；不清理未跟踪文件
- [ ] 确认 `build-profile.json5` 存在且未提交；不存在则用 example + DevEco 签名
- [ ] 构建最新 HAP，记录 SHA256
- [ ] 跑 `verify.mjs`、`verify_formats.mjs`、`verify_light.mjs`、`solar-verify.mjs`
- [ ] `hdc list targets`，安装，打开 Home/AR/Photo 各截一张图
- [ ] 表冠实测；失败则记录现象，不猜
- [ ] 任何“通过”结论都附截图/日志/用户确认
- [ ] 不把历史报告里的旧结论（表背模式、等距投影、旧 AR）当当前状态
## 0.1.1 公开预览版（2026-11-13）

公开源码已与原工作区逐文件比对，应用源码包含 GPS 质量校验、隐私与许可、实物对准校准。版本元数据更新为 0.1.1。此版本重新构建通过，尚未进行新的真机安装验证。源码和 unsigned HAP 下载说明见 DOWNLOADS.md。原始设备证据保留在私有工作区。约 20° 偏差的根因与现场校准精度仍待确认。
