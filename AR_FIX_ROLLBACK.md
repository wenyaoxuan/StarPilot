# AR 修复回滚说明

日期：2026-11-08  
适用构建：12 点模式，HAP `2b2a38a37760d2d4eb323dfad58388fd6fb517a7290db38c693483e976f51b02`

## 1. 回滚前准备

1. 备份当前改动：

```bash
cd starpilot-watch
git diff > ../AR_ROLLBACK_CURRENT.patch
```

2. 确认基线文件存在：

```bash
ls AR_AUDIT/baseline/ArPage.ets \
   AR_AUDIT/baseline/Index.ets \
   AR_AUDIT/baseline/NavPage.ets \
   AR_AUDIT/baseline/OrientationHub.ets \
   AR_AUDIT/baseline/SensorHub.ets
```

3. 基线哈希：`AR_AUDIT/baseline/SHA256SUMS.txt`

## 2. 完全回滚 AR（恢复审计前代码）

> 注意：这会恢复旧的 ROT/投影实现，旧版本存在已知的方向/对准问题，仅用于对比或放弃本次修复。

### 2.1 恢复基线文件

```bash
cd <repo-root>
cp AR_AUDIT/baseline/ArPage.ets starpilot-watch/entry/src/main/ets/pages/ArPage.ets
cp AR_AUDIT/baseline/Index.ets starpilot-watch/entry/src/main/ets/pages/Index.ets
cp AR_AUDIT/baseline/NavPage.ets starpilot-watch/entry/src/main/ets/pages/NavPage.ets
cp AR_AUDIT/baseline/OrientationHub.ets starpilot-watch/entry/src/main/ets/common/OrientationHub.ets
cp AR_AUDIT/baseline/SensorHub.ets starpilot-watch/entry/src/main/ets/common/SensorHub.ets
```

（`<repo-root>` 是本仓库根目录。）

### 2.2 删除 F1–F4 新增文件

```bash
rm common/SensorData.ets
rm common/CameraPose.ets
rm common/SkyProjection.ets
rm common/AttitudeFilter.ets
```

### 2.3 移除诊断页的 SensorAuditPage

`pages/DiagnosticsPage.ets` 没有基线副本，需要手动：

1. 删除 `import { SensorAuditPage } from './SensorAuditPage';`
2. 删除 Swiper 中的 `SensorAuditPage({ ... })`
3. 把页数从 6 改回 5，底部 `x/6` 改回 `x/5`

或直接删除 `pages/SensorAuditPage.ets`，并在 `DiagnosticsPage` 中删掉引用。

### 2.4 重新构建安装

```bash
cd starpilot-watch
PATH="E:/DevEco Studio/tools/node:$PATH" \
DEVECO_SDK_HOME="E:/DevEco Studio/sdk" \
"E:/DevEco Studio/tools/hvigor/bin/hvigorw" assembleHap \
  --mode module -p product=default -p buildMode=debug --no-daemon

HDC="E:/DevEco Studio/sdk/default/openharmony/toolchains/hdc.exe"
"$HDC" -t <watch-ip>:<port> install -r \
  entry/build/default/outputs/default/entry-default-signed.hap
```

### 2.5 校验

```bash
cd starpilot-watch/entry/src/main/ets
sha256sum pages/ArPage.ets pages/Index.ets pages/NavPage.ets \
  common/OrientationHub.ets common/SensorHub.ets
```

对照 `AR_AUDIT/baseline/SHA256SUMS.txt`；应恢复为：

```text
aae6748978853811a4c85b38ce55de8efc171f51d3afe45f776dde7d521ca862  ArPage.ets
3a2d978732e07d299ca6a5112cc8b8401539cdde62a9da0c1cf55eb0d2c730bb  Index.ets
2292814be7b8363d80b7d5dc8a91c2b5d1ca975b3720ffc177ce2db2086ae6da  NavPage.ets
ba84c5a2de8422627ebf6280deda8220563b636f16d981eee0afe6938d9c9427  OrientationHub.ets
8f74e2bd11f5881dcab4524cd2fb3e931653b0b079107fe9ec4e46e9892f9f87  SensorHub.ets
```

## 3. 只回滚 GPS（保留 AR 修复）

1. 删除 `common/GeoLocation.ets`
2. 删除 `data/Cities.ets` 中 `ensureGpsCity/currentGpsCityIndex/GPS_CITY_*`
3. 删除 `LocationPage` 的 GPS 按钮/状态/`onGpsFix`
4. 删除 `Index` 的 GPS 持久化、`applyGpsFix`、`ensureGpsCity` 调用
5. 删除 `module.json5` 中两个定位权限
6. 删除 `string.json` 的 `perm_reason_location`
7. 重建安装

## 4. 只禁用 AR 入口（最小回滚）

如果不想要 AR，但保留其他功能：

1. `pages/NavPage.ets` 顶部 AR 按钮不再调用 `onOpenAr`；
2. 或 `pages/Index.ets` 删除 `showAr` 覆盖层和 `onOpenAr` 赋值。

这样不会恢复旧 AR 代码，只是隐藏入口。

## 5. 回滚注意事项

- 完全回滚会恢复旧的 `ArPage`（+Y 观察轴/旧投影），会重新出现历史上的上下反/无法对准问题。
- 本次删除了表背模式和 MAG 订阅；没有保留旧表背模式的源码副本。如需恢复表背模式，只能从 `AR_POINTING_MODES.md` 的历史说明或 git 历史重建。
- 回滚后仍需重新做真机测试；基线哈希只证明文件一致，不证明功能正确。
- 签名材料在 `build-profile.json5`，不要提交 `.p12/.cer/.p7b` 或密码。
