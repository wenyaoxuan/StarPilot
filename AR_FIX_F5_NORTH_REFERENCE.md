# AR-FIX F5：北向基准、ROT 世界 X 镜像与 +Z 观察轴

> **最终状态（2026-11-08）**：表背模式已取消，当前 AR 只使用 12 点指向模式（ORIENTATION alpha + ACC_Y）。本文的 +Z/表背观察轴、`cameraPoseFromQuat` 方向验证是 F5 时点记录，不再决定最终 AR 观察轴。最终构建与测试见 `AR_POINTING_MODES.md` / `AR_FIX_TEST_REPORT.md`。

日期：2026-11-08  
阶段：F5（北向基准 + 观察轴符号；不改 F3 投影公式、不改 F4 滤波）

## 1. 目标

- 用 SDK 的 `getGeomagneticInfo` 读取观测点的磁偏角，作为真北/磁北换算依据。
- 在同一姿态下对照 ROT `+Y`（表盘 12 点）与 ORIENTATION `alpha`，确认两者是否同一物理轴、同一航向基准。
- 确认系统航向是磁北还是真北；在未确认前**不写死城市偏移，不应用固定 declination**。
- 确认表背观察轴（`+Z`/`-Z`）的符号，避免星图与物理天空上下颠倒。

## 2. 代码变更

| 文件 | 修改 | 关键 |
|---|---|---|
| `pages/SensorAuditPage.ets` | 修改 | 增加 `@Prop cityIndex`；调用 `sensor.getGeomagneticInfo`；显示 decl/dip/H；ROT `+Y` 与 ORI `alpha` 对照；B 行改标“相机 +Z” |
| `common/CameraPose.ets` | 修改 | **F5 关键修正 1**：对 ROT 解出的 world `forward`/`upRaw` 做一次世界 X 取反；**修正 2**：forward 从 `-Z` 改为 `+Z`（表背法线） |
| `pages/ArPage.ets` | 修改 | HUD 改为 `相机 +Z`；其余绘制链路不变 |
| `tools/ar-audit/pose_test.mjs` | 修改 | 姿态测试加入世界 X 镜像和 +Z 观察轴；新增非对称 NE/20° 姿态 |
| `AR_AUDIT/baseline/f5_pose_test_output.txt` | 新增 | F5 数学测试输出 |
| `AR_AUDIT/f5/f5_fix.jpeg` | 证据 | 诊断页 F5 行（+Y / ORI / decl） |
| `AR_AUDIT/f5/f5_ar2.jpeg` | 证据 | X 镜像修正后、仍用 -Z 的 AR 页面（历史） |
| `AR_AUDIT/f5/f5z_ar_plusZ.jpeg` | 证据 | +Z 修正后 AR 页面：屏幕朝上/表背朝地时高度 -84° |

### 2.1 F5 诊断行

`SensorAuditPage` 在诊断第 5/6 页显示：

```text
ROT +Y: 298.7° / 3.7° · ORI α 298.9° · Δ -0.2°
decl -3.64° · dip 34.38° · H 37799nT
B 相机 +Z: ...  A ORI α: 298.9°  Δaz ...
```

- `ROT +Y`：ROT 四元数旋转设备 `+Y` 到世界后的方位/高度；这是表盘 12 点轴。
- `ORI α`：系统 ORIENTATION 的 alpha，同一 12 点轴。
- `decl/dip/H`：`getGeomagneticInfo(LocationOptions, Date.now())` 的磁偏角、磁倾角、水平强度。
- `B 相机 +Z`：AR 实际使用的表背观察轴；它和 `+Y` 不是同一物理轴，`Δaz` 是预期差异，不能用于判断航向误差。

### 2.2 ROT 世界 X 镜像修正

F5 真机发现：ROT 解出的世界向量与 ORIENTATION/天文 ENU 在 X 方向镜像。修正只在 `cameraPoseFromQuat` 内做一次：

```ts
const fwdRaw = rotateByQuat(-qx, -qy, -qz, qw, new Vec3(0, 0, 1));
const upRaw  = rotateByQuat(-qx, -qy, -qz, qw, new Vec3(0, 1, 0));
const forward = normalize(new Vec3(-fwdRaw.x, fwdRaw.y, fwdRaw.z));
const up0     = normalize(new Vec3(-upRaw.x,  upRaw.y,  upRaw.z));
const right   = normalize(cross(forward, up0));
const up      = normalize(cross(right, forward));
```

