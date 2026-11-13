# 系统方向（ORIENTATION）探针与接入报告

日期：2026-11-07/08  
设备：HUAWEI WATCH 5 46mm，RTS-AL00，HarmonyOS 6.1.0.333 / API 23  
范围：先做最小测试页；验证后把系统航向接入 `CompassPage`/`NavPage`，**目标位置计算未改**。

## 结论

1. **`SensorId.ORIENTATION` 在 Watch 5 上可用。** `getSingleSensor` 成功返回 `orientation / huawei / id=256`，`sensor.on` 订阅成功，实测 **10 Hz** 输出 alpha/beta/gamma。
2. **`Sensor.subscribeCompass()` 不能在 Watch 5 的 Stage 工程中使用。** 它来自 `@system.sensor` 的 Lite Wearable/FA 模型；编译直接报 `11706008 FA model interface used in Stage projects`，并标记 deprecated since 8。
3. **alpha 已验证为表盘 12 点航向。** 四方向顺时针递增；干净环境 12 点朝北时 alpha≈0°（连续 14 帧 359.76–359.83°）；同姿态与旧 ROT 12 点轴差 0.5°。
4. 系统指南针是 **MCU hybrid 应用**（`hybrid_deploy_type=mcu`），启动后会绕过 AP 的屏幕常亮设置并导致 hdc 掉线；这解释了测试中“打开系统指南针屏幕就不常亮”的现象。
5. 系统已接入：`CompassPage`/`NavPage` 的 12 点航向改为 ORIENTATION alpha；ROT 只提供高度/姿态并在 ORIENTATION 失效时回退。旧的四方向/持久化偏移在首次启动时迁移为 0。用户接受手表系统指南针与手机存在绝对偏差，不再以手机为基准。

## 1. SDK 检查

### 1.1 ORIENTATION（完整手表 Stage API）

`E:/DevEco Studio/sdk/default/openharmony/ets/api/@ohos.sensor.d.ts`：

- `SensorId.ORIENTATION = 256`（API 9 起）
- `function on(type: SensorId.ORIENTATION, callback: Callback<OrientationResponse>, options?: Options): void`
- `function off(type: SensorId.ORIENTATION, callback?: Callback<OrientationResponse>): void`
- `function getSingleSensor(type: SensorId): Promise<Sensor>`；同步版 `getSingleSensorSync` 从 API 12 起
- `OrientationResponse`：
  - `alpha`: z 轴旋转角，0–360°
  - `beta`: x 轴旋转角，0–±180°
  - `gamma`: y 轴旋转角，0–±90°
- SDK 注释明确提示可用“8 字校准”改善方向精度，理论误差 ±5°，实际取决于驱动/算法。

### 1.2 subscribeCompass（Lite/FA）

`@system.sensor.d.ts`：

- `@syscap SystemCapability.Sensors.Sensor.Lite`
- `@famodelonly`
- `@since 3`
- `@deprecated since 8`
- `@reserved ["liteWearable"]`
- `static subscribeCompass(options: SubscribeCompassOptions): void`
- `static unsubscribeCompass(): void`

`@kit.SensorServiceKit.d.ts` 虽然重新导出了 `Sensor` / `CompassResponse` / `SubscribeCompassOptions`，但底层仍是 `@system.sensor`。把它加入 Stage 工程后编译失败，证据见下。

### 1.3 Stage 工程编译证据

`build_ori2.log`：

```text
ERROR: 11706008 FA model interface used in Stage projects.
Error Message: This API is used only in FA Mode, but the current Mode is Stage.
At OrientationPage.ets:150:9 / 150:16 / 175:7 / 175:14 / 178:37 / 179:46 / 180:47

WARN: 'Sensor' has been deprecated.
WARN: 'subscribeCompass' has been deprecated.
WARN: 'unsubscribeCompass' has been deprecated.
WARN: 'direction' has been deprecated.
```

结论：**不可导入到当前 Watch 5 Stage 应用**。已从最终代码中移除该尝试，保留本报告作为证据。

## 2. 真机结果（ORIENTATION）

测试页：首页 → 诊断 → 第 4/5 页“系统方向探针”。

| 项目 | 结果 |
|---|---|
| `getSingleSensor(SensorId.ORIENTATION)` | 成功 |
| 传感器信息 | `orientation / huawei / id=256` |
| `sensor.on` | 成功 |
| 请求周期 | 100 ms |
| 实测频率 | **10 Hz** |
| 错误码 | 无 |
| 样本 | 20 个，实时 |
| 当前姿态读数 | `alpha 253.1°`、`beta -19.6°`、`gamma -4.7°`（第一次） |
| 平放姿态读数 | `alpha 255.0°`、`beta -5.4°`、`gamma 3.5°`（第二次） |
| 传感器参数 | `hardwareVersion=1`、`minSamplePeriod=20 ms`、`maxSamplePeriod=1000 ms`、`precision=6.1`、`power=39.2 mA`、`isMockSensor=false` |
| 日志节拍 | 23:41:13 连续 11 条样本，间隔约 100 ms（10 Hz） |
| 证据 | `s0-results/ori_page.jpeg`、`s0-results/ori_mark.jpeg` |

