#!/bin/zsh
set -euo pipefail
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
cd "${0:A:h}"

# 沿用已验证的工程构建、模拟器启动和 DeviceHub 路径。
./启动模拟演示.command
device_id=$(xcrun simctl list devices available -j | /usr/bin/python3 -c 'import json,sys; devices=json.load(sys.stdin)["devices"].get("com.apple.CoreSimulator.SimRuntime.iOS-27-0", []); print(next(d["udid"] for d in devices if d["name"] == "EasyFind Demo"))')
demo_app="$HOME/Library/Developer/Xcode/DerivedData/EasyFind-LocalDemo/Build/Products/Debug-iphonesimulator/EasyFind.app"
bundle_id=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$demo_app/Info.plist")
xcrun simctl launch --terminate-running-process "$device_id" "$bundle_id" -uiMock -selfieDemo -phoneFindAuthorized -featureTestControls
print '已打开“功能”窗口。模拟器默认已连接自拍杆，可设置远程拍照延时并测试反向找手机。'
