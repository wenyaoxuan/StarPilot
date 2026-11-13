# 光污染等级与天光曝光模型

日期：2026-11-08  
构建 HAP：`aae60d9ba001d1cbf8a475a03d18a83acd12a8c758a5a1913e87542bcdb51423`

## 1. 目的

- 给 157 个观测城市补上 Bortle 光污染等级；
- 用 Bortle → SQM → 天光电子速率 → 天光限制/饱和限制的链路，让 ISO、光圈、画幅真正参与摄影计划；
- 让“ISO 自定义”有物理作用，而不是只显示一个数字。

## 2. 城市 Bortle 数据

- `City` 新增 `bortle: number` 字段，157 个城市全部有值。
- GPS“当前位置”默认 Bortle 9；可在“遮挡/Bortle”页手动覆盖。
- 城市切换时自动使用该城市的 Bortle，并写入 Preferences。
- Location 列表显示 `纬度, 经度 · Bx`，例如深圳 `B9`。
- 这些是**城市中心近似值**，不是你家阳台的实测值；山区/郊区应手动改小。

主要中国城市估算：

| 城市 | Bortle | 城市 | Bortle |
|---|---:|---|---:|
| 深圳 | 9 | 广州 | 9 |
| 上海 | 9 | 北京 | 8 |
| 成都 | 8 | 重庆 | 8 |
| 西安 | 8 | 武汉 | 8 |
| 杭州 | 8 | 南京 | 8 |
| 拉萨 | 4 | 林芝 | 3 |
| 稻城 | 2 | 阿里 | 1 |
| 德令哈 | 3 | 喀什 | 5 |

国际暗夜点：特卡波 1、萨瑟兰 1、圣佩德罗-德阿塔卡马 1、爱丽丝泉 1、拉帕尔马 2、弗拉格斯塔夫 4。

## 3. 算法

### 3.1 Bortle → SQM

常用对照表（mag/arcsec²）：

```text
B1 21.90  B2 21.70  B3 21.45  B4 20.80  B5 19.80
B6 18.90  B7 18.25  B8 17.80  B9 17.30
```

小数 Bortle 线性插值。

### 3.2 天光电子速率

按 SharpCap 公开示例校准：f/4.2、3.75µm、Bortle 8.2（SQM 17.7）≈ **14.5 e⁻/px/s**。

```text
skyRate = 14.5 × (pitch/3.75)² × (4.2/N)² × 10^(-0.4×(SQM-17.7))
```

- 只依赖 **像素间距/光圈 f 值**，不直接依赖焦距；这与“同样 f 值下天光每像素通量相近”的结论一致。
- 画幅差异通过传感器尺寸、像素间距、像素比例进入 FOV/NPF。

### 3.3 ISO 的作用

ISO 不改变 NPF 拖线，但改变读出噪声和 ADC 饱和点：

```text
readNoise(ISO) ≈ clamp(1.5, 4.5, 4.5 - 0.55·log2(ISO/100))
fullWell ≈ 50000·(pitch/3.76)² e⁻（近似）
satE = fullWell × 100 / ISO
tSky = rn² / (skyRate × ((1.05)²−1))   // 5% 噪声预算
tSat = 0.5 × satE / skyRate             // 半满阱
推荐单张 = min(tSky, tSat)
```

- 高 ISO 读出噪声更低，天光限制更短；但饱和上限也更低。
- 最终单张还受 NPF（无赤道仪）或用户单张（有赤道仪）限制。

### 3.4 堆栈

- 无赤道仪：`单张 = min(NPF, tSky, tSat)`；总时长按所选总分钟数。
- 有赤道仪：`单张 = min(用户单张, tSky, tSat)`。
- 帧间隔按单张自适应：<2s 用 0.5s，<10s 用 1s，否则 3s；避免 0.4s 单张仍按 3s 间隔估算出几小时。

## 4. 真机结果

深圳（GPS 当前位置，Bortle 9）：

```text
Sony A7R IV · 85mm · F1.8
Bortle 9.0 · SQM 17.30
天光 114.72 e/px/s
ISO 100：tSky 1.7s · tSat 218s · 读出噪声 4.5e
ISO 800：tSky 0.7s · tSat 27s  · 读出噪声 2.9e
ISO 1600：tSky 0.45s · tSat 14s · 读出噪声 2.3e
```

真机截图：

- `s0-results/photo_sky.jpeg`：ISO 选择与 Bortle 信息。
- `s0-results/photo_sky2.jpeg`：ISO 100 时单张 1.7s、1046 张、天光限制。
- `s0-results/photo_sky_iso800.jpeg`：ISO 1600 时单张 0.4s、4002 张，证明 ISO 现在确实改变计划。

暗空对照（数学）：

```text
Bortle 1 · SQM 21.90 · F1.8 · ISO 800
skyRate 1.66 e/px/s · tSky 47.8s
```

B9/B1 天光速率比约 69×。

## 5. 验证

`tools/photo-test/verify_light.mjs`：

```text
SharpCap 校准点 14.5 e/px/s        PASS
B1/B9 SQM 21.9/17.3                 PASS
B9/B1 天光速率比 69.18×             PASS
ISO 100/800/3200/12800 趋势         PASS
```

输出：`AR_AUDIT/baseline/lightpollution_test_output.txt`

## 6. 限制

- Bortle 是主观目视等级；城市值是“市中心近似”，不是阳台实测。真正拍摄应在当地实测 SQM 或手动改 Bortle。
- 没有打包 VIIRS/World Atlas 栅格；城市表是离线查找表，不随光污染变化更新。
- 天光速率用 SharpCap 示例做单点校准，全阱/读出噪声/QE 是近似；不能替代传感器实测。
- 模型只给“天光/饱和限制”，没有完整 SNR、滤镜带宽、月光、 transparency 模型。
- ISO 越高单张越短、张数越多；这是读出噪声/饱和模型的结论，实际仍应实拍确认。

## 7. 参考

- Bortle scale / SQM 对照：`https://en.wikipedia.org/wiki/Bortle_scale`
- 光污染地图：`https://www.lightpollutionmap.info`、`https://darkmap.cn`
- SharpCap Sky Background Calculator：`http://tools.sharpcap.co.uk`
- Sky-limited exposure 讨论：`https://github.com/seanhoughton/CalculateSkyLimitedExposure`
- RASC sky-limited 5% 判据：`https://rasc.ca/sites/default/files/publications/JRASC-2013-06-hr.pdf`

## 8. 文件哈希

```text
c389647ebb79cee680549f69a3686e6ed9e1bf40b5a00c54adba43d19068074c  LightPollution.ets
eef57add8dff87f0feebec6404984f6b8436d02e6d16038b8308d88a24f0624d  Cities.ets
db9a13660e466d57ab10553bcff9cfc80a45e44c0cb3d4c458bdeda58b164f5a  PhotoPage.ets
b4ad81b3bfe508c725998896512776ebdab139b6b03141cec48787b77ba83b48  Index.ets
0cd5eeead267f3985700801177c588c9f891ff62691e78e44dff388dd182d37e  LocationPage.ets
aae60d9ba001d1cbf8a475a03d18a83acd12a8c758a5a1913e87542bcdb51423  entry-default-signed.hap
9c282cb4f0cfe1cd5ced832f7d6fcfb24f4acb85ca3c2f807662ebaa7f44ccf2  lightpollution.mjs
2349857fb2c655535fde118e506622e3b1b67f4b5fb418b9c14e9bab4ca4518f  verify_light.mjs
```