- 这是**坐标系符号修正**，不是城市/磁偏角固定偏移。
- 修正后同一姿态 `ROT +Y 298.7°` 与 `ORI α 298.9°`，差 `-0.2°`。
- `SensorAuditPage` 的 `+Y` 对照使用同一 X 取反，保证诊断与 AR 使用同一约定。
- 该修正只针对 RTS-AL00 / 当前 Watch 5 传感器实现；不要外推到其他机型。

### 2.3 表背观察轴从 -Z 改为 +Z

真机反馈：**表背指向天空时 AR 显示地平线以下，表背朝地时反而有星星**。这不是南北偏移，而是观察轴取了反方向：`-Z` 是屏幕外法线，`+Z` 才是表背法线。旧实现等于一直朝手表背面相反方向看，整个星图与物理天空呈对跖（上下 + 左右同时反）。

修正：

```text
Camera Forward = +Z（表背）
Camera Up      = +Y（12 点）
Camera Right   = cross(forward, up)
```

- 只改 forward 的起始轴，仍保留 F5 的世界 X 镜像修正。
- HUD/诊断从 `相机 -Z` / `ROT -Z` 改为 `相机 +Z` / `B 相机 +Z`。
- 没有改 F3 的 `projectPoint`、F4 的 `AttitudeFilter`、天文 RA/Dec/Alt/Az。

### 2.4 没有做什么

- 没有把 `declination = -3.64°` 加到 AR 航向或 ORIENTATION。
- 没有写死深圳/任何城市的偏移。
- 没有用 `+Y` 与 `+Z` 的差值当误差（两者物理轴不同）。
- 没有改 F3 投影公式和 F4 滤波参数。

## 3. SDK 依据

本机 SDK：

```text
E:/DevEco Studio/sdk/default/openharmony/ets/api/@ohos.sensor.d.ts
```

| API | 证据 |
|---|---|
| `sensor.getGeomagneticInfo(locationOptions, timeMillis)` | API 9 起；按经纬度/海拔和时间返回 `GeomagneticResponse` |
| `GeomagneticResponse.deflectionAngle` | 文档定义为真北（地理北）与磁北（地磁水平分量）之间的夹角 |
| `GeomagneticResponse.geomagneticDip` | 磁倾角，水平面到磁场矢量的角度 |
| `GeomagneticResponse.levelIntensity` | 水平强度，nT |
| `GeomagneticResponse.totalIntensity` | 总强度，nT |
| `OrientationResponse.alpha` | 仅定义为绕 Z 轴旋转角，0–360°；**d.ts 没有说明磁北/真北** |

结论：SDK 能给出“真北−磁北”的差值，但**没有在 `OrientationResponse` 中声明 alpha 的北向基准**。因此不能仅凭 API 存在就认定 alpha 是真北或磁北。

## 4. 真机数据

观测城市：深圳（应用当前城市）。截图：`AR_AUDIT/f5/f5_fix.jpeg`。

```text
ROT +Y: 298.7° / 3.7°
ORI α:  298.9°
Δ:      -0.2°

decl:   -3.64°
dip:    34.38°
H:      37799 nT
```

### 4.1 能得到的结论

1. 修正世界 X 后，ROT `+Y` 与 ORIENTATION `alpha` 在**同一物理轴**上一致到 0.2°，远小于 ORIENTATION 的标称误差量级。
2. AR 的 ROT 姿态与导航/罗盘的 ORIENTATION 航向不再互相矛盾；F5 的 X 修正是必要的。
3. `getGeomagneticInfo` 在手表上可调用并返回合理量级（深圳 decl 约 -3.6°、dip 约 34°、H 约 3.8×10⁴ nT）。

### 4.2 不能得到的结论

- **不能确认 alpha 是磁北还是真北。** 两者在当前点只差 3.64°，而本次对照只比较了两个系统源，没有外部真北基准。
- 不能用“手表系统指南针与手机有偏差”作为北向基准证据；用户已明确接受该绝对偏差，且手机本身也可能有磁干扰/declination 设置差异。
- 不能把 `decl` 直接加到 AR 上；如果 alpha 已经是真北，会重复修正，产生 -3.64° 误差。

