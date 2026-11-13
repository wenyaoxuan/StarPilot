# StarPilot-EXP-01 E0 审计与基线

日期为 2026-11-09，时区 Asia/Shanghai。审计依据为用户提供的 EXP-01 任务书、当前源码、本机 SDK、HDC 真机记录，以及仓库内的交接与审计材料。E0 交付审计、基线和阶段计划。

## 1. 冻结基线

| 项目 | 审计结果 |
|---|---|
| Git | `master`，HEAD `9236590f75111a9ba482b1de27f00338862947ca`。当前工作区含既有未提交修改与未跟踪文件，仅靠 HEAD 无法复现当前 HAP。 |
| 应用源码 | 54 项源码、资源与非私密构建输入，含未跟踪的当前 AR 和星表数据。清单 SHA-256 `178b0f6bc38f22066e2e9f11be53b788a74e03e5928e22e385d46a3327fd58c7`。 |
| 构建产物 | `starpilot-watch/entry/build/default/outputs/default/entry-default-signed.hap`，2,515,700 B，SHA-256 `1f98fed8a646b6471dcd42611c5ef1ef7e59bde61314923e3015414d4c0da775`，与交接记录一致。 |
| 工具链 | DevEco Studio `26.0.0.865`，Hvigor `6.26.9`，工程模型 `26.0.0`，Node `24.14.1`，HDC `3.2.0f`。另按用户要求全局安装并核实 DevEco CLI `1.3.0-stable`。 |
| SDK 与包 | 打包元数据的 compile SDK 为 HarmonyOS `26.0.0.105`，target 和 compatible 均为 `6.1.0(23)`。Stage 模型，`wearable`，`entry` / `EntryAbility`，`com.starpilot.audit`，版本 `0.1.0`，调试签名。 |
| 真机 | HUAWEI WATCH 5 46 mm，`RTS-AL00`，零售系统 `6.1.0.333(C00E100R1P102)`，API 23，截图 466×466。另有 OpenHarmony 底层版本字段，两者分别记录。 |

