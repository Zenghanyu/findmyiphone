#!/bin/zsh
set -euo pipefail
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
cd "${0:A:h}"

if [[ ! -d "$DEVELOPER_DIR" ]]; then
  print '请先将 Xcode 安装到 /Applications。'
  exit 1
fi

# 选择本机已安装的最新 iOS runtime，兼容不同 Xcode 版本。
runtime_id=$(xcrun simctl list runtimes -j | /usr/bin/python3 -c 'import json,sys; rs=[r for r in json.load(sys.stdin)["runtimes"] if r.get("isAvailable") and r["identifier"].startswith("com.apple.CoreSimulator.SimRuntime.iOS-")]; print(max(rs, key=lambda r: tuple(map(int,r["version"].split("."))))["identifier"] if rs else "")')
if [[ -z "$runtime_id" ]]; then
  print '请先在 Xcode → Settings → Components 安装 iOS 模拟器。'
  exit 1
fi

device_id=$(xcrun simctl list devices available -j | /usr/bin/python3 -c 'import json,sys; ds=json.load(sys.stdin)["devices"].get(sys.argv[1], []); print(next((d["udid"] for d in ds if d["name"] == "EasyFind Demo"), ""))' "$runtime_id")
if [[ -z "$device_id" ]]; then
  device_id=$(xcrun simctl create 'EasyFind Demo' com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro "$runtime_id")
fi
device_state=$(xcrun simctl list devices available -j | /usr/bin/python3 -c 'import json,sys; ident=sys.argv[1]; print(next(d["state"] for ds in json.load(sys.stdin)["devices"].values() for d in ds if d["udid"] == ident))' "$device_id")
if [[ "$device_state" != Booted ]]; then
  xcrun simctl boot "$device_id"
fi
if [[ -d "$DEVELOPER_DIR/Applications/Simulator.app" ]]; then
  open -a "$DEVELOPER_DIR/Applications/Simulator.app" --args -CurrentDeviceUDID "$device_id"
else
  open -a "$DEVELOPER_DIR/../Applications/DeviceHub.app"
fi
xcrun simctl bootstatus "$device_id" -b

build_dir="$PWD/build/DerivedData"
mkdir -p "${build_dir:h}"
print '正在编译 EasyFind…'
xcodebuild -project ios/EasyFind/EasyFind.xcodeproj -scheme EasyFind \
  -configuration Debug -sdk iphonesimulator \
  -destination "platform=iOS Simulator,id=$device_id" \
  -derivedDataPath "$build_dir" CODE_SIGNING_ALLOWED=NO build \
  > "$build_dir-build.log" 2>&1 || {
    tail -60 "$build_dir-build.log"
    exit 1
  }
demo_app="$build_dir/Build/Products/Debug-iphonesimulator/EasyFind.app"
bundle_id=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$demo_app/Info.plist")
xcrun simctl install "$device_id" "$demo_app"
xcrun simctl launch --terminate-running-process "$device_id" "$bundle_id" -uiMock "$@"
print '已启动模拟演示：点击“扫描标签”，再选择标签查看测距和响铃界面。'
print '模拟器数据为演示数据，真实 UWB 测距需要 iPhone 与配套标签。'
