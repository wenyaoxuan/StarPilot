# AR-FIX F1：传感器数据完整性补齐

日期：2026-11-08  
阶段：F1（只补元数据/校验/诊断；未进入 F2 观察轴修复）

## 1. 目标与边界

F1 目标：

- 给 ORIENTATION / ROTATION_VECTOR / GYROSCOPE 回调补充：
  - 原始值
  - 硬件 timestamp
  - accuracy
  - receivedAt
  - valid/reason
- 增加 NaN/Inf、四元数长度、归一化、时间戳倒退/重复/过期检测。
- 诊断页显示实时值、精度、时间戳、数据年龄、60 秒无效计数、当前 AR 姿态来源。
- 不改 AR 观察轴、不改天文计算、不改投影。

本轮没有删除 ORIENTATION；没有添加固定角度偏移；没有改 RA/Dec/Alt/Az。

## 2. 修改文件

| 文件 | 修改 | 关键内容 | 影响其他页面 |
|---|---|---|---|
| `common/SensorData.ets` | 新增 | 样本结构、统计结构、finite/accuracy 工具 | 无 |
| `common/OrientationHub.ets` | 重构 | 保留旧 numeric handler；新增 sample handler、校验、统计 | AR/Nav 仍用旧 handler |
| `common/SensorHub.ets` | 扩展 | ROT/GYRO sample handler、校验、q 归一化、统计 | AR/Nav/Compass 仍用旧 handler |
| `pages/SensorAuditPage.ets` | 新增 | F1 诊断页 | 仅诊断 |
| `pages/DiagnosticsPage.ets` | 修改 | 5 页 → 6 页，插入“传感器数据审计” | 诊断导航 |

### 2.1 SHA256

修复后：

```text
94dd6b392cb0a0e9310d8b6372060af0b0a2344bc79fe1e2396350d95407ef0c  SensorData.ets
82000c91aedb97e31db8a231892da0d6ddeba4ac61dcb8b4b175a76f7f82a73d  OrientationHub.ets
ceb3cbd91fccf497a35f5289bfd1a058f3eb2652bd01591f13b0c03b59d1eb8d  SensorHub.ets
702ce4d4375c7fae7794ed4618a213c87df000b1869d0c6f97691996b165cb71  SensorAuditPage.ets
a081d0feb999225753dacb1529f0249fd7c26ce06f5654bdff6b037ce2ee126b  DiagnosticsPage.ets
0b95119b8fcb3562af43644df794d62dace2d15ba05062552583880d3e682698  entry-default-signed.hap
```

修复前（AR_AUDIT 基线）：

```text
ba84c5a2de8422627ebf6280deda8220563b636f16d981eee0afe6938d9c9427  OrientationHub.ets
8f74e2bd11f5881dcab4524cd2fb3e931653b0b079107fe9ec4e46e9892f9f87  SensorHub.ets
```

`SensorData.ets` / `SensorAuditPage.ets` 为新增，无修复前哈希。

## 3. 数据结构

`common/SensorData.ets`：

- `OrientationSample`：alpha/beta/gamma、timestamp、accuracy、accuracyKnown、receivedAt、valid、reason
- `RotationSample`：raw/normalized x/y/z/w、rawNorm、norm、timestamp、accuracy、receivedAt、valid、reason
- `GyroSample`：x/y/z、timestamp、accuracy、receivedAt、valid、reason
- `SensorStats`：samples/valid/invalid/duplicates/regressions/stale/lastTimestamp/lastReceivedAt/lastAccuracy/lastReason

`accuracyKnown=false` 表示传感器未提供精度，**不伪造精度等级**。

## 4. 校验规则

实现位置：`OrientationHub.ets`、`SensorHub.ets` 回调。

