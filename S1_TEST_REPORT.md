# S1 真机验收记录

> 日期：2026-11-07
> 设备：HUAWEI WATCH 5 46mm（RTS-AL00 / HarmonyOS 6.1.0.333 / API 23）
> 构建：DevEco Studio 26.0.0.865 / SDK 26.0.0 / Hvigor 6.26.9 / `entry-default-signed.hap`
> 安装：`hdc install -r` 成功，`aa start` 冷启动正常

## 1. 验收项

| 验收项 | 结果 | 证据 |
|---|---|---|
| 四页正常显示 | **PASS** | 首页 / 星空导航 / 深空目标 / 摄影助手，466×466 无裁切 |
| 离线启动 | **PASS** | 应用无网络调用；断网/无手机不影响启动与页面 |
| 计时器 | **PASS** | 30 s 计时 30.07 s 结束；停止按钮可用 |
| 振动提醒 | **PASS** | `VIBRATE\|time 800 ok`；用户确认 `time` 模式可感知 |
| 计时期间常亮 | **PASS** | `SCREEN\|keep on` → 结束 `SCREEN\|keep off` |
| 计时持久化 | **PASS** | 计时中 `force-stop`，65 s 后重开：`TIMER\|catch-up at launch` + 振动 |
| 红光模式 | **PASS** | 全红/黑配色，偏好持久化 |
| 诊断入口 | **PASS** | 首页 → 诊断 → S0 四页；返回正常 |
| 深空目标 | **PASS** | 21 个 Messier 样本；列表 → 详情 → 返回 |
| 表冠 | **PASS** | 用户确认旋转表冠可翻页 |

## 2. 关键日志

```text
TIMER|start=30s end=1793982172671
SCREEN|keep on
TIMER|done
VIBRATE|time 800 ok
SCREEN|keep off

TIMER|start=60s end=1793982297826
（force-stop）
TIMER|catch-up at launch
VIBRATE|time 800 ok

TIMER|start=30s end=1793982384650
SCREEN|keep on
TIMER|stopped at 19s
SCREEN|keep off
```

## 3. 页面

| 页面 | 内容 |
|---|---|
| 首页 | 时间、日期、电量；拍摄条件/天文暮光/月相/手机四个占位卡；红光模式；诊断入口 |
| 星空导航 | 12 点方位角、高度、磁场状态、目标占位、数据源、归零/清除 |
| 深空目标 | 21 个 Messier 列表；RA/Dec/星等/角尺寸/推荐焦段/说明 |
| 摄影助手 | 30s/1/3/5/10/20 min 计时；镜头切换；A7R IV 机身信息；S5 计算占位 |

## 4. 已知限制

1. **息屏计时仍不可靠**：S0 已确认 `setInterval` 在息屏后被挂起。S1 采用“仅计时期间屏幕常亮”，不是整晚亮屏。
2. **补提醒只在下一次打开应用时触发**，不是系统级闹钟。若需要“息屏到点自动振动”，S2/S6 需评估 `reminderAgentManager` 或系统通知方案。
3. **诊断页仍是 S0 的白字配色**，红光模式下不够彻底；后续可统一。
4. **Messier 坐标为近似 J2000 值**，S2 会用独立历算逐条校验。
5. **首页天文/天气为占位**（S2/S4/S6 接入）。
6. **功耗未测**（用户明确暂不设门槛）。

## 5. 截图

- `s1_home2.jpeg`：首页（白光）
- `s1_red2.jpeg`：首页（红光）
- `s1_nav_final.jpeg`：星空导航
- `s1_p3.jpeg` / `s1_target_final.jpeg`：目标列表 / 详情
- `s1_photo2.jpeg` / `s1_running.jpeg` / `s1_timer_done.jpeg`：摄影助手/计时中/结束
- `s1_catchup.jpeg`：杀进程后重开补提醒
- `s1_diag.jpeg`：诊断入口

## 6. 下一步（S2）

- 独立实现 UTC/本地时间、恒星时、太阳/月球位置、月相、天文暮光。
- RA/Dec → Alt/Az、目标升起/落下、可观测窗口。
- 用 AstroPy/Stellarium 交叉验证，误差目标 <0.1°。
- 把首页四个占位卡替换为真实数据。
