# AR 传感器数据审计

日期：2026-11-08  
范围：AR 页面实际读取的传感器，不把原始数据伪装成系统融合结果。

## 1. 实际 API 来源

| 用途 | API | 位置 | 频率 | 实际字段 |
|---|---|---|---|---|
| 航向 | `SensorId.ORIENTATION` | `OrientationHub.ets:40` | 100 ms（10 Hz） | `alpha`, `beta`, `gamma` |
| 高度/姿态 | `SensorId.ROTATION_VECTOR` | `SensorHub.ets:257` | 100 ms（10 Hz） | `x,y,z,w` |
| 保持 ROT 融合 | `SensorId.GYROSCOPE` | `SensorHub.ets:235` | 100 ms（10 Hz） | `x,y,z` |
| 加速度 | AR 页面**未订阅** | — | — | NavPage/CompassPage 才订阅 |
| 磁力计 | AR 页面**未订阅** | — | — | NavPage/CompassPage 才订阅 |

结论：

- AR **不是**在读取原始磁力计/加速度计，也不是自己做九轴融合。
- 航向来自系统融合的 ORIENTATION；高度来自系统融合的 ROTATION_VECTOR。
- 两者是**两个独立融合源**，AR 没有把它们统一到同一个四元数/旋转矩阵。
- 这解释了为什么“航向 + 高度”可能各自看起来正常，但组合到屏幕后目标仍对不准。

## 2. SDK 数据字段

`@ohos.sensor.d.ts`：

- `Response` 带：
  - `timestamp`：设备启动后的纳秒时间
  - `accuracy`：`SensorAccuracy`（0=UNRELIABLE，1=LOW，2=MEDIUM，3=HIGH）
- `OrientationResponse` 继承 `Response`，带 `alpha/beta/gamma`
- `RotationVectorResponse` 继承 `Response`，带 `x/y/z/w`

当前 `OrientationHub`/`SensorHub` 只把数值传给 handler，**accuracy 和 timestamp 全部丢弃**。因此：

- 无法知道 ORIENTATION 当前是否 UNRELIABLE/LOW；
- 无法用硬件时间戳做滤波、插值、延迟测量；
- 无法识别“高精度但被冰箱/钢筋干扰”的假稳定（Sky Map troubleshooting 明确区分 calibration 与 accuracy）。

## 3. 传感器信息（真机）

`ORI_INFO` 日志：

```json
{"sensorName":"orientation","vendorName":"huawei","sensorId":256,
 "minSamplePeriod":20000000,"maxSamplePeriod":1000000000,
 "precision":6.099999904632568,"power":39.226600646972656,
 "isMockSensor":false}
```

- 传感器存在，id=256，非 mock。
- 最小周期 20 ms，最大 1000 ms；当前请求 100 ms。
- 标称功耗约 **39.2 mA**；AR/导航同时订阅时是常驻功耗重点。
- 没有拿到精度等级字段（SDK 的 `accuracy` 在响应里，被代码丢弃）。

## 4. 实测数据

### 4.1 采样率

`ori_session.log` 中 4044 个 `ORI_SAMPLE`：

- 中位间隔 **100 ms**
- 均值 99.995 ms
- P95 103 ms

### 4.2 静止稳定性

同一段静止数据末 20 帧 alpha：

- 范围 **315.798–315.814°**
- 峰峰值约 **0.016°**
- 这说明系统 ORIENTATION 在静止时本身很稳；**画面抖动更可能来自 ROT 高度/绘制混合，而不是 alpha 本身**。

历史干净北向测试：

- alpha 359.76–359.83°，14 帧峰峰值约 0.07°。
- 四方向测试：北≈29.5°（当时环境干扰）、东≈134.8°、南≈214.7°、西≈287.6°；方向顺时针；干净复测北向≈0°。

### 4.3 AR 俯仰日志（AR_ATT）

基线文件：`AR_AUDIT/baseline/ar_att.log`

- 269 条样本
- `raw` 与 `alt` 完全一致
- 范围 2.5–61.9°
- `center` 最大 61.9°
- 没有触发 `lock=true`（未到 84°）

结论：`asin(w.z)` 高度链路能随 12 点轴俯仰变化；此前“竖直锁地平线”是错误高度取反 + 0° 下限钳制造成的，不是传感器无数据。

### 4.4 磁场

`ori_session.log` 中 `COMPASS` 日志 `mag`：

- 49 条
- 范围 **23.7–63.5 µT**
- 常见 24–36 µT
- 深圳地磁总量约 44–46 µT

结论：

- 存在弱场/干扰时段，AR 没有磁力计订阅，也没有任何磁场模长/精度警告。
- 系统 ORIENTATION 的磁航向会受环境影响；Sky Map 文档明确指出“校准状态高 ≠ 指向准确”，外部金属/磁铁无法由 App 修正。
- 用户已实测手表系统指南针与手机有偏差，并接受“以手表系统方向为基准”。

## 5. 磁北/真北

- ORIENTATION 的 alpha 来自系统方向融合；SDK 没有说明它输出磁北还是真北。
- `Astro.ets` 的 `targetHorizontal()` 输出的是**真北**方位（地理坐标）。
- AR 直接把 alpha 与目标真北方位相减，**没有显式磁偏角处理**。
- 深圳磁偏角约 −2～−3°；不足以解释几十度误差，但会贡献固定偏差。
- 没有证据表明系统 ORIENTATION 已应用 WMM；也没有证据表明重复应用了磁偏角。需要在 P0 用已知方位/系统指南针确认。

## 6. 传感器精度与恢复

当前缺失：

- 未读取 `accuracy`；
- 未在 UNRELIABLE/LOW 时提示校准/切换回退；
- 未区分“系统融合源”和“原始磁力计”；
- 未检测 NaN/Inf；
- ROT qn<0.5 直接丢弃，没有计数/恢复提示；
- ORIENTATION 超过 2 秒无数据才回退 ROT 航向（`ArPage.ets:79`）；
- 没有重启后重新读取/校准状态的记录。

## 7. 审计结论

| 项目 | 结果 |
|---|---|
| ORIENTATION 是否存在 | 是，id=256，10 Hz |
| 是否系统融合 | 是（不是原始磁力计） |
| AR 是否读原始磁力计 | 否 |
| AR 是否读陀螺仪 | 是，仅用于维持 ROT |
| AR 是否读加速度计 | 否 |
| 航向来源 | ORIENTATION alpha |
| 高度来源 | ROT +Y 轴 `asin(w.z)` |
| 磁北/真北 | 未显式处理 |
| 磁偏角重复应用 | 未发现，但未验证系统是否已加 |
| 磁场模长异常 | 有（23.7–36 µT 时段），AR 未警告 |
| accuracy/timestamp | SDK 有，代码丢弃 |
| 实测采样率 | 10 Hz |
| 静置 alpha 抖动 | 约 0.016–0.07°（系统方向本身） |

## 8. 必须补做的真机测试

1. 水平静止 60 s：记录 ORIENTATION/ROT 的 accuracy、alpha、alt、q。
2. 顺时针 360°、逆时针 360°：检查 alpha 单调性、0/360 跨界、目标方位是否连续。
3. 30°/60°/90° 倾斜：同时记录 ORIENTATION beta/gamma、ROT alt、目标方位。
4. 重启后重新读取：确认传感器订阅、精度状态、校准数据未被覆盖。
5. 远离金属/磁铁重复北向：对比系统指南针与手机，确认磁偏角策略。