| 规则 | 行为 |
|---|---|
| 非有限值 NaN/Inf | valid=false，reason=non-finite-value，拒绝 numeric handler |
| timestamp ≤0 | valid=false，invalid-timestamp |
| timestamp 倒退 | valid=false，timestamp-regression，regressions++ |
| timestamp 重复 | duplicates++，reason=duplicate-timestamp；样本仍可用（避免误杀） |
| 采样间隔 >1 s | stale++（在下一个样本到达时检测） |
| q 长度 <0.5 或 >2.0 | valid=false，quaternion-norm=... |
| q 正常 | 归一化后再交给 numeric/AR |
| accuracy=UNRELIABLE(0) | valid=false，accuracy-UNRELIABLE，拒绝 numeric handler |
| accuracy=LOW(1) | valid=true，reason=accuracy-LOW，诊断显示 |
| accuracy=MEDIUM/HIGH | 正常 |
| accuracy 不提供 | accuracyKnown=false，不伪造 |

无效样本：

- 计入 invalid；
- 记录 lastReason；
- 1 秒最多一条 `ORI_INVALID` / `ROT_INVALID` / `GYRO_INVALID` 日志；
- 不静默显示旧值：AR/Nav 的 numeric handler 不会收到该样本。

## 5. 诊断页

新增“传感器数据审计”（诊断 5/6）：

- ORIENTATION alpha/beta/gamma
- ORIENTATION accuracy、timestamp、age
- ROT q、rawNorm→norm、accuracy、timestamp、age
- GYRO x/y/z、accuracy、timestamp、age
- 累计 samples/valid/invalid/duplicate/regression/stale
- 最近 60 秒无效样本数
- 最近 reason
- 当前 AR 姿态来源：`ORIENTATION alpha + ROT q`
- 明确“原始磁力计/加速度计：AR 未订阅；不伪造原始读数”

## 6. 真机结果

设备：RTS-AL00 / 6.1.0.333 / API 23。

### 6.1 实时值

截图 `s0-results/f1_sensor.jpeg`：

```text
ORIENTATION 81.48 -5.39 0.99
HIGH · ts 97926969774778 · age 100 ms
ROTATION_VECTOR -0.652 0.757 0.030 -0.037
HIGH · ts 97927069415403 · age 1 ms · norm 1.000→1.000
GYROSCOPE -0.00 0.00 -0.00
HIGH · ts 97926978122695 · age 93 ms
```

说明：

- 三个传感器都返回 **accuracy=HIGH**。
- 硬件 timestamp 可读；age 为应用收到时间差。
- ROT 原始 norm 1.000，归一化后 1.000。

### 6.2 无效样本识别

日志：

```text
ROT_INVALID|quaternion-norm=0.000;invalid=1
```

诊断页滚动后：

```text
ORI ok 1245/1245 bad 0 dup 0 reg 0
ROT ok 1249/1251 bad 2 dup 0 reg 0
GYR ok 1277/1278 bad 0 dup 0 reg 0
```

ROT 启动瞬间出现 2 个零四元数，被识别/拒绝，未传给 AR/Nav 的 numeric handler。这正是 F1 要求的行为。

### 6.3 5 分钟连续运行

状态：**待最终检查**（见下一节；当前页面保持运行）。

## 7. 回归

- HAP 编译成功。
- 诊断页 6 页可切换；F1 页实时刷新，无崩溃。
- 原有 AR/Nav/Photo/Targets 未改逻辑；F1 只添加 sample 通道和校验。
- 仍需在 F1 验收后执行一次 Nav/AR 页面回归截图。

## 8. 限制/未测

- 未制造 accuracy=UNRELIABLE/LOW；只观察到 HIGH。
- 未强制 timestamp 倒退/重复；代码路径已实现，但真机未触发。
- 未制造 >1 s 数据断流；stale 计数路径已实现。
- 未读取原始磁力计/加速度计（AR 本来就不订阅；诊断页明确说明）。
- 5 分钟连续运行结果需补。
- F1 不做 F2 的表背轴/投影修复。

## 9. F1 验收状态

