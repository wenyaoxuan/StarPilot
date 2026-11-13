# 天气数据接入记录（双源：Open-Meteo + 7Timer）

> 日期：2026-11-07
> 设备：HUAWEI WATCH 5 46mm（RTS-AL00 / HarmonyOS 6.1.0.333 / API 23）

## 1. 系统天气 App 能不能读？

**不能。** 华为 `Weather Service Kit` 只对系统/厂商应用开放，第三方普通 App 在 AGC 没有“天气服务”能力开关；也不存在公开 API 让第三方读取系统天气 App 的数据。

因此不能把“手表自带天气”当作第三方可用能力。

## 2. 手表直连公网

Watch 5 是 `Wearable`（Stage/ArkTS），支持 `@ohos.net.http`；`module.json5` 已声明 `ohos.permission.INTERNET`。因此可以不经过手机，直接请求天气 API。

数据源：**Open-Meteo**（免密钥）

```text
https://api.open-meteo.com/v1/forecast
  ?latitude=39.9042&longitude=116.4074
  &current=temperature_2m,relative_humidity_2m,cloud_cover,wind_speed_10m
  &hourly=precipitation_probability
  &timezone=auto&forecast_days=1
```

返回当前温度、湿度、云量、风速，以及逐小时降水概率。

## 3. 真机结果

```text
WEATHER|cloud=12;temp=5;hum=59;wind=5.4;precip=0
```

首页“拍摄条件”卡片：

```text
拍摄条件
12%
5°C 湿59%
风5 降水0% 00:58
```

截图：`s0-results/weather_home7.jpeg`。

## 4. 解析验证

`WeatherParse.ets` 是纯解析模块，Node 用真实响应验证：

```text
HTTP 200
parsed { tempC: 5, humidity: 59, cloudCover: 12, windKmh: 5.4, precipProb: 0 }
PASS weather parse
PASS malformed json -> null
```

脚本：`tools/weather-test/verify.mjs`。

## 5. 缓存与刷新

- 结果写入偏好存储：`wx_cloud / wx_temp / wx_hum / wx_wind / wx_precip / wx_time`。
- 启动时先读缓存，再判断是否超过 30 分钟；超过才联网。
- 每 10 分钟检查一次（实际仍受 30 分钟门槛约束）。
- 切换城市立即重拉。
- 请求失败保留旧数据，卡片显示“离线 · HH:MM”；无缓存显示“获取失败”。

## 6. 双源：7Timer ASTRO

在 Open-Meteo 之外接入 7Timer ASTRO，补充视宁度/透明度：

```text
https://www.7timer.info/bin/astro.php?lon=...&lat=...&ac=0&unit=metric&output=json&tzshift=0
```

- `cloudcover` 1–9（1 晴，9 阴）
- `seeing` 1–8（1 最差，8 最好）
- `transparency` 1–8（1 最差，8 最好）
- `timepoint` 为模型起报后的小时数；解析时选第一个 ≥ 当前小时的条目

真机结果：

```text
WEATHER7|cloud=6;seeing=5;transparency=2;valid=1793988000000
```

- 首页“拍摄条件”第二行显示“视宁5 透明2 · HH:MM”。
- 点“拍摄条件”卡片进入天气详情页，分别展示 Open-Meteo 与 7Timer。
- 两源独立，云量可能不一致（例：Open-Meteo 14%，7Timer 6/9≈69%），不合并成单一数值。

### 超时问题

7Timer 响应约 5.3 KB，手表首次 8 s 超时（错误 2300028）；把超时提到 **20 s** 后成功。Open-Meteo 约 1.2 KB，8 s 足够。

## 7. 已知限制

1. **依赖手表网络**：Wi-Fi / eSIM / 手机网络代理任一可用；完全断网时只能看缓存。
2. **两源可能不一致**：Open-Meteo 与 7Timer 的云量口径不同，UI 同时展示、不合并。
3. **7Timer 较慢**：手表上需 20 s 超时；失败不影响 Open-Meteo 与首页。
4. **城市级坐标**：不是阳台精确坐标；对云量影响不大，对局地雾/楼间风有偏差。
5. **不是系统天气 App 数据**：来源不同，数值可能与手表自带天气不一致。
6. **7Timer 视宁/透明为 1–8 等级**：非物理角秒值，仅作相对参考。

## 7. 下一步

- 可选：7Timer 补充 seeing/transparency。
- 天气详情页（湿度/风/降水/更新时间已缓存，首页两行已展示）。
- S6 手机同步仍受 Wear Engine 审批阻塞；天气已不依赖手机。

## 8. 2026-11-08 刷新修复

问题：点“立即刷新”后请求确实发出（hilog 有 `WEATHER`/`WEATHER7`），但天气页数值不变；按钮还在页面底部，容易被圆屏裁切。

根因：
- `WeatherPage` 使用 `@StorageLink`，Index 在异步网络回调里 `AppStorage.setOrCreate` 后页面没有重绘。
- 刷新没有 busy/状态反馈；7Timer 最长 20 s，用户看起来像“没反应”。
- “立即刷新”按钮在长页面底部，圆屏上只露出一部分。

修复：
- `WeatherPage` 改为 `@Prop @Watch('onWxTick') wxTick` + 本地 `@State`，每次 `wxTick++` 主动从 `AppStorage` 同步全部天气字段（与 HomePage 同一套模式）。
- “立即刷新”移到页面顶部，始终可见；刷新期间按钮显示“刷新中…”并禁用。
- 增加状态行：`刷新中…`、`Open-Meteo 已更新，等待另一源…`、`已刷新 HH:MM`、`部分源失败，保留旧数据`。
- Index 增加刷新序号/完成计数，忽略过期回调；两源独立完成，不再等 7Timer 才更新 Open-Meteo 数值。
- 保留 7Timer 20 s 超时（8 s 会失败），但慢的时候页面有明确等待提示。

真机验证：
- 刷新前页面显示 `26% / 24°C / 80%`；点击顶部“立即刷新”后 0.4 s 显示“刷新中…”，约 3 s 后显示“已刷新 00:35”。
- 页面数值与 hilog `WEATHER` 一致；7Timer 显示 3/9、视宁4、透明4，预报时间 02:00。
- 证据：`s0-results/wx_busy.jpeg`、`wx_done.jpeg`、`wx_page_new.jpeg`。