实测 `ORI_INFO`：

```json
{"sensorName":"orientation","vendorName":"huawei","firmwareVersion":"","hardwareVersion":"1",
 "sensorIndex":0,"sensorId":256,"deviceId":-1,"location":1,
 "maxRange":0.009576806798577309,"precision":6.099999904632568,
 "power":39.226600646972656,"minSamplePeriod":20000000,
 "maxSamplePeriod":1000000000,"isMockSensor":false}
```

注意 `power=39.2 mA` 是传感器标称功耗，若 10 Hz 常驻会明显增加耗电；后续接入应考虑按需/降频，而不是全程 10 Hz。

测试页还提供“北/东/南/西”四个手动标记按钮，点击后写入 `ORI_MARK` 日志；这是为了做四方向零点/递增方向验证，不会自动假设 alpha=12 点。

## 3. 四方向实测（2026-11-07 23:46–23:48）

表盘朝上平放，12 点依次对准北/东/南/西，每次停稳后点探针页的对应按钮。首轮测试桌面有磁干扰，**绝对偏移不可靠，但递增方向有效**：

| 标记 | alpha 读数 | 多次点击范围 |
|---|---:|---:|
| 北 | 29.5° | 29.1–29.8° |
| 东 | 134.8° | 134.5–135.2° |
| 南 | 214.7° | 214.7–214.8° |
| 西 | 287.6° | 287.0–288.2° |

相邻差值：北→东 +105.3°、东→南 +80.0°、南→西 +72.9°。方向明确是 **顺时针递增**；差值不是精确 90°，说明手动摆放有 ±15° 误差。

### 同姿态对照旧 12 点轴（关键）

把探针页与旧的 ROT 罗盘页在同一静止姿态下对照：

- ORIENTATION：`alpha 316.5°`
- 旧 ROT 12 点方位：`azTop 316.0°`，`rawTop 316.0°`，`offset=0`
- 差值约 **0.5°**

日志：`COMPASS|azTop=316.0;rawTop=316.0;offset=0;src=ROTATION_VECTOR`  
结论：**alpha 就是表盘 12 点方向的方位角**，顺时针递增，零点是北；不需要额外的坐标轴变换。四方向测试里“北=29.5°”的偏差主要来自手动摆放/局部磁场，而不是 alpha 参考轴偏移。

原始日志节选：

```text
ORI_MARK|北=29.088;b=-3.401;g=-4.222
ORI_MARK|北=29.752;b=-3.047;g=-3.718
ORI_MARK|东=135.182;b=0.659;g=1.279
ORI_MARK|东=134.450;b=0.775;g=1.265
ORI_MARK|南=214.736;b=-2.996;g=4.483
ORI_MARK|南=214.767;b=-3.003;g=4.343
ORI_MARK|西=287.129;b=-5.086;g=-1.341
ORI_MARK|西=288.199;b=-5.208;g=-1.317
COMPASS|azTop=316.0;rawTop=316.0;offset=0;src=ROTATION_VECTOR
```

### 磁北/真北

SDK 没有说明 ORIENTATION 使用磁北还是真北；从实现看它来自地磁融合，理论上应为磁北。当前测试点磁场仅 **24 µT（偏弱/异常）**，说明手表附近有金属/磁干扰，绝对方向会受影响。需要用系统指南针在同一姿态读数确认是否一致，并确认它显示的是磁北还是真北。

### 干净环境北向复测（23:54–23:55）

移到远离金属/电子设备的表面，仅让 12 点朝北，重复点“北”：

| 时间 | alpha | beta | gamma |
|---|---:|---:|---:|
| 23:54:24 | 0.000°（首帧，可能尚未填充） | 0.0 | 0.0 |
| 23:54:25 | 1.119° | -2.08° | -6.09° |
| 23:54:26 | 0.902° | -2.07° | -6.04° |
| 23:54:27 | 0.738° | -2.18° | -5.52° |
| 23:55:45–47（连续 14 帧） | **359.76–359.83°** | -2.2° | -5.2° |

连续 14 帧 alpha 波动仅约 **0.07°**；12 点朝北时 alpha 在 0°/360° 附近。  
**零点=北、12 点轴、顺时针递增** 三个结论均成立。之前“北=29.5°”的 +30° 偏差来自摆放/磁环境，不是 alpha 定义。

