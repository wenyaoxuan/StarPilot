# StarPilot EXP-01 E2 流星雨预测

2026-11-09，Asia/Shanghai。

## 使用方法

从主页进入「流星雨」。列表把当前活跃的流星雨排在前面。详情显示参考活跃期、极大参考日、太阳黄经和参考 ZHR。活跃期内可查看「未来 24h」，有对应年份的年历时也可查看「极大日 24h」。预测位置沿用主页所选城市或已保存的 GPS 坐标，曲线时间以手表时区显示。红光主题和中英文星名设置沿用全局偏好。E2 先在主页提供直达入口，天文工具合并入口属于 E6。

首批收录象限仪座、天琴座、宝瓶座 η、英仙座、猎户座、南金牛座、北金牛座、狮子座、双子座和小熊座。Source: International Meteor Organization (IMO) – www.imo.net. [IMO 2026 年历](https://imo.net/files/meteor-shower/cal2026.pdf) · [IMO 2027 年历](https://www.imo.net/files/data/calendar/cal2027.pdf) · [IMO 数据使用条款](https://www.imo.net/about/using-imo-data/)

## 计算与限制

- 年历收录两版表 5 的十组公开参数。2026 和 2027 极大参考日分别保存，以 UTC 日期显示。象限仪座 12 月末归入次年 1 月的季节。超出覆盖年份后仅保留参考活跃期及太阳黄经，并提示缺少年历。参考 ZHR 取自 2027 版，代表理想观测条件下的参考速率，实际观测数量随环境和流星雨活动变化。[IMO 对 ZHR 的定义](https://www.imo.net/resources/glossary/)
- 漂移为 StarPilot 对表 6 参考辐射点的线性近似。将太阳黄经近似折算到 J2000，以相对极大参考黄经的偏移估计漂移，并把计算限制在资料覆盖区间。活跃期内超出区间时使用最近端点。然后对辐射点做岁差转换，以既有恒星时和地平坐标算法计算高度与方位。
- 24 小时曲线每半小时取样，共 49 点。实线为辐射点高度，虚线为月亮高度。连续采样点满足太阳高度 ≤ −18° 且辐射点高于本地地平遮挡时，标出活跃期内的候选观测窗口。短于 30 分钟的窗口可能漏检。月亮高度用地心近似，贴近地平线时升落时刻仅供参考。界面在首个窗口开始时显示月面照亮比例、月高和月亮距辐射点的角距离。没有窗口时改用曲线起点。
- E2 使用内置数据和本地历算，无新增网络调用、权限或持久缓存。窗口未计入云量和光污染。

## 验证与回滚

- `node tools/astro-test/meteor-verify.mjs` 直接转译当前 ArkTS。覆盖十条记录、UTC 午夜、象限仪座跨年、年份过期、漂移、南北极、极昼极夜、遮挡、月亮升落和新月/满月。E1 取景数学回归也通过。
- DevEco CLI `1.3.0-stable` 执行 `devecocli build --product default --modules entry --build-mode debug` 成功。HDC 覆盖安装并启动于 WATCH 5 46 mm（RTS-AL00，HarmonyOS 6.1.0.333，466 × 466）。最终签名 HAP 大小 2,695,436 B，SHA-256 为 `9165ebec4ccafdf08c4daba7ef37bb476fe2837841b6bfa3786d6fc6716451ea`。相对 E1 的签名调试包总大小增加 83,093 B（81.1 KiB，包含调试映射等打包内容），超过 E0 的 32 KiB 包内增量目标。发布包、运行内存与功耗留待 E6 实测。
- 真机核对主页入口、活跃流星雨排序、南金牛座详情、跨午夜窗口和极大日视图。象限仪座活动期显示 12/28–1/12，极大参考日为 2027/1/4 UTC。[主页](s0-results/exp_e2_home_20261109.jpeg) · [列表](s0-results/exp_e2_list_20261109.jpeg) · [详情](s0-results/exp_e2_detail_20261109.jpeg) · [未来 24h](s0-results/exp_e2_24h_20261109.jpeg) · [极大日](s0-results/exp_e2_peak_20261109.jpeg) · [象限仪座](s0-results/exp_e2_quadrantid_20261109.jpeg)
- 调试前通过 HDC 启用 30 分钟长亮。调试后恢复原红光偏好和熄屏设置，HDC 返回 `Restore screen off time`。截图验证了红光详情和曲线配色。整表断网及切页瞬间配色尚未实测。[红光详情](s0-results/exp_e2_red_detail_20261109.jpeg) · [红光曲线](s0-results/exp_e2_red_curve_20261109.jpeg) · [象限仪座曲线](s0-results/exp_e2_quadrantid_curve_20261109.jpeg) · [恢复后的主页](s0-results/exp_e2_home_restored_20261109.jpeg)
- `MeteorShowers.ets` 为数据，`MeteorEngine.ets` 为独立历算，`MeteorPage.ets` 为页面。`HomePage.ets` 和 `Index.ets` 提供入口。回滚时撤销对应入口和页面挂载，移除 E2 数据、历算、页面及测试，重新构建即可。
