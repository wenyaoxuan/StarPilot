# 太阳目标与摄影助手扩充报告

日期：2026-11-08  
构建 HAP：`aae60d9ba001d1cbf8a475a03d18a83acd12a8c758a5a1913e87542bcdb51423`

## 1. 太阳目标

### 1.1 接入内容

- `SOLAR_BODIES` 新增 `SUN`（太阳，恒星）。
- `solarPosition('SUN', jd)` 使用 `sunEquatorial(jd)` + `sunDistanceAu(jd)`。
- 角直径按 1,392,700 km 计算，星等 -26.74。
- 天体目录总数从 677 变为 **678**（669 静态 + 太阳 + 月球 + 七大行星）。
- 太阳出现在“太阳系”分类；可见状态单独判断：
  - 高度 < 0 → 已落
  - 低于阳台遮挡 → 遮挡
  - 否则 → 可见
- 太阳的可见窗口按白天高度计算，不再套用“太阳低于 -18°”的深空条件。
- AR 目标提示加 `需巴德膜`；天体详情描述明确“严禁直视或直接拍摄未加巴德膜的太阳”。
- 摄影助手在目标为太阳时显示太阳滤镜警告。

### 1.2 精度对拍

`tools/astro-test/solar-verify.mjs` 加入 SUN，对 5 个地点/日期与 astronomy-engine 比较：

```text
SUN 最大分离 0.30′
月球 0.70′
行星 ≤1.34′
```

太阳位置精度满足指向需求。

### 1.3 真机结果

- 截图 `s0-results/sun_catalog3.jpeg`：太阳系分类 `9/678`，太阳 `+29° · 可见`。
- 截图 `s0-results/sun_detail.jpeg`：太阳详情，恒星 · 太阳系，RA/Dec 实时。
- 尚未在 AR 中实际对准太阳（安全原因，不建议无滤镜操作）。

## 2. 摄影助手扩充

### 2.1 相机库

`common/Photo.ets` 新增 `CAMERAS`，共 **49 台**，覆盖：

- Sony：A7R IV、A7 IV、A7S III、A1 II、A6700、A9 III、A7C II、A7CR、A7R V、A7 V、A7R VI
- Canon：EOS R5、R6 Mark II、R7、R1、R5 Mark II、R50 V、R6 Mark III
- Nikon：Z8、Z6 III、Z50 II、Z9、Z5 II
- Fujifilm：X-T5、X-H2S、GFX 100S、X-T50、X-M5、X100VI、GFX 100 II
- Panasonic：Lumix S5 II、GH6、S1 II、S1R II、GH7
- OM System：OM-1、OM-3、OM-1 II
- Leica：Q3、SL3、SL3-S、Q3 43
- Hasselblad：X2D 100C、X2D II 100C
- Pentax：K-3 III、K-3 III Monochrome、K-1 II、645Z
- Apple：iPhone 15 Pro

相机选择页支持**品牌筛选**：全部/Sony/Canon/Nikon/Fujifilm/Panasonic/OM System/Leica/Hasselblad/Pentax/Apple；打开时默认当前品牌，可切“全部”。

每台包含：

```text
品牌、型号、画幅、裁切系数、传感器宽高、像素数、像素间距
```

画幅覆盖全画幅、APS-C（1.5×/1.6×）、M4/3、中画幅、1/1.28"。

### 2.2 焦段、光圈与总时长

- `FOCALS` 共 15 个常用焦段：14/20/24/28/35/50/85/105/135/180/200/300/400/600/800mm。
- 另外支持 **1–3000mm 自定义焦段**，步进 1mm；主页面即可用 `− / +` 调整。
- 焦段选择页显示当前画幅下的**等效焦距**；自定义时显示“15mm 自定义 · 等效 23mm”。
- 光圈支持 **0.7–22.0** 自定义，步进 0.1；同时保留 F1.8/2.8/4/5.6/8/11 快捷按钮。
- 选择焦段时，如果当前光圈小于该焦段最大光圈，会自动抬到最大光圈；之后仍可手动收/放。
- 低于镜头最大光圈时，详情会提示“超过镜头最大光圈”。
- 总时长支持 **1–1440min 自定义**，步进 1min；保留 15/30/60/120/240min 快捷按钮。
- 总时长只影响无赤道仪模式的堆栈计划；有赤道仪模式仍用单张/张数。
- ISO 现参与天光/饱和限制模型（按 Bortle 计算读出噪声和饱和上限），不再是无效数字；详见 `LIGHT_POLLUTION_REPORT.md`。

### 2.3 画幅差异

FOV、像素比例、NPF 都使用所选相机的真实传感器尺寸和像素间距，不再固定 A7R IV：

```text
FOV = 2·atan(sensor / (2·focal))
pixelScale = 206265·pitch / focal
NPF 使用该机身的 pitch
```

真机示例：