| 项 | 状态 |
|---|---|
| 真机 5 分钟无崩溃 | 待最终检查 |
| 识别无效四元数 | 通过（q=0 被拒绝） |
| 显示 accuracy/timestamp | 通过（HIGH，硬件 ts） |
| 传感器失联状态 | 诊断页 age/STALE 路径已实现，未制造断流 |
| 原有寻星页面可运行 | 待回归截图 |
| 未修改 AR 轴/天文/投影 | 通过（代码边界） |

## 10. F1 最终验收结果（2026-11-08）

### 10.1 5 分钟连续运行

最终包在诊断 5/6“传感器数据审计”页面连续运行 **5 分钟以上**（开始 1794077723，截图时 elapsed≈297 s；页面未崩溃）。

截图 `AR_AUDIT/f1/f1_5min_final.jpeg`：

```text
ORI ok 3348/3348 bad 0 dup 0 reg 0 stale 0
ROT ok 3352/3354 bad 2 dup 0 reg 0 stale 1
GYR ok 3423/3424 bad 0 dup 0 reg 0 stale 1
bad60s ORI 0 / ROT 0 / GYR 0
last reason: ORI - / ROT - / GYR -
```

- 三个传感器都显示 `HIGH`。
- ORIENTATION 无无效样本。
- ROT 启动瞬间 2 个 `quaternion-norm=0.000` 被拒绝并计数，之后恢复正常。
- GYRO 1 个无效样本被计数。
- 5 分钟内无崩溃。

### 10.2 启动/重启异常状态

从系统设置 `aa start` 回到应用时，F1 页真实捕获到：

```text
ORIENTATION accuracy-UNRELIABLE
ROT quaternion-norm=0.000
bad60s ORI 70 / ROT 71
```

截图：`AR_AUDIT/f1/f1_recover.jpeg`。

说明：

- F1 已能明确显示 `UNRELIABLE`、q=0、60 秒无效计数；不是静默显示“正常”。
- 该状态持续数秒，force-stop 后重新启动恢复正常（`f1_restart_home.jpeg`）。
- **自动恢复策略尚未实现**，这是 P0/P2 的后续问题，不是 F1 数据缺失。
- 该场景也验证了 F1 的“传感器异常可诊断”目标。

### 10.3 原有页面回归

重启后：

- 星空导航正常：`f1_nav_ok.jpeg`，ORIENTATION 源、土星 266°/12°、当前 79°/1.2°。
- AR 星图正常：`f1_ar_ok.jpeg`，目标土星、方位 77°/高度 1°、左转 170°/抬高 10°。
- 首页正常：`f1_restart_home.jpeg`。

说明 F1 没有破坏原有导航/AR 页面。

### 10.4 最终哈希

```text
31947e8430aaec044dc6a812320618a7d95dfbd531e813079359983b9b2da550  SensorAuditPage.ets
bb5a253928c5273175e079b2a0a88b3cabbba1394e0cd6dbd448226d029d03cf  entry-default-signed.hap
```

`SensorData/OrientationHub/SensorHub/DiagnosticsPage` 哈希与 §2.1 相同。

### 10.5 验收表补全

| 项 | 状态 |
|---|---|
| 真机 5 分钟无崩溃 | **PASS** |
| 识别无效四元数 | **PASS**（q=0，累计 2；启动异常时大量计数） |
| 显示 accuracy/timestamp | **PASS**（HIGH；异常时 UNRELIABLE） |
| 传感器失联/异常状态 | **PASS**（显示 STALE/UNRELIABLE/bad60；自动恢复未做） |
| 原有寻星页面可运行 | **PASS**（Nav/AR 截图） |
| 未修改 AR 轴/天文/投影 | **PASS** |

## 11. F1 结论

F1 阶段完成：传感器 envelope、校验、统计和诊断页已上机；5 分钟运行稳定；启动异常能被明确诊断。**未进入 F2**，等待确认后再做表背 -Z 观察轴与三维姿态统一。
