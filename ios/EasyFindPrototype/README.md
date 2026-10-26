# EasyFind SwiftUI 前端原型

独立的黑白风格 iPhone 前端，包含设备、墨水屏与提醒三个页面。设备操作入口使用统一卡片，设置页区分返回与保存，开关提供清晰的开关状态和滑动反馈。

## 在 Xcode 查看

1. 打开本目录的 `EasyFind.xcodeproj`，选择 `EasyFind` scheme。
2. 选择 iPhone 模拟器，按 **⌘R** 运行。最低系统版本为 iOS 17。
3. 真机预览时，在 Signing & Capabilities 中选择自己的 Team，按需修改 Bundle Identifier。

工程无第三方依赖；设置和提醒保存在本机。当前 Bundle Identifier 为 `com.easyfind.companion`。

## 本次交互设计

- 设备页与图片来源入口使用一致的卡片、图标、箭头及按压反馈。
- 拍照延时点击“保存延时”后生效；直接返回会放弃草稿。找手机开关立即保存。
- 提醒编辑页在顶部提供取消和保存，空标题会提示补充。
- 开关使用 60 × 34 pt 胶囊，点击区域至少高 44 pt。开启时浅底黑滑块并显示“开”，关闭时深底灰滑块并显示“关”。
- 滑块约 0.18 秒平滑移动，支持点按、向右开启和向左关闭；保留系统开关的辅助功能语义，并尊重“减弱动态效果”。
- 上传演示显示“确认上传 → 正在上传… → 完成”，退出页面后取消演示任务。

![开关状态对比](docs/easyfind-toggle-states.png)

[三个主要页面预览](docs/easyfind-buttons-preview.png)展示页面和按钮布局；其中开关外观以本页上方的最新状态图为准。

## 功能范围

此工程用于前端评审：连接状态、查找距离、设备响铃、图片上传和 AI 生图均为演示；提醒仅保存本地数据。尚未接入蓝牙、UWB、实际墨水屏传输、系统通知或 AI 服务。

仓库原有硬件版 App 位于 `../EasyFind`，可按根目录说明运行。

## 构建与交互检查

已用 Xcode 27.1 与 iOS 27.0 模拟器验证。命令在本目录执行，`SIMULATOR_ID` 为本机选定的模拟器 ID，可通过 `xcrun simctl list devices available` 查询。若系统默认开发工具不是 Xcode，先设置 `DEVELOPER_DIR`。

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
export SIMULATOR_ID='<选定的模拟器 ID>'
xcodebuild -project EasyFind.xcodeproj -scheme EasyFind \
  -configuration Debug -sdk iphonesimulator \
  -destination "id=$SIMULATOR_ID" -derivedDataPath /tmp/easyfind-prototype-build \
  CODE_SIGNING_ALLOWED=NO build
xcrun simctl bootstatus "$SIMULATOR_ID" -b
xcrun simctl install "$SIMULATOR_ID" \
  /tmp/easyfind-prototype-build/Build/Products/Debug-iphonesimulator/EasyFind.app
xcodebuild -project UIReview/ButtonReview.xcodeproj -scheme ButtonReview \
  -destination "id=$SIMULATOR_ID" -derivedDataPath /tmp/easyfind-prototype-ui-checks \
  CODE_SIGNING_ALLOWED=NO test
```

`UIReview` 是独立的 XCUITest 工程，通过 Bundle Identifier 启动上一步安装的 App。检查覆盖开关点击与连续点击、双向拖动、手机开关、拍照草稿与保存、上传演示、提醒表单校验和设置页导航。测试会操作本机演示数据；开关和拍照延时会恢复运行前的值。
