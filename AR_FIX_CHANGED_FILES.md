# AR 修复最终改动清单

日期：2026-11-08  
构建：12 点指向模式；表背模式已移除  
最终 HAP：`2b2a38a37760d2d4eb323dfad58388fd6fb517a7290db38c693483e976f51b02`

## 1. 核心 AR 文件

| 文件 | 修改前 SHA256 | 修改后 SHA256 | 关键函数/内容 |
|---|---|---|---|
| `common/SensorData.ets` | 新增 | `94dd6b392cb0a0e9310d8b6372060af0b0a2344bc79fe1e2396350d95407ef0c` | `OrientationSample`、`RotationSample`、`GyroSample`、`SensorStats` |
| `common/OrientationHub.ets` | `ba84c5a2de8422627ebf6280deda8220563b636f16d981eee0afe6938d9c9427` | `82000c91aedb97e31db8a231892da0d6ddeba4ac61dcb8b4b175a76f7f82a73d` | `subscribeSample`、`statsSnapshot`、NaN/ts/accuracy/stale 校验 |
| `common/SensorHub.ets` | `8f74e2bd11f5881dcab4524cd2fb3e931653b0b079107fe9ec4e46e9892f9f87` | `ceb3cbd91fccf497a35f5289bfd1a058f3eb2652bd01591f13b0c03b59d1eb8d` | `subscribeRotSample`、`subscribeGyroSample`、ROT/GYRO 校验与统计 |
| `common/CameraPose.ets` | 新增 | `ec03c067766bea354d01d5490c1fcfe3715ad42b5cbe45813f2eb583b571d9f7` | `cameraPoseFromQuat`、`cameraPoseFromQuatTwelve`、`cameraPoseFromTwelveReference` |
| `common/SkyProjection.ets` | 新增 | `fd5b321417b4acaabc4940ba55e1ca610170de5a8b2bf61458de9cc62a6945b9` | `enuVector`、`projectPoint`、`screenDirection`、`angularSepVec` |
| `common/AttitudeFilter.ets` | 新增 | `b8a396961de297feb77790f3b5da474480b0aada50081e6a211382b372c9353f` | OFF/SLERP/1€、q/−q、gap restart |
| `pages/ArPage.ets` | `aae6748978853811a4c85b38ce55de8efc171f51d3afe45f776dde7d521ca862` | `52c95841bd5d34c1a098445fd0f317bb460f9c864c102c1aa96e060ffbabaaa2` | 12 点模式、ORI+ACC 姿态、透视投影、目标/边缘箭头 |
| `pages/SensorAuditPage.ets` | 新增 | `0fe849f3a465389b0155df8cda34b8b79340becfc38760e99e7f6cd948c1916f` | ORI/ROT/GYRO 统计、F5 decl/dip/H、+Y 对照 |
| `pages/DiagnosticsPage.ets` | 修改 | `4fb3700e3b8863ac537bdf4910baabbbeb970301d8fbc29e6cb1e48a1959a1a0` | 6 页诊断，加入 SensorAuditPage |
| `pages/Index.ets` | `3a2d978732e07d299ca6a5112cc8b8401539cdde62a9da0c1cf55eb0d2c730bb` | `04da4626e1dc5de7305528b02c53e450c6152c2fa3733adedfca3134a8f934a1` | AR 覆盖层、Diagnostics 透传、GPS 城市/刷新 |
| `pages/NavPage.ets` | `2292814be7b8363d80b7d5dc8a91c2b5d1ca975b3720ffc177ce2db2086ae6da` | `2292814be7b8363d80b7d5dc8a91c2b5d1ca975b3720ffc177ce2db2086ae6da` | 未改；保留 AR 入口 |

## 2. GPS 定位文件

| 文件 | 修改前 | 修改后 | 关键 |
|---|---|---|---|
| `common/GeoLocation.ets` | 新增 | `b3e2c10773f8b8fac59a4d70e74971d911d1e572c8820028c3ce865708ff87e4` | 权限、`getCurrentLocation`、结果校验 |
| `data/Cities.ets` | 修改 | `18a3ff28838fc3cd696cb36403e5cab0bb9563f9d8006f19b5c5fa5d6781e052` | `ensureGpsCity`、`currentGpsCityIndex` |
| `pages/LocationPage.ets` | 修改 | `505e4010050e4e0f211a147ae41ada0f1790e73eb6b3a55e66404f503a200853` | GPS 按钮、精度/状态、定位 chip |
| `entry/src/main/module.json5` | 修改 | `43ce032aee4beb8825e1472b1099bd337cc9dc0c563f12ffaff2cb459b140580` | `APPROXIMATELY_LOCATION`、`LOCATION` |
| `resources/base/element/string.json` | 修改 | `4fc0a5b5267909ed0075580e64a984552f4569053bad01b2aea88f1ad116dac4` | `perm_reason_location` |

## 3. 测试/审计脚本

| 文件 | 说明 |
|---|---|
| `tools/ar-audit/pose_test.mjs` | 世界 X 镜像 + 12 点/表背姿态数学测试 |
| `tools/ar-audit/projection_f3_test.mjs` | 透视/背面/圆屏投影测试 |
| `tools/ar-audit/filter_test2.mjs` | OFF/SLERP/1€ 合成测试 |
| `tools/ar-audit/ar_math_test.mjs` | 旧投影对照 |

## 4. 依赖关系

```text
ArPage
 ├─ CameraPose (Fusion Vec3/rotateByQuat)
 ├─ SkyProjection (CameraPose)
 ├─ AttitudeFilter
 ├─ SensorHub (SensorData)
 ├─ OrientationHub
 ├─ Astro / SolarSystem
 └─ Cities / AuditLog

LocationPage → GeoLocation → LocationKit/AbilityKit
Index → Cities.ensureGpsCity / Preferences
```

## 5. 资源变化

- 删除表背模式：不再订阅 MAG，不再计算 ACC+MAG 表背姿态，不再有模式切换和 `AR_QDIR` 日志。
- 12 点模式只保留 ORI + ACC + ROT 回退。
- 诊断页仍保留 ROT/ORI/GYRO 与磁偏角信息，便于后续排查。

## 6. 构建

```bash
cd starpilot-watch
PATH="E:/DevEco Studio/tools/node:$PATH" \
DEVECO_SDK_HOME="E:/DevEco Studio/sdk" \
"E:/DevEco Studio/tools/hvigor/bin/hvigorw" assembleHap \
  --mode module -p product=default -p buildMode=debug --no-daemon
```

输出：`entry/build/default/outputs/default/entry-default-signed.hap`
