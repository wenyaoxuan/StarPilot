# AR-FIX F3：三维相机透视投影

日期：2026-11-08  
阶段：F3（只替换屏幕投影；尚未做 F4 时间同步/滤波）

## 1. 目标

把旧的：

```text
x = cx + shortestDelta(centerAz, objAz) * (W / 60)
y = cy - (objAlt - centerAlt) * (W / 60)
```

替换为：

```text
world ENU vector = (cos alt·sin az, cos alt·cos az, sin alt)
cameraX = dot(v, right)
cameraY = dot(v, up)
cameraZ = dot(v, forward)
z > 0 才可见
x = cx + f·cameraX/cameraZ
y = cy - f·cameraY/cameraZ
f = (W/2) / tan(FOV/2)
```

- 使用 F2 的 `forward=-Z / up=+Y / right=+X(物理)`。
- 加入 `z<=0` 背面剔除。
- 加入圆形安全区裁剪（圆屏）。
- 目标箭头与正常目标位置分离。
- 未改 F2 姿态源、天文计算、RA/Dec。

## 2. 代码变更

| 文件 | 修改 | 关键 |
|---|---|---|
| `common/SkyProjection.ets` | 新增 | `enuVector`、`projectPoint`、`angularSepVec`、`screenDirection` |
| `pages/ArPage.ets` | 重写绘制 | 星/行星/网格/地平线/目标全部走 `projectPoint` |
| `tools/ar-audit/projection_f3_test.mjs` | 新增 | 纯数学投影测试 |

### 2.1 SkyProjection

- ENU 向量：北 0°、东 90°、南 180°、西 270°。
- `projectPoint()` 返回 `x/y/z/visible/insideCircle`。
- `z <= 1e-4` → `visible=false`，且不返回屏幕坐标。
- 圆形安全半径：`min(W,H)/2 - 16`（466 px 屏幕约 217 px 半径；Canvas vp 单位下约 100.5）。
- `screenDirection()` 只用于边缘箭头，不混入正常目标位置。

### 2.2 ArPage

- 高度/方位环、30° 方位子午线、N/E/S/W 全部由 ENU 向量投影。
- 星星/行星先 `enuVector(az,alt)`，再 `projectPoint`；`!insideCircle` 不画。
- 目标：
  - `z>0` 且圆内且角距 ≤FOV/2：正常红圈/十字。
  - 角距 ≤2°：提示“已对准”。
  - `z<=0`：不画正常位置，只提示“在相机后方 · 请转身”。
  - 前方但圆外：独立边缘箭头；方向来自屏幕投影向量，文字用真实 Δaz/Δalt。
- 圆屏外的星、行星、网格点全部丢弃。

## 3. 数学测试

脚本：`tools/ar-audit/projection_f3_test.mjs`  
输出：`AR_AUDIT/baseline/f3_projection_test_output.txt`

中心朝北/地平线：

| 目标 | 屏幕 | z | visible | circle |
|---|---|---:|---|---|
| 北 0/0 | (233, 233) | 1.000 | true | true |
| 东 90/0 | — | 0.000 | false | false |
| 南 180/0 | — | −1.000 | false | false |
| 西 270/0 | — | −0.000 | false | false |
| 天顶 0/90 | — | 0.000 | false | false |

- 15° 右/左：x=341.1 / 124.9，符合 FOV 60° 透视。
- roll 90°：目标 alt30 从中心上方移到 (466,233)，说明 roll 进入相机 up/right。
- 背后目标 `z=-1`：visible=false，不产生假屏幕位置。
- 角距 30° 中心/目标：精确 30.000°。

## 4. 真机结果

截图：`AR_AUDIT/f3/f3_ar.jpeg`

```text
相机 -Z
方位 182° · 高度 85° · FOV 60°
土星 · 右转 86° · 降低 76°
```

- 表背朝天顶时，AR 中心 85°。
- 圆形网格/边缘被圆屏裁剪；星点、行星都限制在圆内。
- 目标土星在视场外，使用独立边缘箭头；不把土星画到错误天空位置。
- 顶部/底部 HUD 正常。

### Roll 说明

箭头方向是**屏幕空间**（包含手腕 roll），文字“降低 76°”是**世界高度差**。当手腕滚转接近 180° 时，两者可能看起来不一致：目标世界高度更低，但屏幕上的箭头被 roll 转到上方。这是相机坐标系的正确行为，不是目标坐标错误。F4/F3 后续可在 UI 上同时显示“屏幕方向”和“世界高度”以避免误解。

## 5. 验收

| 项 | 状态 |
|---|---|
| 使用 cameraZ 透视 | **PASS**（数学+真机） |
| z<=0 背面剔除 | **PASS**（数学；真机目标未在背后） |
| 圆形安全区 | **PASS**（网格/星点裁剪） |
| 目标箭头与正常位置分离 | **PASS** |
| roll 进入投影 | **PASS（数学构造）；真机 roll 动作待 F4/F5 验收** |
| FOV 记录 | 固定 60°，未做硬件标定 |
| 旧 az/alt 差值 | 仅保留在目标文字 Δaz/Δalt，不再用于绘制 |
| F4 时间同步/滤波 | 未做 |

## 6. 文件哈希

```text
fd5b321417b4acaabc4940ba55e1ca610170de5a8b2bf61458de9cc62a6945b9  SkyProjection.ets
99d276a60d349bb9b6e474346e33e91f3d88fb4df18afc68603dbf8f7e128569  ArPage.ets
4047c880b4dd34c719439fc6d192cb3d55059d89f7caf4e07a3fb5100c1e9725  entry-default-signed.hap
```

## 7. 限制/下一步

- FOV 固定 60°，未用真实相机/表壳标定；圆屏半径取 100.5 vp（16 vp 安全边）。
- 真机 roll 0/30/60/90° 动作测试未做；数学已验证。
- 目标角距/屏幕方向在 roll 大时可能文字与箭头观感不同，F4/F5 可优化 UI。
- 下一步：F4 时间同步与滤波；等待确认。

## 8. F5 更新（2026-11-08）

F3 的投影公式本身未变：

```text
cameraX/Y/Z = dot(v, right/up/forward)
z > 0 → x = cx + f·xc/zc, y = cy − f·yc/zc
```

F5 只修正了输入 `CameraPose` 的世界 X 符号（ROT 世界向量镜像）。因此：

- `projectPoint`、背面剔除、圆形安全区、边缘箭头逻辑不受影响。
- 本文第 6 节的 `ArPage.ets` / HAP 哈希是 F3 时点值，**不是最终值**；最终哈希见 `AR_FIX_F5_NORTH_REFERENCE.md`。
- F3 的纯投影数学测试仍有效（它构造物理 `CameraPose`，不依赖传感器符号）。

