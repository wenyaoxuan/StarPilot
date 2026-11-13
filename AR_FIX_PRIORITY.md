# AR 问题分级与修复优先级

日期：2026-11-08  
原则：先消除传感器/坐标不确定性，再动投影和滤波；禁止用固定偏移掩盖坐标错误。

## 1. 总排序

| 优先级 | 主题 | 目标 | 不改会怎样 |
|---|---|---|---|
| P0 | 传感器真值与精度 | 确认航向基准、accuracy、磁环境 | 后面所有修复都建立在错误输入上 |
| P1 | 唯一坐标/相机轴 | 12 点 vs 表背/屏幕法线；统一姿态源 | 目标永远差 90° 或随姿态漂移 |
| P2 | 姿态滤波 | 1€/SLERP，时间戳、q 符号、NaN | 抖动/漂移/目标游移 |
| P3 | 天文/磁偏角 | 真北/磁北策略、目标坐标确认 | 固定方位偏差 |
| P4 | 投影/UI | 透视、背面、roll、圆屏、对准容差 | 目标在错误位置、箭头误导 |

## 2. P0：传感器真值与精度

### 现象

- 指南针方向与手机有偏差。
- 磁场 23.7–63.5 µT，常见 24–36 µT；深圳地磁约 44–46 µT，存在弱场/干扰。
- AR 不读 accuracy/timestamp；无法知道 ORIENTATION 是否 UNRELIABLE/LOW。
- 系统 ORIENTATION 与 ROT 是两个融合源。

### 证据

- `AR_SENSOR_DATA_AUDIT.md` 第 3–4 节。
- `OrientationHub.ets:25–31` 丢弃 accuracy/timestamp。
- `@ohos.sensor.d.ts` Response 定义。
- Sky Map troubleshooting：校准状态高 ≠ 指向准确；外部金属 5–30°。

### 建议

1. 在诊断页记录 ORIENTATION/ROT 的 `accuracy`、`timestamp`、raw q；不要改 AR 主逻辑。
2. 在干净室外/远离金属处重复北向，系统指南针 + 手机 + ORIENTATION 三方对照。
3. 确认 ORIENTATION 是否已含磁偏角；若没有，P3 加 WMM/固定 declination；若已含，禁止重复。
4. 记录弱场时的 alpha/alt 变化；给用户“磁环境异常”提示（后续版本）。
5. 不自行做硬铁/软铁校准；系统校准失败时提示用户做 8 字。

### 验收

- 已知北向三方差 ≤ 3°（干净环境）。
- accuracy 状态可见/可记录。
- 磁偏角策略明确。

## 3. P1：唯一坐标与相机轴

### 现象

- 12 点轴 vs 表背/屏幕法线未定义；用户按手机 AR 习惯对准时目标差约 90°。
- 航向来自 ORIENTATION，高度来自 ROT；无统一四元数。
- roll 完全未处理。

### 证据

- `AR_COORDINATE_SYSTEM.md` 第 3、6 节。
- `ArPage.ets:52–85` 两个独立回调。
- 数学测试 roll 表：45° roll 目标从 (233,0) 到 (398,68)。

### 建议

1. 产品先确认指向轴：
   - 手持指星：+Y 为 forward，屏幕 up 取局部天顶切向；
   - 表背 AR：-Z 为 forward，+Y 为 screen up，+X 为 right。
2. 统一一个姿态源：
   - 优先 ORIENTATION 提供的完整姿态（alpha/beta/gamma 或系统旋转矩阵），或
   - 用 ROT 四元数统一生成 forward/right/up；不要一半 alpha 一半 ROT。
3. 建立 `SkyCamera { forward, up, fov }` 与 `Projection`，目标/星点都走同一矩阵。
4. 处理屏幕旋转/roll（至少 0/90/180/270）。
5. 明确磁北/真北后再进入 P3。

### 验收

