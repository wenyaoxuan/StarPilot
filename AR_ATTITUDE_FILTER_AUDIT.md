# AR 姿态滤波审计

日期：2026-11-08  
目标：确认当前是否有滤波、抖动/漂移/延迟来自哪一层，并对照 Sky Map 的实现。

## 1. 当前实现

`ArPage.ets:52–85`：

- ORIENTATION 回调直接写 `centerAz = alpha`，无平滑。
- ROT 回调直接 `azAltOfAxis()`，写 `centerAlt`，无平滑。
- 唯一“过滤”：
  - `qn < 0.5` 丢弃 ROT 四元数（`ArPage.ets:62`）
  - ORIENTATION 超过 2 s 无数据才回退 ROT 航向（`ArPage.ets:79`）
  - 绘制节流 90 ms（`ArPage.ets:126`）
- 没有：
  - SLERP/四元数插值
  - 1€ filter
  - 加速度/陀螺仪互补滤波
  - 真实传感器时间戳
  - accuracy 状态
  - NaN/Inf 检查
  - q/-q 符号统一（无插值时不影响，但未来滤波必须）
  - 静止死区/漂移补偿
  - 采样率和刷新率解耦

## 2. 采样与刷新

- 传感器：ORIENTATION/ROT/GYRO 均请求 100 ms；实测 ORIENTATION 中位 100 ms。
- 绘制：`requestDraw()` 最短 90 ms，即约 11 Hz；传感器与绘制频率接近。
- 由于没有时间戳，绘制不知道“这一帧用了多旧的姿态”；ORIENTATION 和 ROT 两个回调各自触发绘制，可能在同一帧混用不同时刻的数据。

## 3. 参考实现：Sky Map / Stardroid

### 3.1 OneEuroQuaternionSmoother

文件：`AR_AUDIT/refs/stardroid/OneEuroQuaternionSmoother.kt`

关键点：

- 在四元数上做 1€ filter，不是对 yaw/pitch/roll 简单平均。
- 使用 SensorEvent 的硬件 `timestamp` 计算真实 dt；不依赖采样率。
- q 与 -q 双覆盖：`dot(prev,raw)<0` 时取反，避免 SLERP 走长弧。
- 角速度先做 1 Hz 低通，再按速度调 cutoff；静止时强滤、运动时低延迟。
- 速度有 noise floor，避免噪声反复打开 cutoff。
- NaN 会“吸收”状态；检测到不可用四元数时 `restart + heal`。
- 超过 1 s 间隔（后台恢复）直接 restart，不追赶旧姿态。
- 最终用 SLERP。

### 3.2 旧版 SensorSmoother

文件：`AR_AUDIT/refs/stardroid/SensorSmoother.java`

- 旧版是简单低通/阻尼，不是 1€；Sky Map 已用 1€ 替代，因为固定低通无法区分抖动和真实运动。

### 3.3 Sky Map troubleshooting

- 明确区分 **calibration** 与 **accuracy**：高精度状态也可能被外部磁场干扰。
- 抖动排查：关闭 legacy sensors、提高 Steadiness（1€ 的 minCutoff）、调整 Ease off when moving（beta）。
- 说明“平滑”与“延迟”是权衡，不能只加低通。

## 4. 当前滤波缺口

| 项目 | 当前 | Sky Map 参考 | 影响 |
|---|---|---|---|
| 四元数插值 | 无 | SLERP | 抖动/跳变 |
| 自适应低通 | 无 | 1€ | 静止抖、运动滞后 |
| q 符号 | 未处理 | dot<0 取反 | 未来插值会走长弧 |
| 时间戳 | `Date.now()` | SensorEvent timestamp | 无法算真实 dt |
| 采样率解耦 | 无 | 时间基滤波 | 不同设备频率不同 |
| NaN/Inf | 无 | restart/heal | 可能永久冻结 |
| accuracy | 丢弃 | 监控/提示 | 不知道罗盘不可靠 |
| 静止漂移 | 无检测 | 诊断抖动/精度 | 长时间指向漂移 |
| 混合源 | alpha + ROT 各自更新 | 统一矩阵 | 目标游移 |

## 5. 已有测量

### 5.1 静止 alpha

`ori_session.log` 末 20 帧：315.798–315.814°，峰峰 0.016°。  
说明 ORIENTATION 静止本身很稳；当前画面抖动不能只怪 alpha。

### 5.2 AR_ATT

269 条日志，raw=alt，2.5–61.9°。采样被日志节流到约 500 ms，不能用于抖动统计；只能证明高度链路。

### 5.3 缺失

- 没有静止 60 s 的 AR 目标/星点抖动 RMS。
- 没有转动响应延迟（ms）。
- 没有停止后稳定时间。
- 没有 10 分钟以上漂移。
- 没有异常数据恢复时间。

这些必须在 `AR_TEST_PLAN.md` 的真机测试中补。

## 6. 风险判断

1. **抖动**：当前无滤波，ROT 10 Hz 直接驱动绘制；高精度 ORIENTATION 稳定，但 ROT/混合更新会造成星图轻微跳动。
2. **漂移**：没有长时间测试；系统融合可能缓慢漂移，尤其磁环境弱（23.7–36 µT）。
3. **延迟**：没有滤波，运动延迟低；如果直接加低通，会引入 lag。应使用 1€ 而不是固定 EMA。
4. **目标游移**：航向和高度来自不同融合源、不同回调时刻；即使各自稳定，组合后目标位置可能每秒轻微游移。
5. **天顶锁**：`zenithLock` 在 84° 锁定、60° 才释放，属于 UI 状态机，不是滤波；会引入 24° 的滞回，靠近天顶时目标不可对准。

## 7. 审计结论

- 当前 AR **没有姿态滤波**，不是“滤波参数不对”。
- 不应直接替换成 1€；先统一姿态源（P1），再用带时间戳的 1€ 四元数滤波（P2）。
- 需要建立抖动/延迟/漂移的量化基线，否则无法判断修复是否有效。
- 参考实现已下载：`AR_AUDIT/refs/stardroid/OneEuroQuaternionSmoother.kt`。
