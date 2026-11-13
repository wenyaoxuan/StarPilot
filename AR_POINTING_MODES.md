# AR 指向模式：12 点（表背模式已取消）

日期：2026-11-08  
范围：AR 只保留 12 点指向；表背模式、MAG 订阅和模式切换已移除

## 1. 最终行为

- AR 只有 **12 点指向模式**；
- 用表盘 12 点边缘指目标，屏幕朝向自己；
- 屏幕上方始终对齐地平线，不需要靠手腕滚转；
- 顶部右侧固定显示 `12点`，不再是可点击按钮；
- 不再订阅磁力计，不再计算表背姿态，不再有 `AR_QDIR` 日志。

## 2. 实现

```text
方位 = ORIENTATION alpha（12 点航向）
高度 = asin(ACC_Y / |ACC|)
forward = (sin az·cos alt, cos az·cos alt, sin alt)
up      = 世界 +Z 在垂直于 forward 的平面上的投影
right   = cross(forward, up)
```

- 这是从 ORIENTATION + 加速度计直接构造 12 点方向，不依赖 ROT 四元数的 `q/-q` 方向。
- ACC_Y 是设备 +Y（12 点）在世界竖直方向上的分量；12 点朝地时高度为负，朝上时为正。
- forward 接近天顶时，世界 +Z 投影退化，回退到 ROT 四元数构造。
- 表背模式（ACC+MAG）代码、MAG 订阅、模式切换按钮已删除。
- 不改变 F3 的 `projectPoint`、F4 的 `AttitudeFilter`、GPS 和天文历算。

## 3. 真机验证

### 3.1 平放

截图：`s0-results/mode12_flat2.jpeg`

```text
12点 方位 263° · 高度 5° · 14:26
月球 234°/28° · 左转 30° · 抬高 22°
ori=263.25°
acc=-0.2 / 0.98 / 9.84
```

- 方位与 ORIENTATION alpha 一致（263.3 vs 263.25）。
- 高度 5.7° 与 ACC_Y/|ACC| 一致。
- 地平线在中心下方，符合“12 点略朝上”的平放姿态。

### 3.2 仅 12 点模式（取消表背后的构建）

截图：`s0-results/ar_12only.jpeg`

```text
12点 方位 69° · 高度 5° · 14:41
月球 236°/25° · 在指向后方
ori=68.68°
acc=0.2 / 0.9 / 9.9
```

- 顶部右侧固定 `12点`，没有切换按钮。
- MAG 日志只有 `HUB|mag off`，确认没有磁力计订阅。
- 中心方位与 ORI 一致，说明 12 点模式链路正常。

## 4. 使用

1. 打开 AR；
2. 屏幕朝向自己；
3. 用表盘 **12 点边缘**对准目标；
4. 看底部 `12点 方位/高度` 和“抬高/降低”；
5. 12 点朝地时高度为负，抬向天空后变正。

## 5. 限制

- 目标 az/alt 仍按真北计算；ORIENTATION 航向没有应用磁偏角（深圳约 -3.64°）。
- 12 点模式的 up 是重力水平，目标在正天顶附近时方向退化，需要回退逻辑。
- ORIENTATION 或 ACC 失效时回退到 ROT 四元数；此时可能出现 `q/-q` 方向歧义。
- 表背模式已删除，不再维护。

## 6. 文件哈希

```text
ec03c067766bea354d01d5490c1fcfe3715ad42b5cbe45813f2eb583b571d9f7  CameraPose.ets
52c95841bd5d34c1a098445fd0f317bb460f9c864c102c1aa96e060ffbabaaa2  ArPage.ets
2b2a38a37760d2d4eb323dfad58388fd6fb517a7290db38c693483e976f51b02  entry-default-signed.hap
```