## 5. 数学测试

脚本：`tools/ar-audit/pose_test.mjs`  
输出：`AR_AUDIT/baseline/f5_pose_test_output.txt`

测试把“物理姿态”先转成世界 X 镜像后的 ROT 输入，再用 `+Z` 作为表背 forward，验证 `cameraPoseFromQuat` 能恢复物理 `forward/up/right`。

| 姿态 | forward az/alt | 期望 | 正交误差 | right 误差 |
|---|---|---|---:|---:|
| 平放，屏幕朝上，12 点北 | 0.0 / -90.0 | 0 / -90 | 0 | 0.00° |
| 表背朝北地平线 | 0.0 / 0.0 | 0 / 0 | 0 | 0.00° |
| 表背朝东地平线 | 90.0 / 0.0 | 90 / 0 | 0 | 0.00° |
| 表背朝天顶 | 0.0 / 90.0 | 0 / 90 | 0 | 0.00° |
| 表背朝 NE、高度 20° | 45.0 / 20.0 | 45 / 20 | 9.2e-17 | 0.00° |

其他：

- ENU 基准：北 0/0、东 90/0、南 180/0、西 270/0、天顶 0/90 全部正确。
- q / -q 的 forward/up 夹角均为 0。
- 非对称 NE 姿态覆盖了 X 镜像对 forward 和 up 同时生效的情况。
- “屏幕朝上/表背朝地”明确对应 forward 高度 -90°，与 +Z 表背轴的定义一致。

## 6. AR 真机结果

### 6.1 X 镜像修正后（仍用 -Z，历史）

截图：`AR_AUDIT/f5/f5_ar2.jpeg`（旧构建）。

```text
相机 -Z
方位 163° · 高度 85° · FOV 60°
火星 · 右转 121° · 降低 78°
```

该截图证明 X 镜像链路能运行，但后来确认 -Z 是屏幕法线，不是表背观察轴；这张图不再作为方向正确性的证据。

### 6.2 +Z 修正后

截图：`AR_AUDIT/f5/f5z_ar_plusZ.jpeg`（当前构建，手表屏幕朝上/表背朝地）。

```text
相机 +Z
方位 329° · 高度 -84° · FOV 60°
月球 在相机后方 · 请转身
```

- 表背朝地时 forward 指向地下（高度 -84°），因此天空目标全部在相机后方，显示“请转身”。
- 这与物理方向一致：不再出现“表背朝地却有星星”的对跖错误。

补充的传感器证据（同一次屏幕朝上姿态）：加速度计 `ACC 0.00 0.96 9.85`，说明物理 +Z 是屏幕外法线；但 ROT 经世界 X 取反后的 `+Z` 指向地下。**ROT 坐标系的 Z 与加速度计的 Z 相反**，所以 AR 用 ROT `+Z` 才是表背方向，不能用物理加速度计的 +Z/-Z 直接推断。这个差异已写入 `CameraPose.ets` 注释，避免后续再次把 forward 改回 -Z。

- 表背抬向天空时应变为正高度；该正向姿态仍需用户翻腕确认（见第 7 节）。

### 6.3 相机基现场校验（屏幕朝上，同一帧）

截图：`s0-results/gps_f5diag.jpeg`（F5 诊断 5/6 页，与传感器页同一放置姿态）。

```text
ORIENTATION α: 281.55°（12 点航向）
ROT q:         0.632  0.774  0.037  0.031
ACC:           0.00   0.96   9.85
```

用当前 `cameraPoseFromQuat`（+Z、世界 X 取反）计算：

| 轴 | 计算 az/alt | 物理期望 | 差 |
|---|---|---|---:|
| forward（表背） | 0.7° / **-84.5°** | 屏幕朝上 → 表背朝地 | 符合 |
| up（12 点） | **281.4°** / 1.0° | ORI α 281.55° | 0.15° |
| right（3 点） | **11.5°** / 5.4° | ORI α + 90° = 11.55° | 0.05° |

- `right` 与 12 点航向 +90° 一致，说明 **左右没有镜像**，`right = cross(forward, up)` 的符号正确。
- `up` 与 ORI α 一致，说明世界 X 取反后的 12 点轴正确。
- `forward` 指向地下，与屏幕朝上/表背朝地的物理姿态一致。
- 这一帧同时验证了 +Z、世界 X 取反和 right 符号，不能再用“加速度计 +Z 向上”直接推断 AR forward。

