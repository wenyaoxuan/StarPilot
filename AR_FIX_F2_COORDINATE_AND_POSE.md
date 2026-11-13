# AR-FIX F2：统一姿态坐标与观察轴

> **F5.1 更正（2026-11-08）**：本文的 `Camera Forward = -Z` 假设在 Watch 5 上被真机否定。`+Z` 才是表背法线；最终实现为 `forward=+Z / up=+Y / right=cross(forward,up)`。本文保留为 F2 时点记录，最终约定以 `AR_FIX_F5_NORTH_REFERENCE.md` 为准。

日期：2026-11-08  
阶段：F2（只统一点观察轴/姿态；尚未替换 F3 透视投影）

## 1. 目标

按用户确认的 B 模式：

```text
设备 +X = 表盘右侧
设备 +Y = 表盘 12 点
设备 +Z = 屏幕外法线
设备 -Z = 表背法线 = Camera Forward

Camera Forward = -Z
Camera Up      = +Y
Camera Right   = +X（物理右）
```

F2 只允许：

- 用 ROT 四元数建立统一 camera basis；
- 把 AR 中心从 +Y 改为 -Z；
- 保留 ORIENTATION 做对照/诊断；
- 增加数学测试。

不删除 ORIENTATION，不加固定角度偏移，不改天文 RA/Dec/Alt/Az，不先做 F3 投影。

## 2. 代码变更

| 文件 | 修改 | 关键 |
|---|---|---|
| `common/CameraPose.ets` | 新增 | `cameraPoseFromQuat`、`vectorAzAlt`、`axisAngleDeg` |
| `pages/ArPage.ets` | 修改 | AR 中心改为 ROT -Z；ORIENTATION 不再驱动 centerAz |
| `pages/SensorAuditPage.ets` | 修改 | 增加 F2 对照：ROT -Z vs ORIENTATION alpha |
| `tools/ar-audit/pose_test.mjs` | 新增 | 构造已知姿态的数学测试 |

### 2.1 CameraPose

```text
qDeviceToWorld = conjugate(qWorldToDevice)
forward = normalize(qDeviceToWorld * (0,0,-1))
upRaw   = normalize(qDeviceToWorld * (0,1,0))
right   = normalize(cross(forward, upRaw))
up      = normalize(cross(right, forward))
```

- 世界坐标 ENU；`vectorAzAlt` 用 `atan2(E,N)`、`asin(U)`。
- 不直接用原始 device +X 当 screen right：旧代码已确认 Watch 5 传感器 +X 相对物理 3 点镜像（旧罗盘用 `atan2(-x,y)`）。用 `forward × upRaw` 得到物理右手系。
- `right/up/forward` 两两正交、长度 1；roll 通过 +Y 的旋转自然进入 up/right。
- 没有使用 alpha/alt 拼接；没有固定偏移。

### 2.2 ArPage

- `rotHandler` 只做：
  - 校验 q（F1 已归一化）
  - `cameraPoseFromQuat`
  - `view = vectorAzAlt(pose.forward)`
  - `centerAz = view.az`, `centerAlt = view.alt`
- `oriHandler` 仍订阅，但只更新 `lastOriMs` 供状态/诊断；**不再写 centerAz**。
- 删除 +Y 的天顶 88° 锁定逻辑（那是 12 点轴专用）；F3 投影阶段再处理背面/透视。
- 顶部状态改为 `相机 -Z` / `等待 ROT`。

## 3. 数学测试

文件：`tools/ar-audit/pose_test.mjs`  
输出：`AR_AUDIT/baseline/f2_pose_test_output.txt`

构造 device→world 正交基，再转四元数；验证 `cameraPoseFromQuat`：

| 姿态 | forward az/alt | 期望 | 正交误差 | device +X vs right |
|---|---|---|---|---|
| 平放，屏幕朝上，12 点北 | 0.0 / −90.0 | 0 / −90 | 0 | 0.00° |
| 表背朝北地平线 | 0.0 / 0.0 | 0 / 0 | 0 | 0.00° |
| 表背朝东地平线 | 90.0 / 0.0 | 90 / 0 | 0 | 0.00° |
| 表背朝天顶 | 0.0 / 90.0 | 0 / 90 | 0 | 0.00° |

- 三个基向量长度 1，点积误差 ~1e-16。
- q 与 −q 的 forward/up 差 0。
- ENU 基准：北 0/0、东 90/0、南 180/0、西 270/0、天顶 0/90 全部正确。

结论：**forward=-Z、up=+Y、right=+X 的构造在数学上成立**；roll 由 up/right 自然携带，不需要单独角度。

## 4. 真机对照

### 4.1 F2 诊断页