| 相机 | 画幅 | 35mm 等效 | 35mm 视场 | 比例 |
|---|---|---|---|---|
| Sony A7R IV | 全画幅 | 35mm | 54.0°×37.6° | 22.16″/px |
| Sony A6700 | APS-C 1.5× | 53mm | 37.1°×25.1° | 22.39″/px |
| Panasonic GH6 | M4/3 2× | 70mm | 27.8°×21.0° | 17.68″/px |
| Fujifilm GFX 100S | 中画幅 0.79× | 28mm | 64.1°×50.3° | 22.16″/px |

（具体数值以页面实时计算为准。）

### 2.4 数学验证

`tools/photo-test/verify.mjs` 原有 A7R IV 用例全部 PASS。  
新增 `verify_formats.mjs`：

```text
A6700 85mm FOV / 像素比例    PASS
GH6 300mm FOV                PASS
GFX 85mm FOV                 PASS
A7S III 85mm 像素比例        PASS
A6700/GH6/GFX 等效焦距       PASS
Canon R7 裁切 1.6×           PASS
像素数换算                   PASS
```

### 2.5 真机结果

- `s0-results/photo_camera_picker2.jpeg`：相机选择页，Sony 列表。
- `s0-results/photo_apsc2.jpeg`：A6700 + 180mm，APS-C 视场 7.5°×5.0°、等效 270mm、4.35″/px。
- `s0-results/photo_focal_picker.jpeg`：焦段选择页，显示 APS-C 等效焦距。
- `s0-results/photo_35.jpeg`：A6700 + 35mm，视场 37.1°×25.1°、等效 53mm、22.39″/px。
- `s0-results/photo_ap_plus.jpeg`：自定义光圈 F6.3 → F6.4，NPF 9.6→9.7s。
- `s0-results/photo_focal15.jpeg`：A6700 + 自定义 15mm，视场 76.1°×54.9°、等效 23mm、52.25″/px。
- `s0-results/photo_pentax2.jpeg`：相机列表中的 Pentax K-3 III / K-3 III Monochrome / K-1 II / 645Z。
- `s0-results/photo_pentax_k3.jpeg`：Pentax K-3 III + 自定义 15mm，APS-C 参数正确。
- `s0-results/photo_brand.jpeg`：相机选择页品牌栏，默认当前品牌 Pentax。
- `s0-results/photo_sony_filter.jpeg`：切到 Sony，列表只显示 Sony。
- `s0-results/photo_specs_final.jpeg`：Sony 列表最终版，A7 V 33MP、A7R VI 66.8MP（列表四舍五入显示 67MP）、35.9×24.0mm，无“规格待确认”。
- `s0-results/photo_sky_iso800.jpeg`：ISO 1600 + Bortle 9，天光限制 0.4s、堆栈张数随 ISO 变化。
- `s0-results/photo_total2.jpeg`：总时长 1–1440min 自定义与 15–240min 快捷按钮。
- `s0-results/photo_sony_a7v.jpeg`：修正前的旧截图，仅作历史。

## 3. 限制

- 相机参数按官方规格页四舍五入，不是个体标定；A7 V/A7R VI/R6 III/S1R II/Pentax K-3 III 已核对，其余新机型仍建议发布后复核。
- 焦段支持 1–3000mm 自定义；最大光圈仍取所选预设的参考值，不绑定具体卡口/镜头像场。
- 自定义光圈允许超过镜头最大光圈，会显示警告，但不会阻止计算。
- 没有加入曝光亮度/天空背景模型；摄影助手仍只做 FOV、NPF、500 法则、堆栈计时。
- 太阳目标只做坐标/指向；没有太阳滤镜检测，安全责任在用户。

## 4. 文件哈希

```text
f92b91c07bd256ef658807282db4f6e2333ba5c035619b35cb015ea5ef6a325b  SolarSystem.ets
a6024a26f728b63e61f8a165f13ccb6c39067cdd448379a4173846a834cd23e0  Photo.ets
db9a13660e466d57ab10553bcff9cfc80a45e44c0cb3d4c458bdeda58b164f5a  PhotoPage.ets
39f15137f0cca508ed11601368350ff13fea5345252ca5f2b41940d4e6a07255  TargetsPage.ets
66eb9af8602a83845bfbb05b55e06384e6873126fa84476a28f7e95738b96e30  ArPage.ets
aae60d9ba001d1cbf8a475a03d18a83acd12a8c758a5a1913e87542bcdb51423  entry-default-signed.hap
7a2b0ad6b9e374a5ec46e6061db088ba1c95085574c135a9b1a9526748fbcbac  photo.mjs
9471f0e5d51a419df3774be46883f8e89da53f568807826af1583a916e8f2e59  verify_formats.mjs
c69b3d083353f588527e76d2f9c59405233289ac475d0342109f72deb70ec09f  solar.mjs
```
