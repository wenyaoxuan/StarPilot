# D1 天体目录数据来源与导入说明

版本：`D1-2026-11-07`  
生成文件：`starpilot-watch/entry/src/main/ets/data/Messier.ets`（沿用旧文件名，内容为完整 D1 目录）  
机器可读副本：`tools/catalog/catalog.json`  
生成脚本：`tools/catalog/build_catalog.py`；抽检脚本：`tools/catalog/qc_random.py`

## 1. 数据源

| 数据源 | 版本/快照 | 许可 | 用途 |
|---|---|---|---|
| [OpenNGC](https://github.com/mattiaverga/OpenNGC) `NGC.csv` + `addendum.csv` | 2026-11-07 主分支；13,971 条 NGC/IC + 64 条 addendum | CC-BY-SA-4.0 | Messier/Caldwell 的星表主体、250 条精选 NGC/IC、坐标/星等/尺寸/别名 |
| [Astro-Catalogue-Viewer](https://github.com/thebioguy/Astro-Catalogue-Viewer) Caldwell 元数据 | 109 条 Caldwell | MIT | Caldwell 编号、名称、RA/Dec、距离、最佳月份 |
| [HYG Database](https://github.com/astronexus/HYG-Database) `hyg/v3/hyg_v35.csv.gz` | v3.5；完整文件 13.6 MB | CC-BY-SA-4.0（仓库 LICENSE 快照） | 200 颗最亮恒星、双星/变星标记、距离、星座/拜耳名 |

原始文件保存在 `tools/catalog/source/`，未提交到应用包；应用只打包生成后的 `Messier.ets`。

## 2. 记录构成

| 组 | 数量 | 说明 |
|---|---:|---|
| Messier | 110 | M1–M110；M102 按 NGC 5866 收录并注明争议 |
| Caldwell | 109 | C1–C109；与 NGC/IC 正表交叉去重 |
| NGC/IC 精选 | 250 | 90 星系 + 66 星云 + 94 星团（配额选样后按余量补齐） |
| 亮星 | 200 | HYG 按 V 星等排序；含双星/变星子类 |
| **合计** | **669** | 唯一 ID 669 个 |

分类计数：星云 107、星系 165、星团 196、恒星 132、双星 6、变星 63。

## 3. 字段与单位

| 字段 | 类型 | 含义 |
|---|---|---|
| `id` | string | 规范编号：`M31`、`C20`、`NGC7000`、`IC434`、`HIP32349`（NGC/IC 去前导零，无空格） |
| `name` | string | 中文名；无通用中文名时用编号 |
| `nameEn` | string | 英文名/通用名；无则用编号 |
| `aliases` | string[] | 编号、Messier/Caldwell 写法、NGC/IC 交叉号、常用名、中文名 |
| `type` | string | 中文类型（星系、球状星团、发射星云、行星状星云、超新星遗迹、双星、变星等） |
| `category` | string | UI 筛选键：`nebula`/`galaxy`/`cluster`/`star`/`double`/`variable` |
| `raHours` | number | J2000 赤经，小时（0–24） |
| `decDeg` | number | J2000 赤纬，度（−90–90） |
| `epoch` | number | 固定 `2000.0` |
| `mag` | number | 星等；未知填 `99` |
| `magKnown` | boolean | 星等是否来自源表 |
| `sizeA`/`sizeB` | number | 长/短轴，角分；未知填 `0` |
| `sizeKnown` | boolean | 尺寸是否来自源表 |
| `surfaceBrightness` | number | mag/arcsec²；未知填 `0` |
| `distanceLy` | number | 光年；未知填 `0` |
| `fl` | string | 按角尺寸分档的推荐焦段（启发式，不保证构图） |
| `season` | string | 仅 Caldwell 元数据有最佳月份时填写 |
| `desc` | string | 原有 21 个目标的描述保留；新增目标多为空 |
| `source` | string | 该条记录的来源与许可 |

**不虚构缺失值**：没有可靠星等/尺寸/距离时保留哨兵值并置 `*Known=false`，UI 显示“未收录”或“—”。

## 4. 关键映射与去重

### Messier
- 110 个 M 编号逐个映射到 OpenNGC 正表；M45=`Mel022`、M40=`M040`、M24=`IC4715`、M25=`IC4725`。
- **M102**：OpenNGC 的 addendum 将 M102 标为 M101 的重复行；主流共识按 **NGC 5866** 处理。本目录采用 `M102 = NGC5866`，`desc` 注明争议。
- Messier 目标优先使用 OpenNGC 的坐标/星等/尺寸；21 个旧目标的描述从 `legacy_Messier.ets` 原样迁移。

### Caldwell
- 109 条全部收录；优先把 Wikipedia 链接或 addendum 编号解析为 NGC/IC 正表行，缺失时回退到 Caldwell 元数据坐标。
- 手工修正/映射：
  - C9 → `C009`（Sh2-155）
  - C14 → `C014`（双星团；坐标用元数据中心）
  - C39 → `NGC2392`（爱斯基摩星云）
  - **C40 → `NGC3626`**：元数据外链误写为 `NGC_3632`；OpenNGC 的 `NGC3632` 是 `Dup` 行，`NGC3626` 的 Identifiers 明确含 `C 040`。
  - C41 → `C041`（毕星团）
  - C49 → `NGC2237`（玫瑰星云）
  - C50 → `NGC2239`（NGC 2244 星团；OpenNGC 的 `NGC2244` 是 `Dup` 行）
  - C55 → `NGC7009`（土星状星云）
  - C60 → `NGC4038`、C61 → `NGC4039`（触须星系两个成员）
  - C92 → `NGC3372`（船底座星云）
  - C99 → `C099`（煤袋星云）
  - C106 → `NGC104`（杜鹃座 47）

### NGC/IC 精选
- 排除已被 Messier/Caldwell 占用的正表对象。
- 排除重复片段/别名冲突对象：`IC4703`（M16 内）、`NGC1990`（参宿二反射星云）、`NGC2238`、`NGC2244`、`NGC3632`、`NGC6995`。
- 仅保留星系/星云/星团三类，按“有常用名优先、V 星等亮、角尺寸大”排序，按配额选 250 条。

### 亮星
- HYG 取 `mag ≤ 6`、排除 Sol，按星等升序。
- 同一 `HIP`/`HR`、同一 `proper` 名、以及坐标四舍五入到 `0.001h / 0.01°` 的重复行只保留最亮的一条（例如 Castor A/B 合并为一条）。
- 中文名：常用中文名表；否则“星座中文名 + 拜耳希腊字母”；否则“星座 + Flamsteed 号 + 星”；否则编号。
- 双星/变星：常用名表 + HYG `var` 字段标记；仅用于分类筛选，不改变追踪坐标。

## 5. 生成与校验

在 `tools/catalog/` 下：

```bash
python -I build_catalog.py     # 读 source/，写 Messier.ets、catalog.json、D1_QC_REPORT.md
python -I qc_random.py         # 随机 20 条回查 + 搜索回归，覆写 D1_QC_REPORT.md
```

校验结果：
- 唯一 ID 669/669；NGC/IC 交叉编号冲突 0。
- 随机 20 条（5 Messier + 5 Caldwell + 5 NGC/IC + 5 亮星）RA/Dec 与源表逐条一致，20/20 PASS。
- 原有 21 个目标全部保留。
- 中文/英文/Messier/NGC/Caldwell/IC/HIP 搜索回归全部 PASS。
- 坐标范围 0≤RA<24、−90≤Dec≤90 全部通过。

详见 `D1_QC_REPORT.md` 与 `D1_DEVICE_TEST.md`。

## 6. 许可与分发

- OpenNGC：CC-BY-SA-4.0；Caldwell 元数据：MIT；HYG：CC-BY-SA-4.0（以仓库 LICENSE 快照为准）。
- 本目录是上述数据的衍生数据库，数据部分按 **CC-BY-SA-4.0** 分发，并保留来源与许可说明；代码部分沿用项目自身许可。
- 应用运行时不访问上述网站；搜索、筛选、追踪全部使用打包在 HAP 内的本地数据。

## AR 星座连线

连线来自 [Stellarium Modern](https://github.com/Stellarium/stellarium/tree/daace2add6a1bf886e8ee1934f51e9c69f818d18/skycultures/modern)，作者为 Stellarium 团队。导入 88 个星座的线段，按 HIP 号匹配本目录的 HYG v3.5 J2000 坐标，去重后得到 710 个端点和 695 条线段。衍生数据按 [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/) 分发，署名随 HAP 一起打包。

下载该版本的 Modern `index.json` 和 [Stellarium Chinese v26.3 的 `index.json`](https://raw.githubusercontent.com/Stellarium/stellarium/v26.3/skycultures/chinese/index.json) 后，运行 `node tools/catalog/build_constellations.mjs /path/to/modern.json /path/to/chinese.json` 重新生成 `Constellations.ets`。脚本检查星座数量、端点坐标范围和 HIP 匹配结果。

中文模式保留 D1 中已有的常用中文名，其余按 HIP 匹配 Stellarium Chinese v26.3 的中文名。该数据由 Karrie Berglund 和 Sun Shuwei 贡献，按 CC BY-SA 4.0 分发。英文模式使用 HYG 或 Stellarium Modern 的常用名。缺少对应名称时使用拜耳、弗兰斯蒂德、HR 或 HIP 编号。520 颗新增恒星由 `TargetCatalog.ets` 按 HIP 去重后合并进应用目录，原 D1 文件作为 669 条基线保留。

## E4 手动星桥

星桥沿用已打包的恒星及其 J2000 坐标。由 HYG v3.5 补入原目录缺失且视星等 ≤ 4.0 的 79 颗 HIP 恒星，从 Stellarium Chinese v26.3 匹配其中 76 颗的中文名称。补充星表和现有 HIP 星座缩写的衍生数据按 CC BY-SA 4.0 分发，署名见随包的 `constellation-data-credit.txt`。使用同一个中文 `index.json` 运行 `python tools/catalog/build_star_hop.py /path/to/chinese.json` 重新生成。