证据：`s0-results/ori_north.jpeg`（界面显示 alpha 0.3°、beta -2.1°、gamma -5.9°）。

### 测试环境警告

较早四方向测试时旧罗盘记录 `mag=24 µT`，而深圳地区地磁场总量约 44–46 µT；当时桌面/附近物体存在明显磁干扰（可能金属桌面、电脑、手机）。这会让绝对方向产生几十度误差，也能解释四方向不是精确 90°。  
**结论：alpha 与旧 ROT 的 0.5° 一致性、以及干净环境北向 0° 复测都支持 alpha=12 点航向；绝对磁北/真北对照仍建议用系统指南针在同一干净姿态确认。**

### 倾斜

beta/gamma 在平放时约 `-5.5° / 3.4°`（旧 ROT 俯仰约 0°、横滚约 5.4°）。倾斜测试尚未做；alpha 在平放和多次点击中稳定，倾斜时是否受俯仰/横滚耦合影响仍需实测。

## 4. 系统指南针对照

- 系统指南针 bundle：`com.huawei.hmos.watch.compass`
- Ability：`MainAbility`
- 元数据：`hybrid_deploy_type=mcu`、`hybrid_mcu_view=128`
- `aa start` 可以启动，但启动后 hdc 无线连接掉线，截图回到无线调试设置页；同时 AP 的 `power-shell timeout` 屏幕常亮被绕过。

用户实测手表自带指南针与手机指南针也存在偏差，并明确接受“以手表系统方向为基准”继续，不再追求与手机绝对北一致。

这说明系统指南针是 MCU 侧 hybrid 应用，不能靠普通 `aa start` + 截图稳定对照。后续可选：

1. 用户手动打开系统指南针，读出表盘方向，同时让探针页在后台记录 alpha（需要 hdc 保持）；
2. 用物理四方向标记 + 已知地标/地图核对；
3. 若系统指南针无法稳定共存，则以四方向标记 + 旧 ROT 12 点轴对照确定映射。

## 5. 代码变更

- 新增 `starpilot-watch/entry/src/main/ets/pages/OrientationPage.ets`：只读探针。
- 新增 `common/OrientationHub.ets`：全应用共享一条 ORIENTATION 订阅，600 ms 延迟退订，避免 Swiper 切页/诊断页并发订阅。
- `CompassPage.ets`：`azTop/rawTop` 改为 alpha；ROT 只提供高度/姿态，并在 ORIENTATION 超过 2 s 无数据时回退。
- `NavPage.ets`：同上；目标方位/高度、左右/抬高提示算法未改，只替换航向来源。
- 两个页面首次加载时把旧 `heading_offset` 迁移为 0（`ori_heading_v2` 标记）；之后“归零”仍可作为显式用户偏移。
- `DiagnosticsPage.ets`：4 页 → 5 页，插入“系统方向”页。
- **未修改** `Fusion.ets`、`Astro.ets` 或目标位置计算。

真机接入结果：

```text
NAV|az=286.7;alt=-0.8;raw=286.7;offset=0;src=ORIENTATION;target=C20;tAz=312.0;tAlt=16.7
COMPASS|azTop=286.4;altTop=-0.8;rawTop=286.4;offset=0;src=ORIENTATION;pitch=2.6;roll=5.5
ORI_HUB|off ok
ORI_HUB|on ok 100ms
```

## 6. 下一步

1. **倾斜测试**：12 点抬高/压低约 30°、左右侧倾约 30°，记录 alpha 是否稳定、beta/gamma 如何变化（尚未做）。
2. **回退验证**：在 ORIENTATION 不可用的设备/场景确认自动回退 ROT，且 UI 标注 `ROTATION_VECTOR`。
3. **功耗实测**：orientation 标称 39 mA；当前只在 Nav/Compass 页 active 时 10 Hz 订阅，后续可降到 5 Hz 或按需。
4. 观察“归零”按钮是否还需要保留；目前默认偏移 0，不影响与系统方向一致。
5. 系统指南针与手机存在绝对偏差，用户已接受以手表系统方向为基准；不再用手机指南针做强制对齐。

## 7. 备注

- ORIENTATION 的 SDK 理论误差 ±5°，比现有 S0 罗盘基线（RMS 4.6°、最大 8.7°）同量级或更好；但必须以四方向实测为准。
- ORIENTATION 订阅只在 Nav/Compass 页 active 时建立，离开后 600 ms 退订；不会后台常驻。
- 系统指南针运行期间屏幕常亮失效，是 MCU 应用行为，不是 StarPilot 的 keep-screen-on 代码问题。
