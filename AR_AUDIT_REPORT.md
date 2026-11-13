# AR-AUDIT-01 总报告

- 日期：2026-11-08
- 设备：HUAWEI WATCH 5 46mm，RTS-AL00，HarmonyOS 6.1.0.333（API 23）
- 应用：`com.starpilot.audit`，AR 入口在星空导航页右上角
- 审计范围：现有 AR 寻星导航的传感器、坐标、姿态、天文计算、屏幕投影与目标对准
- **本轮只做审计和测试，没有修改 AR/追踪代码。**

## 1. 结论摘要

土星的**天文坐标本身是正确的**。以 2026-11-08 02:15 CST、深圳为例：

| 来源 | 高度 | 方位 |
|---|---:|---:|
| StarPilot `solarHorizontal(SATURN)` | 22.904° | 261.173° |
| astronomy-engine 2.1.19 | 22.946° | 261.173° |
| 差 | −0.041° | 0.000° |

现场 AR 截图（`ar_revert_flat.jpeg`）显示中心 322°/3°，土星提示“左转 62° · 抬高 23°”，与目标约 260°/26° 一致。**因此“无法对准土星”不是 RA/Dec 或行星历算错误，优先查姿态帧、指向轴、投影和目标反馈。**

六个现象与初步归因：

| 现象 | 主要类别 | 证据 | 结论 |
|---|---|---|---|
| 目标位置不准 | 坐标映射 + 投影 | AR 用 ORIENTATION 航向 + ROT 高度混合；屏幕用简单方位/高度差 | 高概率 |
| 转动手表星图方向不对 | 坐标轴 + 投影 | 12 点轴/表背轴/屏幕法线未统一定义；无 roll | 高概率 |
| 倾斜后目标异常 | 投影 | 无透视除法、无背面判断；倾斜时等距投影误差急剧增大 | 已量化 |
| 指南针方向不准 | 传感器/环境 | 磁场 23.7–63.5 µT，含弱场/异常；无精度状态、无磁偏角处理 | 高概率/环境相关 |
| 画面抖动 | 滤波 | AR 无任何平滑；10 Hz 直接绘制 | 确定 |
| 静止漂移 | 滤波/传感器 | 无 1€/SLERP；无硬件时间戳；无精度监控 | 确定 |

## 2. 审计方法与基线

- 冻结当前 AR 相关文件与哈希：`AR_AUDIT/baseline/SHA256SUMS.txt`
- 当前 Git commit：`9236590f75111a9ba482b1de27f00338862947ca`（工作区包含后续功能改动，未提交）
- 当前签名 HAP SHA-256：`faa5b8f47bf050ec5227f234f78497b8898c94f55d123ef50c93b8841bfbecc8`
- 基线截图：`AR_AUDIT/baseline/ar_revert_flat.jpeg`、`ar_page3.jpeg`、`ar_cam_final.jpeg`
- 基线日志：`AR_AUDIT/baseline/ar_att.log`、`ori_session.log`
- 数学测试：`tools/ar-audit/ar_math_test.mjs` → `AR_AUDIT/baseline/math_test_output.txt`

## 3. 现有 AR 结构

| 文件 | 作用 | 关键行 |
|---|---|---|
| `pages/ArPage.ets` | AR 页面、Canvas 绘制、目标标记 | 52–85 姿态；183–294 星空/行星；306–356 目标 |
| `common/OrientationHub.ets` | 系统 ORIENTATION 共享订阅，10 Hz | 25–31 回调；40 订阅 |
| `common/SensorHub.ets` | ROT/GYRO/ACC/MAG 共享订阅，10 Hz | 224–257 |
| `common/Fusion.ets` | 四元数转轴 az/alt | 45–75 |
| `common/Astro.ets` | J2000→岁差→地平坐标 | 317、338、372 |
| `common/SolarSystem.ets` | 月球/行星历算 | 415、467 |
| `pages/NavPage.ets` | 目标选择后的导航、AR 入口 | 204–248 目标；顶部 AR |
| `pages/Index.ets` | AR 覆盖层 | `showAr` 分支 |

## 4. 已确认事实

### 4.1 传感器来源

- AR 航向来自 **`SensorId.ORIENTATION.alpha`**（系统融合方向），10 Hz。
- AR 高度来自 **`ROTATION_VECTOR` 的 12 点轴（+Y）**，10 Hz。
- AR 同时订阅 **GYROSCOPE**，仅用于维持 Watch 5 ROT 融合；**不读原始加速度计/磁力计**。
- NavPage/CompassPage 还会订阅 ACC/MAG，但 AR 页面没有。
- `OrientationResponse` 和 ROT response 都含 `accuracy` 与 `timestamp`，当前 **全部丢弃**。

### 4.2 实测数据

- ORIENTATION：请求 100 ms，实测中位间隔 **100 ms**；静止末 20 帧 alpha 315.798–315.814°，波动约 **0.016°**。
- 干净北向历史测试：alpha 359.76–359.83°，波动约 **0.07°**；四方向验证 alpha 顺时针递增、0=北。
- AR_ATT 俯仰测试：raw=alt=center，从 2.5° 到 **61.9°**，说明 `asin(w.z)` 高度链路可用；未测到 90°。
- 磁场：同一时段 COMPASS 日志 `mag` 23.7–63.5 µT，常见 24–36 µT；深圳地磁约 44–46 µT，存在弱场/干扰。
- 系统指南针与手机指南针存在偏差，用户已接受“以手表系统方向为基准”。

