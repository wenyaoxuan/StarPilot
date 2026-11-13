# 太阳系目标（太阳 + 月球 + 七大行星）接入报告

- 日期：2026-11-08
- 设备：HUAWEI WATCH 5 46mm，RTS-AL00，HarmonyOS 6.1.0.333 / API 23
- 范围：在“天体目录”中加入月球与七颗行星；坐标按当前时间实时计算；不改深空目标的静态星表。

## 1. 目标

新增 8 个动态目标：

| ID | 中文 | 英文 | 类型 |
|---|---|---|---|
| `MOON` | 月球 | Moon | 天然卫星 |
| `MERCURY` | 水星 | Mercury | 行星 |
| `VENUS` | 金星 | Venus | 行星 |
| `MARS` | 火星 | Mars | 行星 |
| `JUPITER` | 木星 | Jupiter | 行星 |
| `SATURN` | 土星 | Saturn | 行星 |
| `URANUS` | 天王星 | Uranus | 行星 |
| `NEPTUNE` | 海王星 | Neptune | 行星 |

目录从 **669 条静态目标** 扩为 **677 条目标**（669 + 8 动态）。太阳系目标使用搜索、分类“太阳系”、仅可见筛选、详情和导航，链路与深空目标一致。

## 2. 历算实现

文件：`starpilot-watch/entry/src/main/ets/common/SolarSystem.ets`（纯数学，无 HarmonyOS 导入）。

### 月球
- 复用 `Astro.ets` 的 Meeus 截断月球黄经/黄纬/距离。
- **站心视差**：用观测者地心向量减去月球地心向量，再转回 RA/Dec；对腕表指向很重要（月球视差约 1°）。
- 相位/照亮比例复用 `moonPhase()`；角直径按 3474.8 km / 距离计算。

### 行星
- Paul Schlyter 低精度轨道根数（1800–2050 适用），计算日心黄道坐标。
- 地球位置由太阳黄经/日地距离反推；行星地心坐标 = 行星日心 − 地球日心。
- 加入木星/土星/天王星主要互扰项。
- 一次光行时改正（`Δt = 距离(AU) × 0.0057755183 天`）。
- 黄道→赤道使用当日黄赤交角；不预cession，因为坐标已经是当日赤道系。
- 视星等用常用近似公式；角直径按行星直径/距离计算；相位照亮比例由相位角计算。

### 可见窗口
- 以 10 分钟步长扫描当地午夜后 24 小时。
- 条件：太阳高度 ≤ −18°、目标高度 ≥ max(10°, 当前方位遮挡线)。
- 生成与静态目标相同的 `VisibleWindow`，详情页显示最长窗口。

## 3. 交叉验证

脚本：`tools/astro-test/solar-verify.mjs`  
命令：

```bash
cd tools/astro-test
npx esbuild ../../starpilot-watch/entry/src/main/ets/common/SolarSystem.ets \
  --loader:.ets=ts --resolve-extensions=.ets,.ts,.js --bundle --format=esm --outfile=solar.mjs
node solar-verify.mjs
```

对拍 `astronomy-engine 2.1.19`，5 个地点/日期（深圳、北京 ×2、悉尼、特罗姆瑟），比较当日赤道坐标角距：

| 目标 | 最大角距 |
|---|---:|
| 月球（站心） | 0.70′ |
| 水星 | 0.53′ |
| 金星 | 1.34′ |
| 火星 | 0.47′ |
| 木星 | 0.32′ |
| 土星 | 0.24′ |
| 天王星 | 1.27′ |
| 海王星 | 0.61′ |

**最大 1.34′（金星）**，远小于腕表罗盘基线（RMS 4.6°、最大 8.7°），足够作为腕上指向目标；不能用于高精度天体测量。

## 4. 真机验证

| 用例 | 结果 | 证据 |
|---|---|---|
| 目录总数 | `677/677`，新增“太阳系”分类 | `s0-results/solar_targets.jpeg` |
| 太阳系筛选 | `8/677`，月球/水星/金星… | `s0-results/solar_list.jpeg` |
| 月球详情 | RA 13h34m、Dec −14°29′、实时历元、30.4′、392729 km、3% 新月 | `moon_detail.jpeg`、`moon_detail2.jpeg` |
| 搜索 Jupiter | `1/677`，木星 | `jupiter_search.jpeg` |
| 木星详情 | RA 9h50m、Dec +13°50′、约 m−2.1、0.6′、5.40 AU、99%、窗口 1:30–5:20/3.8h | `jupiter_detail.jpeg`、`jupiter_detail2.jpeg` |
| 导航到木星 | 目标 73°/−4°，提示“目标在地平线下”；当前航向 ORIENTATION | `jupiter_nav.jpeg` |

说明：测试时月球已落（−67°）、木星在地平线下（−4°）；窗口由计算给出，属于正常状态。

## 5. 已知限制

- 行星采用低精度轨道根数，误差约角分级；不是 JPL Horizons 级历表。
- 月球站心视差用球形地球/地心纬度近似，未计观测者海拔；对腕表指向足够。
- 行星视星等为近似值；土星环倾角项未加入，亮度可能有零点几等偏差。
- 太阳系可见窗口按 10 分钟步长扫描，边界有 ≤10 分钟误差。
- 动态目标不写入静态 `catalog.json`；`catalog.json` 仍是 669 条深空/恒星。
- 太阳系目标坐标随当前时间变化，详情页“历元”显示“实时”，不是 J2000。
- 搜索/列表/导航离线可用；历算无网络依赖。

## 6. 文件变更

- 新增 `common/SolarSystem.ets`：历算、目标定义、可见窗口。
- `pages/TargetsPage.ets`：合并 669 静态 + 8 动态；新增“太阳系”分类；动态 RA/Dec/星等/角尺寸/距离/相位/窗口。
- `pages/NavPage.ets`：太阳系目标每 5 秒重算目标方位/高度。
- `pages/PhotoPage.ets`：太阳系目标使用实时赤纬。
- `tools/astro-test/solar-verify.mjs`：对拍脚本。
- 未改 `Astro.ets` 的原有太阳/月球/恒星数学。


## 2026-11-08 太阳追加

- 目录新增 `SUN`（太阳，恒星），总数 677 → 678（669 静态 + 太阳 + 月球 + 七大行星）。
- `solarPosition(SUN)` 使用 `sunEquatorial` + `sunDistanceAu`；角直径按 1,392,700 km；星等 -26.74。
- 太阳可见状态不使用“太阳低于 -18°”的深空条件：高度 <0 已落、低于遮挡为遮挡、否则可见。
- 太阳详情/AR/摄影助手均提示必须使用合格太阳滤镜，严禁直视。
- 对拍 astronomy-engine：太阳最大分离 0.30′。
- 详见 `SUN_AND_PHOTO_UPDATE.md`。
