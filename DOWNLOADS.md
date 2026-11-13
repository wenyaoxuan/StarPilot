# 下载与安装

[所有版本](https://github.com/wenyaoxuan/StarPilot/releases) · [最新版本](https://github.com/wenyaoxuan/StarPilot/releases/latest)

| 文件 | 说明 |
|---|---|
| `StarPilot-0.1.1-source.zip` | 固定版本源码，含许可证，可用 DevEco Studio 为自己的设备签名安装 |
| `StarPilot-0.1.1-unsigned.hap` | 未签名调试 HAP，需自行签名后通过 HDC 安装 |
| `SHA256SUMS.txt` | 上述文件的 SHA-256 校验值 |
| GitHub 自动生成的 Source code | 对应发布标签的源码 |

## 手表用户

当前提供的是开发预览版，普通用户直接安装的公开分发包尚未提供。unsigned HAP 不能直接安装。个人调试证书和 Profile 绑定设备，需要为自己的手表配置签名。[华为签名说明](https://developer.huawei.com/consumer/cn/doc/app/agc-help-releasefaq-0000001110342644/)

## 使用 DevEco Studio

1. 下载源码并解压，打开其中的 `starpilot-watch/`。
2. 安装项目所需 SDK，复制 `build-profile.example.json5` 为 `build-profile.json5`。
3. 登录自己的华为开发者账号，为手表配置自动签名。
4. 开启手表 HDC 与无线调试，用 DevEco 运行，或将生成的签名 HAP 通过 HDC 安装。

如使用 unsigned HAP，请使用华为官方签名工具和自己的证书及 Profile 完成签名。签名所需材料在华为开发者平台管理。

## 校验

在 PowerShell 中运行以下命令，与 `SHA256SUMS.txt` 对照。

```powershell
Get-FileHash -Algorithm SHA256 .\StarPilot-0.1.1-unsigned.hap
Get-FileHash -Algorithm SHA256 .\StarPilot-0.1.1-source.zip
```

预览版的实物对准校准精度与磁北/真北基准仍待现场验证，完整状态见 `CODEX_HANDOFF.md`。
