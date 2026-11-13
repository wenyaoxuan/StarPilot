# D1 真机测试报告

- 设备：HUAWEI WATCH 5 46mm，RTS-AL00，HarmonyOS 6.1.0.333，API 23
- 测试日期：2026-11-07
- 应用：`com.starpilot.audit`，`EntryAbility`
- 构建：DevEco Studio 26.0.0.865 / HarmonyOS SDK 26.0.0 / hvigor 6.26.9
- HAP：`starpilot-watch/entry/build/default/outputs/default/entry-default-signed.hap`（约 1.5 MB）
- 安装：`hdc -t <watch-ip>:<port> install -r <hap>` → `install bundle successfully`

## 结论

D1 目录扩充、搜索、分类筛选、可见性筛选、详情与导航均已在真机跑通；原有 Messier 目标仍可追踪。随机 20 条坐标回查 20/20 与源表一致。**未做断网实测**（断 Wi-Fi 会中断本次 hdc 连接），但目录页无任何网络调用、数据全部打包，离线可用性由代码结构保证。

## 用例

| 用例 | 操作 | 结果 | 证据 |
|---|---|---|---|
| D1-T01 安装/启动 | 覆盖安装后 `aa start` | PASS，首页正常，天气/月相不受影响 | `d1_home.jpeg` |
| D1-T02 目录规模 | 进入“天体目录” | PASS，`669/669` | `d1_polish.jpeg`、`d1_rows.jpeg` |
| D1-T03 中文搜索 | 输入“北美洲” | PASS，`1/669`，C20 北美洲星云 | `d1_cn_ok.jpeg` |
| D1-T04 英文搜索 | 输入“Andromeda” | PASS，`1/669`，M31 仙女座星系 | `d1_en4.jpeg` |
| D1-T05 NGC 别名搜索 | 输入“NGC7000” | PASS，`1/669`，C20 | `d1_c20b.jpeg` |
| D1-T06 Caldwell 编号精确搜索 | 输入“C20” | PASS，`1/669`，仅 C20（修复了子串误命中 NGC20xx） | `d1_c20exact.jpeg` |
| D1-T07 分类筛选 | 星云/星系/恒星/双星/变星 | PASS：星云 107、星系 165、恒星 132、双星 6、变星 63 | `d1_galaxy2.jpeg`、`d1_stars.jpeg`、`d1_double.jpeg`、`d1_var.jpeg` |
| D1-T08 仅可见 | 开“仅可见” | PASS，`282/669`；叠加星系后 `63/669` | `d1_visible.jpeg`、`d1_gal_vis.jpeg` |
| D1-T09 列表性能 | 669 条中连续 fling | PASS，无崩溃/白屏；LazyForEach 正常回收 | `d1_scroll.jpeg` |
| D1-T10 详情字段 | 打开 M1 | PASS：RA 5h35m、Dec +22°01′、m8.4、8′×4′、600–1200mm、别名、窗口 21:06–5:16/8.2h、描述 | `d1_detail.jpeg`、`d1_detail2.jpeg` |
| D1-T11 原有目标导航 | M1 详情 →“导航到目标” | PASS：目标 79°/38°，当前 216°/−5.7°，提示左转 137°/抬高 43° | `d1_nav_m1.jpeg` |
| D1-T12 新增目标导航 | C20 详情 →“导航到目标” | PASS：RA 20h59m、Dec +44°32′；目标 310°/26°，当前 322°/3.3°，提示左转 12°/抬高 23° | `d1_c20detail.jpeg`、`d1_c20nav.jpeg` |
| D1-T13 原有 21 个目标 | 数据检查 + M1 真机 | PASS：21/21 均存在；M1 真机导航通过，其余 20 个共用同一追踪路径（未逐一点击） | `D1_QC_REPORT.md`、`d1_nav_m1.jpeg` |
| D1-T14 离线目录 | 代码审计 + 离线搜索回归 | 结构 PASS；未断 Wi-Fi 实测 | `D1_QC_REPORT.md` |
| D1-T15 搜索响应 | 输入后即时过滤 | 主观 PASS，无可感卡顿；未做帧率量化 | 录屏未采集 |

## 本次修复的交互问题

1. **横向分类条与整页滑动抢手势**：真机上横向滑分类条会翻页。改为两行固定芯片（搜索/全部/星云/星系/星团 + 恒星/双星/变星/仅可见/清除），不再需要横向滚动。
2. **搜索框误触弹键盘**：搜索框改为“搜索”芯片展开，避免滑页时误触；展开后仍可正常输入。
3. **分类高亮不同步**：`@Builder` 的 `selected` 布尔参数不触发重绘；改为 Builder 内直接读 `categoryKey`。
4. **编号子串误命中**：`C20` 之前会命中 NGC20xx；编号类查询改为整词匹配，名称仍为包含匹配。
5. **导航后返回仍是详情**：点“导航到目标”时先关闭详情，返回目录页直接看到列表。

## 未完成/待确认

- **断网实测**：为避免关闭 Wi-Fi 导致 hdc 断连，本次未切断网络；目录页无网络 import/请求，数据为编译期常量。建议后续单独做一次飞行模式验收。
- **表冠**：D1 未改表冠逻辑；真机表冠翻页仍待用户手动确认。
- **逐项真机点击 21 个旧目标**：仅 M1 做了完整详情→导航；其余 20 个做了数据存在性检查，追踪代码未改。
- **性能量化**：未采集帧率/内存；仅确认 669 条 LazyForEach 列表可连续滚动、无崩溃。
- **搜索输入法**：手表中文 IME 下用 hdc `uitest` 注入文本需要多次确认/退格，属于测试工具限制；手工输入正常。英文与编号输入正常。

## 证据位置

全部截图在 `s0-results/`：`d1_home.jpeg`、`d1_polish.jpeg`、`d1_rows.jpeg`、`d1_cn_ok.jpeg`、`d1_en4.jpeg`、`d1_c20b.jpeg`、`d1_c20exact.jpeg`、`d1_galaxy2.jpeg`、`d1_visible.jpeg`、`d1_gal_vis.jpeg`、`d1_stars.jpeg`、`d1_double.jpeg`、`d1_var.jpeg`、`d1_scroll.jpeg`、`d1_detail.jpeg`、`d1_detail2.jpeg`、`d1_nav_m1.jpeg`、`d1_c20detail.jpeg`、`d1_c20nav.jpeg`。

## 复现命令

```bash
cd starpilot-watch
DEVECO_SDK_HOME="E:/DevEco Studio/sdk" \
  "E:/DevEco Studio/tools/hvigor/bin/hvigorw.bat" \
  --mode module -p product=default -p module=entry@default assembleHap --no-daemon

hdc tconn <watch-ip>:<port>
hdc -t <watch-ip>:<port> install -r entry/build/default/outputs/default/entry-default-signed.hap
hdc -t <watch-ip>:<port> shell aa start -a EntryAbility -b com.starpilot.audit
```

测试期间为便于连续截图，执行过 `power-shell timeout -o 86400000`（24 小时）保持屏幕常亮；这是测试操作，不是应用行为，重启后恢复。


> 注：本报告的 669/677 是 D1 时点数量。2026-11-08 追加太阳后，当前目录为 678 条（669 静态 + 太阳 + 月球 + 七大行星）；新增项见 `SUN_AND_PHOTO_UPDATE.md`。
