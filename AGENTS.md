# Codex Instructions — StarPilot V1

Read `CODEX_HANDOFF.md` first. It is the authoritative handoff for project state, device evidence, pending work, and constraints.

## Hard rules

- HarmonyOS wearable Stage model + ArkTS only. Do not introduce Android APIs.
- Never invent APIs, sensor behavior, device results, or test passes.
- Do not claim a real-device test passed without an `hdc` screenshot/log or a user-confirmed action in the report.
- Do not apply a fixed magnetic declination or heading offset. The true-north/magnetic-north datum is still unconfirmed; see `AR_FIX_F5_NORTH_REFERENCE.md`.
- Keep AR in **12-point mode only**. The back-camera mode was removed at the user's request; do not reintroduce it without an explicit request.
- The user's camera (Sony A7R IV) is fully manual. Never add camera control/shutter triggering.
- Keep the app usable offline; network is only for weather. Do not make core pointing/astronomy depend on a server.
- Never commit signing material: `build-profile.json5`, `*.p12`, `*.cer`, `*.p7b`, passwords, or `~/.ohos` contents. Use `build-profile.example.json5` + DevEco automatic signing.
- Do not run `git clean -fdx` or delete untracked files. Many untracked files are deliberate audit evidence (`AR_AUDIT/`, `s0-results/`, reports).
- Do not commit unless the user asks. The working tree contains a large, intentional set of uncommitted changes.

## Build

```bash
cd starpilot-watch
PATH="E:/DevEco Studio/tools/node:$PATH" \
DEVECO_SDK_HOME="E:/DevEco Studio/sdk" \
"E:/DevEco Studio/tools/hvigor/bin/hvigorw" assembleHap \
  --mode module -p product=default -p buildMode=debug --no-daemon
```

Output: `entry/build/default/outputs/default/entry-default-signed.hap`

If `build-profile.json5` is missing on a fresh checkout:

1. Copy `starpilot-watch/build-profile.example.json5` to `starpilot-watch/build-profile.json5`.
2. Open the project in DevEco Studio and configure automatic signing for the watch.
3. Do not paste signing passwords into tracked files or the handoff.

## Install / device

```bash
HDC="E:/DevEco Studio/sdk/default/openharmony/toolchains/hdc.exe"
"$HDC" list targets
"$HDC" -t <watch-ip>:<port> install -r \
  starpilot-watch/entry/build/default/outputs/default/entry-default-signed.hap
```

Current device (volatile): RTS-AL00 / Watch 5 46mm / HarmonyOS 6.1.0.333 / API 23 / 466×466. Last known HDC target: `<watch-ip>:<port>`; the port changes.

If AR shows `等待 ROT` or `ORIENTATION UNRELIABLE` after returning from Settings, `aa force-stop com.starpilot.audit` then restart. Automatic sensor recovery is not implemented.

## Tests

```bash
# photo optical math
cd tools/photo-test
npx esbuild ../../starpilot-watch/entry/src/main/ets/common/Photo.ets \
  --loader:.ets=ts --format=esm --outfile=photo.mjs
node verify.mjs
node verify_formats.mjs

# light pollution / sky model
npx esbuild ../../starpilot-watch/entry/src/main/ets/common/LightPollution.ets \
  --bundle --loader:.ets=ts --resolve-extensions=.ets,.ts,.js \
  --format=esm --outfile=lightpollution.mjs
node verify_light.mjs

# astronomy cross-check
cd ../astro-test
npx esbuild ../../starpilot-watch/entry/src/main/ets/common/SolarSystem.ets \
  --bundle --loader:.ets=ts --resolve-extensions=.ets,.ts,.js \
  --format=esm --outfile=solar.mjs
node solar-verify.mjs

# AR math
cd ../ar-audit
node pose_test.mjs
node projection_f3_test.mjs
node filter_test2.mjs
```

## Where to look

- Product/status: `README.md`
- Handoff: `CODEX_HANDOFF.md`
- AR behavior/test: `AR_POINTING_MODES.md`, `AR_FIX_TEST_REPORT.md`
- AR change/rollback: `AR_FIX_CHANGED_FILES.md`, `AR_FIX_ROLLBACK.md`
- GPS: `GPS_LOCATION_REPORT.md`
- Sun + photo assistant: `SUN_AND_PHOTO_UPDATE.md`
- Light pollution/sky model: `LIGHT_POLLUTION_REPORT.md`
- Original platform audit: `TECH_AUDIT.md`

## Current highest-value work

1. Real-device verify the latest crown navigation / target-catalog crown scroll.
2. Complete the missing A–F motion tests (360°, pitch, roll, abnormal sensors) if the user agrees.
3. Resolve the ORIENTATION magnetic-vs-true-north datum with an external reference.
4. Validate Bortle estimates for the user's actual site; manual override is available in the Horizon page.
5. Real balcony horizon data and S3 field pointing remain product-level gaps.
