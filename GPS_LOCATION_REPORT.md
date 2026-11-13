# GPS 观测位置接入报告

日期：2026-11-08  
范围：一次性 GPS 定位、权限、城市/天气/导航/AR 坐标贯通

## 1. 目标

- 增加“使用当前位置”能力，解决手动城市与实际观测点不一致导致的月球/行星方位偏差。
- 只做**一次性定位**：用户点按钮取一次坐标，不持续订阅 GPS，避免手表功耗和隐私问题。
- 定位失败时保留手动城市，不阻塞原有功能。
- 不改变天文历算、AR 投影、传感器滤波。

## 2. 实现

| 文件 | 修改 | 作用 |
|---|---|---|
| `common/GeoLocation.ets` | 新增 | 权限申请、`getCurrentLocation` 一次性定位、结果校验 |
| `data/Cities.ets` | 修改 | `ensureGpsCity` 把 GPS 坐标作为额外的“当前位置”城市，复用现有 `cityIndex` 数据流 |
| `pages/LocationPage.ets` | 修改 | 顶部“GPS 定位”按钮、状态/精度显示、定位 chip |
| `pages/Index.ets` | 修改 | 应用 GPS 坐标、持久化、天气/目标刷新、启动恢复 |
| `module.json5` | 修改 | 声明 `APPROXIMATELY_LOCATION` / `LOCATION` |
| `resources/base/element/string.json` | 修改 | 新增定位权限用途说明 |

### 2.1 权限

```text
ohos.permission.APPROXIMATELY_LOCATION
ohos.permission.LOCATION
```

- 两者都是 `user_grant`；运行时用 `abilityAccessCtrl.requestPermissionsFromUser` 请求。
- 先同时请求精确 + 粗略；如果设备拒绝精确权限请求，再退化为只请求粗略权限。
- 任一权限授予即可继续；全部拒绝则显示“定位权限未授予”，不崩溃。
- 权限用途文案单独使用 `perm_reason_location`，不再复用传感器/振动文案。

### 2.2 定位

```ts
geoLocationManager.isLocationEnabled()
geoLocationManager.getCurrentLocation({
  priority: FIRST_FIX,
  scenario: UNSET,
  maxAccuracy: 1000,
  timeoutMs: 20000
})
```

- 返回 `latitude/longitude/altitude/accuracy`。
- 校验经纬度范围、NaN/Inf；无效结果不写入城市。
- 错误统一在 LocationPage 显示，并写 `GPS_ERR` 日志。
- 当前不调用逆地理编码，名称为“当前位置”；避免依赖地理编码服务。

### 2.3 坐标贯通

`ensureGpsCity(lat, lon)` 在 `CITIES` 末尾创建/更新一条 `当前位置` 城市：

```text
name=当前位置, country=GPS, region=GPS, lat/lon=定位结果
```

因此所有已有页面不需要新的位置模型：

- Home：城市名显示“当前位置”，天气按 GPS 经纬度刷新。
- Nav/AR/Targets：继续使用 `CITIES[cityIndex].lat/lon`，月球/行星/深空目标自动使用新坐标。
- 手动城市选择仍可用；选择手动城市会把 `gps_active` 置 false。
- 重启时从 Preferences 读取 `gps_active/gps_lat/gps_lon`，重新创建 GPS 城市，`city_index` 继续有效。

## 3. 真机结果

设备：RTS-AL00 / 6.1.0.333 / API 23。

### 3.1 权限与定位

- 首次点“GPS 定位”弹出系统位置权限对话框。
- 选择“仅使用期间允许”后授权成功。
- 定位结果：

```text
22.7673, 113.8005 · ±10m
```

- LocationPage 显示“当前位置”行，勾选状态正确。
- 没有出现 801/201/超时错误。

### 3.2 城市与天气

截图：`s0-results/gps_home2.jpeg`

- Home 城市从“深圳”变为“当前位置”。
- 天气从深圳缓存值更新为 GPS 坐标对应的数值（示例：31°C / 41% / 视宁4）。
- 重启应用后仍显示“当前位置”，说明 Preferences 持久化生效。

### 3.3 月球方位

截图：`s0-results/gps_nav.jpeg`

```text
目标 月球 222° / 38°
```

与独立 `astronomy-engine` 在同一 GPS 坐标/时间的计算一致（约 222°/38°）。说明 GPS 坐标已进入月球历算链路。

### 3.4 AR

截图：`s0-results/gps_ar.jpeg`

- 表盘朝上/表背朝地时：`方位 360° · 高度 -84°`，月球提示“在相机后方”。
- 与 +Z 表背观察轴一致；GPS 不改变姿态轴。

