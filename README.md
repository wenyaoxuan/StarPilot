# StarPilot

HarmonyOS 手表上的观星与深空摄影辅助工具，使用 ArkTS Stage 模型开发。当前版本 **0.1.1**。

## 下载

**[打开下载列表](https://github.com/wenyaoxuan/StarPilot/releases)** · [最新版本](https://github.com/wenyaoxuan/StarPilot/releases/tag/v0.1.1) · [安装说明](DOWNLOADS.md)

| 下载 | 用途 |
|---|---|
| [源码 ZIP](https://github.com/wenyaoxuan/StarPilot/archive/refs/heads/main.zip) | DevEco Studio 打开工程，为自己的手表配置自动签名后构建安装 |
| [版本下载列表](https://github.com/wenyaoxuan/StarPilot/releases) | 版本说明、固定版本源码、供自行签名的 unsigned HAP 及 SHA-256 校验文件 |

unsigned HAP 需要用自己的证书与设备 Profile 签名。个人调试签名包只能安装到 Profile 指定的设备。普通用户直接安装的公开分发包尚未提供，安装要求见 [DOWNLOADS.md](DOWNLOADS.md)。

## 当前功能

- 1,198 个天体，包含全部 710 颗星座连线端点，支持中英文星名、搜索、分类与可见筛选。
- 12 点边缘指向导航和 AR 星空，包含星座连线、太阳系目标与转向提示。
- 实物对准校准由用户瞄准目标后测量当次方位差，导航与 AR 共用，重启或更换观测位置后清除。
- 单次精确定位，拒绝过旧或系统报告误差超过 100 米的结果。主页标记默认城市、手选城市和上次 GPS。
- 首次隐私选择、GPS 单独同意、清除 GPS、个人信息与第三方 API 清单、可见的开源许可。
- Open-Meteo 与 7Timer 城市天气，支持缓存与链路恢复重试。精确 GPS 用于本地计算，天气使用单独选择的城市目录坐标。
- 摄影助手包含 49 台机身、视场、NPF、曝光与堆栈规划，支持自定义焦段、光圈、ISO 和总曝光时间。
- 16 扇区遮挡编辑、Bortle 手动设置、流星雨、ISS 过境、手动星桥与极轴辅助。

天文、目录和摄影核心可离线使用。相机由用户手动操作。

## 构建与安装

1. 使用 DevEco Studio 打开 `starpilot-watch/`。工程 compile SDK 为 26.0.0，compatible/target 为 HarmonyOS 6.1.0（API 23）。
2. 将 `build-profile.example.json5` 复制为 `build-profile.json5`，用 DevEco 为自己的手表配置自动签名。
3. 开启手表的 HDC / 无线调试，使用 DevEco 运行或通过 HDC 安装签名 HAP。

```sh
hdc tconn <watch-ip>:<port>
hdc install -r entry-default-signed.hap
```

已测试设备为 HUAWEI WATCH 5 46mm，HarmonyOS 6.1。其他设备兼容性待验证。

## 验证范围与限制

数学验证脚本位于 `tools/`，项目状态见 [CODEX_HANDOFF.md](CODEX_HANDOFF.md)。根目录报告包含各开发阶段的历史记录，以交接文档和当前源码为准。原始设备截图、日志和私有签名文件保留在本地，公开仓库中的历史证据路径可能无法打开。

月球现场约 20° 偏差的根因和实物校准后的精度仍待验证。系统航向的磁北/真北基准尚未确认，AR 动作测试、真实阳台遮挡与现场指向验收尚未全部完成。光污染数值为规划估算。

## 许可证

应用代码采用 [MIT](LICENSE)。OpenNGC、HYG、Stellarium 衍生星表按 CC BY-SA 4.0 分发，Caldwell 元数据和 satellite.js 采用 MIT。完整归属与服务条款见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。