[源码哈希清单](s0-results/exp_e0_source_20261109.sha256)以工作区相对路径排序，每行记录该文件实际字节的 SHA-256，清单使用 UTF-8 和 LF。主工程私有签名配置只确认存在且被 Git 忽略。DevEco CLI 的 `--version` 和 `--help` 已核实，E0 复建采用已有可重复的 Hvigor 流程。[华为 DevEco CLI](https://developer.huawei.com/consumer/cn/doc/HarmonyOS-Guides/ide-deveco-cli-options/)

## 2. 现有实现与可复用项

| 范围 | 现状与接入约束 |
|---|---|
| 天体数据 | `Messier.ets` 有 669 条 D1 静态目标，`TargetCatalog.ets` 合并 520 颗去重后的连线恒星，再加 9 个太阳系目标，共 1,198 条。字段含 ID、中英文名与别名、类别、J2000 RA 小时与 Dec 度、星等及有效标记、长短轴角分及有效标记、距离与来源。现有应用对象无位置角与自行字段，缺值需保留未知。连线端点与增补名称的数据许可见 [数据来源](tools/catalog/DATA_SOURCES.md)。 |
| 时间与位置 | `Astro.ets` 有 Unix UTC 毫秒与 JD 转换、恒星时、J2000 岁差和 RA/Dec→几何 Alt/Az。经度东正，方位真北 0° 顺时针。页面日期通常采用手表本地时区，远程城市的本地日期不能直接沿用。位置来自 157 城市或一次性 GPS。GPS 海拔写入 `gps_alt`，当前共享城市对象和常规 Alt/Az 计算未传递该字段。 |
| 日月、可见性 | `SolarSystem.ets` 提供站心太阳系位置，`Astro.ets` 有太阳高度、暮光、月相、角距离、升落窗口与 16 扇区遮挡插值。Bortle 为估算，可覆盖。遮挡只有最低高度，无法表示阳台顶棚或狭窄方位开口。 |
| 光学与投影 | `Photo.ets` 的 `fovFor`、相机预设和输入约定可复用。现有 `SkyProjection.ets` 提供透视分母、背面剔除和圆屏投影参考，构图应另建赤道切平面与矩形裁切，独立于设备姿态和 AR 固定视场。 |
| 页面与主题 | `Index.ets` 管理 Home/Nav/Targets/Photo 和覆盖页、语言及红光偏好。新工具可挂单一覆盖入口，子页只接入所需数据。各新页通过 `Theme.palette` 继承红光，并单独测试弹层、Canvas 和跨页过渡。 |
| 本地状态和网络 | `starpilot_s1` Preferences 已持久化观测位置、遮挡、红光、摄影参数、计时及天气缓存。现有包声明 `INTERNET`、`GET_NETWORK_INFO`，天气走 Open-Meteo 和 7Timer。扩展首版使用本地数据，卫星先用缓存或离线导入，联网更新等到 E3 明确授权后再接入。 |

AR 以 [当前 12 点说明](AR_POINTING_MODES.md) 和源码为准。已读 [传感器审计](AR_SENSOR_DATA_AUDIT.md)、[坐标系审计](AR_COORDINATE_SYSTEM.md)、[修复测试](AR_FIX_TEST_REPORT.md)、[北向验证](AR_FIX_F5_NORTH_REFERENCE.md) 与 [技术审计](TECH_AUDIT.md)。工作区未找到标题为 AR-FIX-01 的独立任务书。EXP-01 E4 提到的表背轴与当前交接约束冲突，E4 先做手动模式。未来姿态辅助必须单独验收，并以当前 12 点接口为接入基线。北向基准仍未确认，阶段计划不引入固定磁偏角或航向补偿。

## 3. SDK 能力与真机证据

| 能力 | SDK／源码证据 | Watch 5 验证与开发限制 |
|---|---|---|
| Stage 安装、圆屏 UI、Canvas | 包元数据、ArkUI、`Index.ets`、`ArPage.ets` | E0 签名安装和启动成功，首页、导航、AR、摄影助手已截图。 |
| 姿态 | 本机 `@ohos.sensor.d.ts`，`SensorHub`、`OrientationHub`、`CameraPose` | E0 `AR_POSE` 日志记录到 `ORI_ACC`，导航截图提示磁场异常。只能证明链路输出。真实北向、角度精度与 A–F 运动测试未在 E0 验收。 |
| 定位 | `@ohos.geoLocationManager.d.ts`、双定位权限及一次性 `getCurrentLocation` | E0 首页读到已保存的当前位置。此前 [定位日志](s0-results/gps_weather_update_20261108.hilog) 证明该表能取一次位置，E0 未重新定位或测离线搜星。 |
| 本地存储 | Preferences 已接入。SDK `@ohos.file.fs.d.ts` 有 `open`、`fsync`、`rename` | Preferences 有历史真机证据。应用沙箱文件导入、异常恢复及同目录原子替换需 E3 用真机探针验证，失败时保留旧缓存。 |
| 常亮、计时和振动 | SDK `window.setWindowKeepScreenOn`、`vibrator.startVibration`，现有摄影计时采用 UTC 截止时间 | E0 调试用 HDC 延长屏幕超时。计时期间应用常亮及定时振动有 [历史 S1 真机证据](S1_TEST_REPORT.md)，E0 只截图摄影页。漂移法首版复用前台计时方案。 |
| 通知与后台 | SDK 有 `notificationManager.requestEnableNotification` 和 `backgroundTaskManager.startBackgroundRunning`，当前应用未接入 | SDK 声明不等同于腕表交付保障。E3/E5 首版采用前台倒计时、重新打开补提示，等待腕表验证后再承诺后台通知。 |
| 网络、红光与手机依赖 | 天气已接入，`palette` 已接入主界面。无 Wear Engine 依赖 | 首页截图实际显示 7Timer 预报。红光切换见 E0 截图。E0 未做断网、30 分钟功耗或后台时效验收。 |

调试先执行 `power-shell timeout -o 1800000` 和 `power-shell wakeup`。设备回显临时超时 1,800,000 ms 并调用唤醒。截图收集后用 `power-shell timeout -r` 恢复系统设置。该方式只用于调试，不计入正常功耗测试。 [首页](s0-results/exp_e0_home_20261109.jpeg) · [导航](s0-results/exp_e0_nav_20261109.jpeg) · [AR](s0-results/exp_e0_ar_20261109.jpeg) · [摄影](s0-results/exp_e0_photo_20261109.jpeg) · [红光](s0-results/exp_e0_red_20261109.jpeg) · [HDC 日志](s0-results/exp_e0_watch_20261109.hilog)

Hvigor 基线复建成功。重新从当前 ArkTS 转译后，光学、画幅、光污染、天文和太阳系对照脚本均退出 0，太阳系最大角距差 1.34′。现有 AR 姿态、投影、滤波脚本均完成，输出包含诊断样例，结果不等同于物理转腕测试。E0 切页使用 HDC 滑动，表冠旋转仍未验收。[测试原始输出](s0-results/exp_e0_math_20261109.txt)

## 4. 统一计算接口

后续阶段以纯 ArkTS 数学模块接收不可变的 `ObservationContext` 快照。建议输入为 `utcMs`、WGS84 纬度与经度、可空海拔、位置来源/精度、可选遮挡轮廓和数据版本。观测地点时区只用于界面格式化和当地日期边界，历算输入始终为 UTC。坐标明确区分 J2000、当日平赤道、TEME、地固与站心 ENU。卫星的未知海拔可按 0 m 估算并显式标记。

每个引擎的计算函数只接受原始数值和数据记录，由页面持有时间、传感器和文件服务。每个阶段新增可执行的 Node 数学夹具和真机用例。E0 定义输入、参考和验收边界，具体引擎随对应阶段实现。

## 5. 阶段计划、预算和降级

下列为首版增量目标，单位 KiB。包内数据与缓存可用哈希和文件大小验证，运行内存、CPU 和耗电由 E6 实测。预算适用于本机纯计算及数据缓冲，页面框架开销另测。

| 阶段 | 首版实施与验证 | 包内增量 / 临时运行内存 / 缓存上限 | 来源、许可与降级 |
|---|---|---|---|
| E1 深空取景 | 复用相机传感器和目标星表，`FramingEngine` 以赤道切平面进行矢量投影，再做旋转和矩形裁切。支持手动偏移中心、横竖和 20/35/50/85/100/135/200 mm。Sony 35.7×23.8 mm 的 85/135/200 mm 独立水平/垂直参考值为 23.72°/15.94°、15.06°/10.07°、10.20°/6.81°。测 RA 0h、高赤纬、出框、未知尺寸和位置角。 | ≤24 / ≤512 / ≤4 | Sony 官方规格和既有星表许可。尺寸缺失时只画点和名称，位置角缺失时不绘制有方向含义的椭圆，可标长短轴尺寸。几何取景不预测亮度或可拍性。[Sony 规格](https://www.sony.com/electronics/support/e-mount-body-ilce-7-series/ilce-7rm4/specifications) |
| E2 流星雨 | `MeteorEngine` 按太阳黄经和带年份的极大数据建预报。处理辐射点漂移、月光、太阳高度、未来 12–24 小时曲线和跨年/极昼。ZHR 作为参考参数，标明数据年份与不确定性。 | ≤32 / ≤384 / ≤8 | IMO 年历是候选来源。公开可读未确认可分发完整表，E2 核查许可并保留逐条来源。数据过期时仅显示活跃期与参考太阳黄经，收录漂移参数时保留有效范围。[IMO 年历](https://www.imo.net/calendar/) |
| E3 卫星过境 | 先 ISS，`SatelliteEngine` 采用固定版本且通过参考向量的 SGP4，实现 TEME→地固→站心 ENU，独立对照方位、仰角及 AOS/LOS。验证近切阈值、跨 UTC 午夜、损坏元素和元素历元。进出光照与观察地暮光共同用于可见性提示。 | ≤192 / ≤1024 / ≤128 | 候选 `satellite.js` 为 MIT，复用前锁版本、保存版权声明并验证 ArkTS 构建。CelesTrak OMM 格式可作为输入，轨道数据分发与刷新遵循数据源政策并在 E3 确认。数据无效、过旧或缺失时停止精确预测，保留前台可用提示。[SGP4 对照](https://celestrak.org/software/tutorials/sgp4.php) · [MIT 许可](https://github.com/shashwatak/satellite-js/blob/develop/LICENSE.md) · [OMM 格式](https://celestrak.org/NORAD/documentation/gp-data-formats.php) · [数据政策](https://celestrak.org/usage-policy.php) |
| E4 手动星桥 | `StarHopEngine` 先复用现有恒星与指定目标。候选按可见方位、遮挡、高度和用户星等限制筛选，再以 Dijkstra 或 A* 综合角距、亮度与步数。手动起点、逐步星图、位置角、重规划。测 M31/M42/M45/M13/M57/M27、无路径、RA 跨界和极区。 | ≤24 / ≤1024 / ≤8 | 复用已署名的 HYG 与星表数据。按 Bortle 9 场景从亮星开始，用户可调整可见极限。无路径时指出是遮挡、星等不足或选点不可见。 |
| E5 极轴辅助 | `PolarAlignEngine` 分粗摆位和人工漂移向导。粗摆位显示半球、数学天极方位和纬度绝对值对应的高度。漂移向导先做子午圈方位检查，再判断南/西南阳台能否执行东西向高度检查。支持 60/120/180 秒、人工方向记录、试调与复测。P-C 只在输入和条件数足以解算时启用。 | ≤64 / ≤512 / ≤128 | 经典漂移步骤以 PHD2 文档作为参考，自写向导，用户自行观察相机图像。东/西低空被挡时只提供确实可做的步骤或标注几何较弱。方向映射取决于半球、成像镜像及架台姿态，不使用通用螺丝方向。粗摆位不判“已对准”，无需北极星视线和激光。[漂移法参考](https://openphdguiding.org/man/Tutorials.htm) |
| E6 整合 | 统一二级入口，回归离线、红光、传感器释放与异常恢复。按同一设备和亮度记录冷启动、切页、峰值内存、包大小、CPU 与 30 分钟功耗。分别记录测试过程、失败与回滚。 | 每阶段单独核对，整合后复测 | 先使用表上已经验证的能力。系统授权界面、后台提醒与长时间功耗另列实测状态。 |

## 6. 后续阶段与回滚

E1 和 E2 依赖 E0，可依次交付。E3 的门禁为可复核的 SGP4 参考值与轨道数据许可。E4 先做手动，姿态模式另行验证。E5 先交付 P-A/P-B 与场地可行性判定，P-C 单列。E6 只在 E1–E5 达到各自阶段门禁后进入。

E0 无产品源码变更。后续阶段用独立模块和入口接入，采用单独的 Preference 键和版本化数据，不改写既有观测记录。回滚时撤除对应阶段入口与模块，并以本报告 HAP 哈希核验可回装基线。下一阶段等待用户确认。