### 4.3 天文计算

- `targetHorizontal()` 对静态目标做 J2000→当日岁差→地平坐标（`Astro.ets:317/338/372`）。
- 行星/月球走 `SolarSystem.ets`；对拍 astronomy-engine：月球 ≤0.70′、行星 ≤1.34′。
- 土星现场目标值与 astronomy-engine 一致（见上表）。
- 未发现 RA/Dec、恒星时、经纬度或时间基准错误。

### 4.4 投影

当前 AR 不是透视投影，而是：

```text
x = cx + (targetAz - centerAz) * (W / 60)
y = cy - (targetAlt - centerAlt) * (W / 60)
```

问题已数学量化：

| 中心高度 | 与透视投影的像素误差 RMS | 最大 |
|---:|---:|---:|
| 0° | 8.4 px | 23.1 px |
| 30° | 42.5 px | 117.2 px |
| 60° | 112.5 px | 285.5 px |
| 80° | 129.9 px | 287.9 px |

另外：
- 无 `cos(alt)` 收敛，方位差在高度角大时被高估。
- 无 roll：手表绕视线滚转 45° 时，目标屏幕位置从 (233,0) 变到 (398,68)（参考透视），当前实现不动。
- 无背面判断：目标在背后（az 差 180°）仍会被当成“屏幕外可转向”；透视参考应判 `z<=0` 丢弃。
- “已进入视场”用矩形 `|dAz|<=30 && |dAlt|<=30`；az=30/alt=30 的真实角距是 41.4°，是**假阳性**，且标记可能落在圆屏外。
- 圆屏有效区没有遮罩；方形 Canvas 四角的内容可能被表壳裁掉。

## 5. 问题分类（本轮不定修复）

| 编号 | 类别 | 问题 | 证据 | 优先级 |
|---|---|---|---|---|
| A1 | 传感器/环境 | 磁场弱/受扰，系统方向与手机有偏差 | 23.7–63.5 µT；用户实测差异 | P0 |
| A2 | 传感器数据 | 丢弃 accuracy/timestamp；无校准状态 | `OrientationHub.ets` 25–31；SDK Response | P0 |
| A3 | 姿态融合 | ORIENTATION 航向 + ROT 高度混用，无统一四元数 | `ArPage.ets` 52–85 | P1 |
| A4 | 坐标映射 | 12 点轴/表背/屏幕法线未定义清楚；无 roll | `Fusion.ets` 68–74；`ArPage` 183–294 | P1 |
| A5 | 滤波 | 无 SLERP/1€；无 q 符号处理；无真实时间戳 | `ArPage` 60–85；`SensorHub` 10 Hz | P2 |
| A6 | 天文 | 目标 RA/Dec/Alt/Az 正确；但未处理磁北/真北 | 土星对拍 0.04°/0.00°；无 declination | P3 |
| A7 | 投影 | 等距投影、无透视除法、无背面、无圆屏遮罩 | 数学测试；`ArPage` 183–356 | P4 |
| A8 | UI/对标 | 无“已对准”判定；箭头对背后目标可能误导 | `ArPage` 306–356 | P4 |

## 6. 对“土星无法对准”的判断

按证据排序：

1. **目标坐标正确**（土星 az 261.17°/alt 22.90°，与 astronomy-engine 一致）。
2. 目标标记在 `dAz=dAlt=0` 时一定画在中心；因此单纯投影误差不会让“永远无法对准”，但会：
   - 让目标在错误的屏幕位置出现；
   - 让边缘箭头方向/是否“已进入视场”判断错误；
   - 在大角度/滚转时让用户追错方向。
3. 更像根因的是 **A3/A4：AR 的“中心”是 12 点轴，而用户可能按手机 AR 习惯用表背/屏幕方向对准**；同时航向来自 ORIENTATION、高度来自 ROT，两个融合源没有统一到同一个姿态四元数。
4. 没有“已对准”容差提示，用户只能凭红圈/十字判断，容易误判。

**建议先做 P0/P1 的真机对照测试，再决定改轴还是改投影；不要先用固定偏移掩盖。**

## 7. 交付物

- `AR_SENSOR_DATA_AUDIT.md`
- `AR_COORDINATE_SYSTEM.md`
- `AR_ATTITUDE_FILTER_AUDIT.md`
- `AR_ASTRONOMY_AUDIT.md`
- `AR_PROJECTION_AUDIT.md`
- `AR_TEST_PLAN.md`
- `AR_FIX_PRIORITY.md`
- 本文件

## 8. 参考实现

- Sky Map / Stardroid：`SensorOrientationSource.kt`、`OneEuroQuaternionSmoother.kt`、`SkyProjection.kt`、`SkyCamera.kt`、`troubleshooting.md`
- Vega：`script.js`（DeviceOrientation → Three.js camera quaternion、FOV、手动 Sync）
- Stellarium Web Engine：`src/projection.c`、`src/projections/proj_perspective.c`、`src/observer.c`
- Astronomy Engine 2.1.19：`Equator()`、`Horizon()`、`Illumination()`

参考文件已下载到 `AR_AUDIT/refs/`，不直接移植 Android API。