截图：`AR_AUDIT/f2/f2_diag.jpeg`

```text
B ROT -Z: 187.9° / 84.6°
A ORI α:  70.3°
Δaz 117.6°
```

解释：

- A 是旧 ORIENTATION alpha（12 点轴航向）。
- B 是 ROT 表背 -Z 的方位/高度。
- 两者物理轴不同（12 点 vs 表背），差 90° 量级是**预期**，不能再把 alpha 直接当 AR 中心。
- 该差值也证明：旧实现“ORI 航向 + ROT 高度”是混合坐标系，F2 必须切到统一 ROT 姿态。

### 4.2 AR 页面

截图：`AR_AUDIT/f2/f2_ar2.jpeg`

```text
相机 -Z
方位 188° · 高度 85° · FOV 60°
土星 · 右转 79° · 降低 75°
```

- 表背朝天顶时，AR 中心显示 85°，不再是 12 点轴的地平线。
- 目标土星在下方，提示“降低 75°”，方向与目标 alt≈10° 一致。
- 顶部明确显示 `相机 -Z`。

### 4.3 原有页面

- 星空导航仍用 `ORIENTATION`（12 点语义）显示 74°/0.7°、土星 267°/10°，未受 F2 影响。
- 罗盘页仍用 +Y，不受影响。
- F2 只改变 AR 的观察轴。

## 5. F2 验收

| 项 | 状态 |
|---|---|
| 表背 -Z 是 AR 唯一 forward | **PASS**（代码/真机 `相机 -Z`） |
| +Y 是 screen up | **PASS**（CameraPose 数学） |
| +X 是 screen right | **PASS（构造基）；真实传感器 +X 镜像我方用 forward×up 规避，待 P1 真机轴向复核** |
| 航向/俯仰/roll 统一三维姿态 | **PASS（ROT 四元数）；roll 真机动作待测** |
| 不再用 +Y 作 AR 中心 | **PASS** |
| ORIENTATION 未删除 | **PASS**（保留对照） |
| 不加固定偏移 | **PASS** |
| F3 透视投影 | 未做（下一阶段） |

## 6. 文件哈希

```text
e08674fa9841aef093603842691f960db94f9abe77f87e0a87bc00debad6f86d  CameraPose.ets
7e9f5281f0533dd77806c4188a3ee8ccab77a3c5d51ace7a14c1e2e510adb25d  ArPage.ets
d6c0879133c30e06cae41c9ee6e473e9f736a394d3735600d7a1081eac5cf871  SensorAuditPage.ets
7c7fadd887d197ef4a114409da217992e55c3b436442154c63d2edf3e0a5964e  entry-default-signed.hap
```

## 7. 限制/下一步

- F2 仍使用旧的简单 az/alt 差值投影；大角度/roll 下星点和目标位置仍会错。F3 将替换为 `cameraX/Y/Z` + 透视除法 + `z<=0` 剔除 + 圆屏裁剪。
- roll 的数学已通过构造姿态，但尚未做真机 0/30/60/90° 动作测试。
- ORIENTATION 与 ROT 的 117.6° 差值不是误差结论，是不同物理轴的对照；F5 再确认磁北/真北。
- 下一步：F3 三维透视投影。等待确认。

## 8. F5 更新（2026-11-08）

F5 真机对照发现两件事：

1. ROT 解出的世界向量与 ORIENTATION / 天文 ENU 在**世界 X 方向镜像**。`CameraPose.cameraPoseFromQuat` 已对 `forward`/`upRaw` 做一次世界 X 取反；修正后同一姿态 `ROT +Y 298.7°` 与 `ORI α 298.9°` 相差 -0.2°。
2. **F2 的 `-Z = 表背` 假设在 Watch 5 上是错的。** 用户真机反馈：表背朝天空时显示地平线以下，表背朝地时反而有星星。实际 `+Z` 才是表背法线，`-Z` 是屏幕法线。F5.1 已把 `Camera Forward` 改为 `+Z`，并保留 `up=+Y`；HUD 显示 `相机 +Z`。

因此：

- 本文第 3 节的姿态构造和 `device +X vs right` 结论是 **F2 历史测试**，已被 F5 镜像修正取代。
- 本文第 6 节的 `CameraPose.ets` / HAP 哈希是 F2 时点值，**不是最终值**；最终哈希见 `AR_FIX_F5_NORTH_REFERENCE.md`。
- F5 的数学测试（含非对称 NE/20° 姿态、+Z forward）输出在 `AR_AUDIT/baseline/f5_pose_test_output.txt`。
- 最终相机约定是 `forward=+Z（表背）/ up=+Y（12 点）/ right=cross(forward,up)`；`right` 的符号需在表背朝天姿态下做左右对准验收。