- 五个虚拟目标（N/E/S/W/zenith）投影与参考矩阵一致。
- 滚转 90° 后星图旋转，目标相对屏幕位置符合相机模型。
- 目标居中时 Δaz/Δalt ≤1°。

## 4. P2：姿态滤波

### 现象

- 无平滑、无时间戳、无 q 符号处理、无 NaN 防御。
- 画面抖动/静止漂移未量化。

### 证据

- `AR_ATTITUDE_FILTER_AUDIT.md`。
- Sky Map `OneEuroQuaternionSmoother.kt`。

### 建议

1. 先完成 P1 统一姿态源，再在**四元数**上做 1€ filter；不要对 az/alt 分别平均。
2. 使用 SensorEvent `timestamp` 计算真实 dt；超过 1 s 间隔 restart。
3. q/-q：`dot(prev,raw)<0` 取反；SLERP。
4. NaN/Inf 检测→restart/heal。
5. 记录静止 RMS、转动延迟、停止稳定时间；按数据调 minCutoff/beta。
6. 不要用 UI 动画掩盖真实抖动；不要把滤波前的数据当滤波后。

### 验收

- 静止 60 s 目标屏幕抖动 ≤2 px RMS。
- 转动延迟 ≤150 ms。
- 停止 500 ms 内稳定。

## 5. P3：天文与磁偏角

### 现象

- 土星目标坐标正确，但 AR 航向与目标方位基准可能不同（磁北/真北）。
- 没有显式 declination。

### 证据

- 土星对拍：alt 差 0.041°、az 差 0.000°。
- `Astro.targetHorizontal()` 真北；ORIENTATION 基准未确认。

### 建议

1. P0 确认 ORIENTATION 是否已应用 WMM。
2. 若未应用：按城市经纬度加磁偏角，或明确“磁北模式”并让目标方位也用磁北。
3. 不要同时加两次 declination。
4. 保持 Astronomy Engine 对拍作为回归测试；不要重写历算。

### 验收

- 干净环境目标方位与系统指南针/手机差 ≤3°。
- 土星/月亮/亮星对拍仍 ≤2′。

## 6. P4：投影与 UI

### 现象

- 等距投影误差：30° 中心 RMS 42.5 px、60° 中心 RMS 112.5 px。
- 角点假阳性：az/alt 30/30 真实角距 41.4°。
- 无背面、无 roll、无圆屏遮罩、无“已对准”。
- 边缘箭头对背后目标可能指错。

### 证据

- `AR_PROJECTION_AUDIT.md` 全部。
- Sky Map `SkyProjection.kt`：perspective×view，`w<=1e-9` 丢弃。
- Stellarium `proj_perspective.c`：透视矩阵 + NDC→窗口。

### 建议

1. 用 `forward/right/up` + 透视除法替换 `x=cx+dAz*scale`。
2. `zc<=0` 丢弃；背后目标不画正面标记/箭头。
3. 圆屏安全裁剪：以中心为圆心，半径约 210–220 px（按实际表壳）。
4. 目标“进入视场”改为真实角距 ≤ FOV/2（不是矩形）。
5. 增加“已对准”容差（例如总角距 ≤2°）和方向/高度提示。
6. 边缘箭头用相机 x/y 方向，不用 dAz/dAlt。
7. 大 FOV/天顶用向量投影，避免角度奇点。

### 验收

- 五目标投影与参考透视 ≤5 px。
- 背后目标不绘制。
- 圆屏内无裁切。
- 目标对准容差可用。

## 7. 对“土星无法对准”的最小验证顺序

1. P0：确认土星目标 az/alt（已对拍正确）与当前 ORIENTATION 基准。
2. P1：确认用户是把 12 点还是表背对准土星；记录 center az/alt 与 target az/alt。
3. P4：检查目标是否因角点/背后/圆屏被误画；检查“已进入视场”是否假阳性。
4. 只有在上述确认后才改代码。

**本轮不实施以上修复。等待确认后再按 P0→P1→P2→P3→P4 执行。**
