#!/usr/bin/env bash
# Build the S0 HAP, install it on the watch, launch it, and capture a screenshot.
# Requires: DevEco Studio installed, project signing configured (debug profile
# must include the watch UDID), watch on the same WLAN with wireless debugging.
set -euo pipefail
export MSYS_NO_PATHCONV=1

DEVECO="/e/DevEco Studio"
HDC="$DEVECO/sdk/default/openharmony/toolchains/hdc.exe"
DEVICE="${1:-}"
if [ -z "$DEVICE" ]; then
  echo "usage: $0 <watch-ip>:<port>"
  exit 1
fi
BUNDLE="com.starpilot.audit"

cd "$(dirname "$0")/../starpilot-watch"

echo "== build =="
DEVECO_SDK_HOME='E:\DevEco Studio\sdk' NODE_HOME='E:\DevEco Studio\tools\node' \
  "$DEVECO/tools/node/node.exe" "$DEVECO/tools/hvigor/bin/hvigorw.js" \
  assembleHap --mode module -p product=default -p buildMode=debug --no-daemon

HAP="$(find entry/build -name '*-signed.hap' | head -1 || true)"
if [ -z "$HAP" ]; then
  echo "ERROR: no signed HAP found."
  echo "Configure File > Project Structure > Signing Configs in DevEco, then retry."
  exit 1
fi
echo "HAP: $HAP"

echo "== connect =="
"$HDC" tconn "$DEVICE" || true
"$HDC" list targets

echo "== install =="
"$HDC" -t "$DEVICE" install -r "$HAP"

echo "== launch =="
"$HDC" -t "$DEVICE" shell aa start -a EntryAbility -b "$BUNDLE"

sleep 3
echo "== pid =="
"$HDC" -t "$DEVICE" shell pidof "$BUNDLE" || true

echo "== screenshot =="
mkdir -p "$(dirname "$0")/../artifacts"
"$HDC" -t "$DEVICE" shell snapshot_display -f /data/local/tmp/starpilot_home.jpeg
"$HDC" -t "$DEVICE" file recv /data/local/tmp/starpilot_home.jpeg \
  "$(dirname "$0")/../artifacts/watch_home.jpeg"

echo "done"
