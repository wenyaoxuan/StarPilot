# AR-FIX F4：姿态时间同步与平滑

日期：2026-11-08  
阶段：F4（只处理 ROT 四元数时间戳/滤波；未进入 F5）

## 1. 目标

- 使用传感器事件 timestamp，而不是只用 `Date.now()`。
- 统一从 ROT 四元数得到姿态；不再拼接 ORIENTATION 航向 + ROT 高度。
- q 归一化、q/-q 一致、真实 dt、间隙重启、无效样本不参与滤波。
- 比较不滤波 / SLERP / 1€ Filter，量化静止抖动和阶跃响应。
- 不对 alpha/beta/gamma 做普通线性平滑。

## 2. 代码变更

| 文件 | 修改 | 关键 |
|---|---|---|
| `common/AttitudeFilter.ets` | 新增 | OFF / SLERP / 1€ 四元数滤波 |
| `pages/ArPage.ets` | 修改 | 改用 `subscribeRotSample`，使用 F1 的 timestamp/valid/accuracy |
| `tools/ar-audit/filter_test2.mjs` | 新增 | 合成静止噪声 + 30° 阶跃测试 |

### 2.1 数据流

```text
ROT sample (F1): x/y/z/w + timestamp(ns) + accuracy + valid
→ AttitudeFilter.update()
→ normalized/filtered quaternion
→ cameraPoseFromQuat()
→ F3 projectPoint()
```

- AR 不再使用 numeric `RotHandler`；使用 `RotationSampleHandler`。
- `ORIENTATION` 只保留诊断/对照，不进入姿态。
- 没有把旧航向和新高度拼接。
- F1 已拒绝 NaN/Inf、q 异常、accuracy UNRELIABLE；F4 再拒绝无效样本进入滤波。

### 2.2 AttitudeFilter

- OFF：归一化 raw。
- SLERP：固定 2 Hz cutoff 的指数 SLERP。
- 1€：
  - 角速度估计低通（1 Hz）
  - `cutoff = 1.0 + 0.12 × max(0, speed − 20)`（上限 30 Hz）
  - `alpha = 1 − exp(−2π·cutoff·dt)`
  - 用真实 dt（ns timestamp）
- q/-q：`dot(current, raw) < 0` 时取反。
- 首次样本、时间戳不前进、间隔 >1 s：restart，不追赶旧姿态。
- 无效样本：返回 valid=false，不改变 current。

## 3. 合成测试

脚本：`tools/ar-audit/filter_test2.mjs`  
输出：`AR_AUDIT/baseline/f4_filter_test2_output.txt`

条件：10 Hz、1.5° 静止噪声、t=2 s 时 30° 阶跃。

| 模式 | 静止输出 RMS | 输入 RMS | 阶跃到 <1° |
|---|---:|---:|---:|
| OFF | 1.05° | 1.05° | 0.0 s |
| SLERP | 0.70° | 1.05° | 0.4 s |
| 1€ | **0.42°** | 1.05° | 0.0 s |

- 1€ 对静止噪声抑制最好，阶跃响应也快（速度升高会打开 cutoff）。
- 这是**合成数学测试**，不能替代真机抖动/延迟测量。

其他测试：

- q/-q 输入：输出保持在 ±q 等价，无长弧。
- 1 s 以上间隔：`reset=true, reason=gap>1s`。
- 无效 q：不进入滤波。

## 4. 真机结果

截图：`AR_AUDIT/f4/f4_ar.jpeg`  
日志：`AR_FILTER`：

```text
mode=2;dt=100.5;cut=1.0;speed=1.2;reset=false
mode=2;dt=100.2;cut=1.0;speed=1.2;reset=false
...
```

- 1€ 模式（mode=2）生效。
- dt≈100 ms，符合 10 Hz。
- 静止速度 0.2–2.4°/s，cutoff 保持 1 Hz，说明静止时在强滤。
- 当前 AR 星图/目标正常显示；F3 透视投影保留。

### 未完成

- 没有真机 60 s 静止抖动 RMS。
- 没有真机转动响应延迟、停止稳定时间、快速转动跟随。
- 没有真机 360° 顺/逆时针、0/360 连续性。
- 这些需要用户按 `AR_TEST_PLAN.md` 的 A–D 动作配合，当前只有静态日志和合成数据。

## 5. 验收

| 项 | 状态 |
|---|---|
| 使用硬件 timestamp | **PASS**（`AR_FILTER dt` 约 100 ms） |
| q 归一化/符号/无效样本 | **PASS** |
| 长间隙重启 | **PASS（合成）** |
| 不拼接 ORI 航向 + ROT 高度 | **PASS** |
| 1€ 默认启用 | **PASS** |
| 静止抖动真机量化 | **未完成** |
| 转动延迟/停止稳定真机量化 | **未完成** |
| 360° 顺/逆时针连续性 | **未完成** |

## 6. 文件哈希

```text
b8a396961de297feb77790f3b5da474480b0aada50081e6a211382b372c9353f  AttitudeFilter.ets
2cbd9318df98eb951c922309fb1f899d8eec9cff6f06bbf30db0a1b367678b28  ArPage.ets
b43958675ce3f68c272051441cd2a9fcc6125282851b3715fdf9186666d48dd9  entry-default-signed.hap
```

## 7. 结论/下一步

- F4 的时间基、q 符号、间隙重启和 1€ 路径已实现并上机；合成测试显示 1€ 优于 OFF/SLERP。
- 由于缺少真机运动测试，F4 **不能宣称“抖动/延迟已验收”**；只能声明路径正确、静态日志正常。
- 下一步 F5：磁北/真北基准确认；之后再做 A–F 真机验收。