### 3.5 时间基准复核（用户反馈“像早上 7–8 点的月球位置”）

截图：`s0-results/gps_ar3.jpeg`  
日志（`AR_TARGET`，13:41）：

```text
clock=13:41
jd=2461352.737
target=MOON
az=225.2  alt=35.6
city=当前位置  lat=22.7673  lon=113.8005
```

对照独立历算：

| 时刻 | 月球 az/alt |
|---|---|
| 07:30 当地 | 131.6° / 35.1°（约） |
| 13:41 当地 | 225.2° / 35.6° |

- 两者高度接近，但方位相差约 **93°**。
- 时间/JD 已排除：13:41 的日志和独立历算都是当前月球位置。
- 后续加速度计复核（3.6）表明，当时手表实际是**屏幕朝上/表背朝地**，AR 中心高度 -84°，所以看到的是地平线附近；90° 的巧合来自“表背朝地时可见天区在另一侧”，不是 12 点轴单独造成。
- AR 相机在**表背**，必须用表背中心对准目标；屏幕朝向自己。

### 3.6 姿态复核：表背实际朝地（13:57）

日志（`AR_TARGET` / `AR_QDIR`）：

```text
clock=13:57
center=41° / -81°
target=MOON 228.4° / 33.0°
ACC=-1.1 / 1.2 / 9.8
```

- 加速度计 Z ≈ **+9.8**：屏幕外法线朝上，表背朝地；不是表背朝月亮。
- 如果表背真的指向高度 33° 的月球，屏幕法线应朝下约 33°，ACC Z 应约为 **-5.3**，而不是 +9.8。
- 当时手表在水平旋转（中心方位从 311° 变到 41°），但高度一直约 -81°，说明只转了方位、没有把表背抬起来。
- AR 顶部已增加状态：中心高度 < -20° 时显示 **“表背朝地”**；抬到天空后变为“表背朝目标”。
- 结论：这不是四元数方向或历算错误；是表背没有真正指向天空。需要把屏幕向下翻、表背向上抬，直到 `高度` 从 -80° 变到接近 +33°。


## 4. 限制

1. **不是实时跟踪**：只在点按钮时取一次坐标；移动位置后需要再次点“GPS 定位”。
2. **依赖系统定位服务**：系统定位关闭、室内无网络/卫星、权限拒绝时会失败，需手动城市回退。
3. **没有逆地理编码**：城市名固定“当前位置”，不显示行政区名。
4. **精度取决于系统**：本次 ±10m 是系统报告值；室内/Wi-Fi 定位可能更差。
5. **GPS 不修复 AR 姿态**：如果坐标正确但 AR 仍对不到月球，问题在航向/姿态/投影，不在位置。

## 5. 验收

| 项 | 状态 |
|---|---|
| 定位权限弹窗 | **PASS** |
| 一次性定位 | **PASS**（22.7673, 113.8005 ±10m） |
| 坐标进入天气 | **PASS** |
| 坐标进入月球历算 | **PASS**（222°/38°） |
| 重启后保留 | **PASS** |
| 手动城市回退 | **PASS（代码路径）** |
| 持续 GPS/实时移动 | 未实现（设计如此） |
| AR 对准月球 | **待真机复核** |

## 6. 文件哈希

```text
b3e2c10773f8b8fac59a4d70e74971d911d1e572c8820028c3ce865708ff87e4  GeoLocation.ets
18a3ff28838fc3cd696cb36403e5cab0bb9563f9d8006f19b5c5fa5d6781e052  Cities.ets
505e4010050e4e0f211a147ae41ada0f1790e73eb6b3a55e66404f503a200853  LocationPage.ets
04da4626e1dc5de7305528b02c53e450c6152c2fa3733adedfca3134a8f934a1  Index.ets
43ce032aee4beb8825e1472b1099bd337cc9dc0c563f12ffaff2cb459b140580  module.json5
4fc0a5b5267909ed0075580e64a984552f4569053bad01b2aea88f1ad116dac4  string.json
b96072394bfaaabb8219fb8c70f579e8bff4adce2a09526258f6d59d956478c3  entry-default-signed.hap
```

完整清单：`AR_AUDIT/baseline/GPS_SHA256.txt`。

## 7. 下一步

1. 用户用 GPS 坐标重新对准月球，记录 AR 中心 `方位/高度` 与目标提示。
2. 若中心读数与月球 222°/38° 差很多，转查 ROT 航向/相机 right 符号，而不是继续改位置。
3. 若需要移动中自动更新，再单独评估持续定位/手机下发坐标方案。