## 7. 验收

| 项 | 状态 |
|---|---|
| `getGeomagneticInfo` 真机可调用 | **PASS** |
| decl/dip/H 数值合理 | **PASS**（-3.64° / 34.38° / 37799 nT） |
| ROT +Y 与 ORI α 同轴一致 | **PASS**（Δ -0.2°） |
| 世界 X 镜像修正 | **PASS**（真机 + 数学） |
| 表背轴改为 +Z | **PASS（代码/数学/现场基）** |
| 表背朝地 → 负高度 | **PASS**（真机 -84°） |
| 相机 right 不镜像 | **PASS**（right 11.5° vs ORI+90=11.55°） |
| 表背朝天 → 正高度 | **待用户翻腕确认** |
| 目标对准月球/土星 | **待 A–F 真机验收** |
| 未应用固定 declination/城市偏移 | **PASS** |
| alpha 磁北/真北基准 | **未确认** |
| 静止抖动/转动延迟量化 | **未完成**（F4 遗留） |

## 8. 残余风险

1. **正向姿态未复核**：当前只观察到表背朝地 -84°；表背朝天是否稳定 +84° 需用户翻腕确认。
2. **左右镜像风险**：+Z 把观察方向翻转 180°；如果表背朝天时目标左右仍反，需要再检查 `right = cross(forward, up)` 的符号（不要直接加固定 az 偏移）。
3. **北向基准未定**：若 alpha 实为磁北，而目标方位按真北计算，深圳残余约 3.64°；在 60° FOV 内仍可见，但“已对准 ≤2°”可能系统性偏 3.6°。
4. **磁干扰**：手表靠近金属/磁体时 alpha 与 ROT 都会偏；系统没有硬铁/软铁校准，本阶段不实现。
5. **X 镜像的机型依赖**：当前只对 RTS-AL00 验证；换机型需重新做 `+Y` vs ORI 对照。
6. **传感器恢复**：从系统设置返回应用时仍可能出现 ORIENTATION UNRELIABLE / ROT q=0；当前需 force-stop 恢复，F1 诊断可见，自动恢复未实现。

## 9. 文件哈希

当前 +Z 构建（F5.1）：

```text
ea98b733e511a1310118cca67a96b836ed22d4eb53695f4745110b559995f096  CameraPose.ets
0fe849f3a465389b0155df8cda34b8b79340becfc38760e99e7f6cd948c1916f  SensorAuditPage.ets
6cc66ea9e5a164b2224db725d13f72b140b5ee85270de14993e06d745015803e  ArPage.ets
afa1bddbe0c8325e86425c0a4c6b0ef414f79ad3881f0b206b87dcc4e59752f4  tools/ar-audit/pose_test.mjs
b96072394bfaaabb8219fb8c70f579e8bff4adce2a09526258f6d59d956478c3  entry-default-signed.hap（含 GPS + 时间/目标 HUD）
b77eafccbf615e770b11913180382454a272061d46581fff9c2cb494f74c3fb8  AR_AUDIT/f5/f5z_ar_plusZ.jpeg
```

旧 -Z 构建哈希保存在 `AR_AUDIT/baseline/F5_SHA256.txt`，仅作历史证据。

## 10. 结论/下一步

- F5 完成了“同一物理轴一致性”“世界 X 镜像修正”和“表背 +Z 观察轴修正”。
- **北向基准本身仍未确认**：没有外部真北/系统指南针读数证明 alpha 是磁北还是真北，因此不应用 declination、不写死偏移。
- 下一步：
  1. 用户翻腕确认表背朝天时高度为正、星图在上方。
  2. 按 `AR_TEST_PLAN.md` 做最终 A–F 真机验收（静止抖动、360°、俯仰、roll、背面剔除、传感器异常）。
  3. 若用户能用系统指南针/已知地理方位确认 alpha 基准，再决定是否应用 `deflectionAngle`。
  4. 汇总 `AR_FIX_TEST_REPORT.md`、`AR_FIX_CHANGED_FILES.md`、`AR_FIX_ROLLBACK.md`。
