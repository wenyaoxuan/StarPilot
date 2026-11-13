# StarPilot EXP-01 E4 手动星桥

2026-11-09，Asia/Shanghai。目标设备为 HUAWEI WATCH 5 46 mm（RTS-AL00，HarmonyOS 6.1.0.333，466 × 466）。

## 使用方法

打开「主页 → 天文工具 → 手动星桥」，选择 M31、M42、M45、M13、M57 或 M27。其他星云、星团和星系可从「天体目录 → 目标详情 → 星桥」进入。选择一颗已经认出的起点亮星。起点可按中文名、英文名、星座缩写或 HIP 编号搜索，也可把极限星等在 1–6 等间以 0.5 等为步长调整。

每一步显示当前星、下一星或目标、角距、位置角、下一点的规划时刻高度和方位。局部图以当前星为中心，上北右东。小圆表示下一颗参考星，方框表示深空目标。找到下一颗星后手动确认，也可回到上一步，或从当前星重新计算。最后一步的完成标记来自用户确认。

## 星表与路线

- 起点与中转星沿用已有恒星目录，再用 HYG v3.5 补入 79 颗不重复且亮于或等于 4.0 等的 HIP 恒星。补充星中有 76 颗按 HIP 匹配到 Stellarium Chinese v26.3 的中文名。运行时共有 796 颗已知星等且不暗于 6 等的候选恒星。J2000 坐标、视星等、星座缩写和标识均来自本地数据，未使用恒星自行修正。衍生数据按 CC BY-SA 4.0 分发，保留原署名。[Astronexus HYG](https://github.com/astronexus/HYG-Database/tree/main/hyg/v3) · [Stellarium Chinese](https://github.com/Stellarium/stellarium/tree/v26.3/skycultures/chinese) · [数据说明](tools/catalog/DATA_SOURCES.md)
- 规划沿用应用所选城市或 GPS 和用户的地平遮挡表。搜索范围为目标周围 60°。参考星需至少 10° 高，且高于该方向的遮挡线 1°。目标至少 5° 高且越过遮挡线。Bortle 9 默认 2.5 等，Bortle 1 默认 6 等，默认值用于规划筛选。暮光或白天仍可预演并有标签。实际识别还取决于云量、月光和观察条件。
- 隐式图以恒星和深空目标为节点。每条边最长 14°，Dijkstra 的代价综合跳数、角距平方、参考星星等、可辨认性及相对遮挡的高度，并按 Bortle 增加较暗恒星的惩罚。目标的星等不用于参考星过滤。路径不连通、目标太低、遮挡和参考星不足分别提示。
- 稳定球面 `atan2` 求角距和天球位置角，位置角从天球北向东计，重合、对跖或起点正处天极时省略无定义的角度。局部图采用以起点为中心的方位等距映射。该功能用目录坐标手动操作，遵循现有 12 点 AR 与北向约束。[角距离与位置角约定](https://docs.astropy.org/en/stable/coordinates/matchsep.html)

## 验证

`node tools/astro-test/star-hop-verify.mjs` 转译当前 ArkTS，使用北京经纬度、各目标过中天时刻、5 等和空白地平线测试六个指定目标。路线如下。

| 目标 | 参考测试路径 |
| --- | --- |
| M31 | HIP677 → HIP3092 → M31 |
| M42 | HIP27989 → M42 |
| M45 | HIP21421 → M45 |
| M13 | HIP91262 → HIP87808 → HIP84380 → M13 |
| M57 | HIP91262 → M57 |
| M27 | HIP97649 → HIP97365 → M27 |

测试还覆盖 RA 0h 跨界、高赤纬、天极、低高度、地平线下、目标或起点被遮挡、星等不足、起点不可用、图不连通与 Bortle 默认值变化。测试路线用于验证历算与寻路，现场识别以实际观测为准。

### Watch 5

- DevEco CLI `1.3.0-stable` 构建成功，HDC 覆盖安装。最终签名调试包 3,030,147 B，SHA-256 `cf59915148ef478f1f7fd636af21c4338b78b9d34c7b7d12dd8486b232a20de7`。比 E3 增加 163,475 B（159.6 KiB，含调试映射），超过 E0 的 24 KiB 增量目标。
- 真机在 Bortle 9 显示默认 2.5 等。手动调到 3.5 等，按 HIP677 搜索到壁宿二，得到「壁宿二 → 奎宿五 → 仙女座星系」。前进、回退均重绘星图，从奎宿五重规划后显示剩余 1 跳。确认最后一跳后显示完成页。[默认星等](s0-results/exp_e4_m31_starts_20261109.jpeg) · [搜索](s0-results/exp_e4_search_20261109.jpeg) · [第 1 跳](s0-results/exp_e4_route_1_20261109.jpeg) · [第 2 跳](s0-results/exp_e4_route_2_20261109.jpeg) · [回退](s0-results/exp_e4_route_back_20261109.jpeg) · [重规划](s0-results/exp_e4_replan_20261109.jpeg) · [完成](s0-results/exp_e4_complete_20261109.jpeg)
- 选 M42 时，真机提示「目标高度低于 5°」。这次保留无线 HDC 连接，整表断网与实地辨星尚未实测。[低高度提示](s0-results/exp_e4_m42_status_20261109.jpeg)
- 从目录详情直接打开 M31 星桥，验证红光和英文星名，返回后仍为原目标详情。调试前临时开启 30 分钟亮屏，结束后恢复熄屏、主题和星名设置。[目录入口](s0-results/exp_e4_catalog_english_20261109.jpeg) · [红光英文星图](s0-results/exp_e4_red_english_20261109.jpeg) · [返回详情](s0-results/exp_e4_catalog_return_20261109.jpeg) · [设备日志](s0-results/exp_e4_audit_20261109.txt)

## 回滚

撤销 `Index.ets` 和 `TargetsPage.ets` 中星桥入口与挂载，移除 `StarHopPage.ets`、`StarHopEngine.ets`、`StarHopCatalog.ets`、`StarHopSupplement.ets`、生成和验证脚本，以及对应的星表署名增量后重新构建。E4 无持久缓存或数据迁移。
