# EasyFind 功能窗口

本阶段提供“功能”窗口、模拟设备、BLE 配置客户端和固件协议草案。页面默认自拍杆已经在 iPhone 系统蓝牙中连接；App 不扫描附近设备，也不要求用户在页面内选择或连接自拍杆。没有真实硬件，因此模拟快门和找手机事件只用于确认使用流程。

## 查看页面

项目根目录新增 `启动自拍杆演示.command`。双击会编译原 EasyFind 工程并切换到“功能”窗口。也可以在已运行 App 底部点“功能”；“查找”窗口继续保留原来的找标签页面。

模拟器演示使用启动参数 `-uiMock -selfieDemo`。`-selfieDemo` 只负责打开“功能”窗口；模拟设备只编译进模拟器产物。

## 操作

1. 真实手机先在“设置 > 蓝牙”中完成自拍杆连接；回到“功能”窗口后 App 会自动读取设备设置。模拟器会直接进入模拟已连接状态。
2. 在“远程拍照”卡片选择即刻、3 秒、5 秒、10 秒，或拖动滑块设置 0–30 秒。
3. 点“保存到自拍杆”，等待设备确认。仅选择时间不会改变设备当前设置。
4. 打开系统相机，按自拍杆的远程拍照按键。倒计时由设备执行，App 不需要打开。
5. 在“反向找手机”卡片允许手机通知；按自拍杆上的找手机按键，手机会播放提示并显示本地通知。模拟器可点“模拟反向找手机按键”查看事件。
6. 退出并重新运行演示，已保存的模拟设备设置仍能读回。

模拟持久化使用模拟器 App 容器中的存储代替设备 Flash；模拟计时仍发生在本机演示进程中。它不能证明真实 App 退出后设备还能拍照。

## 真实产品目标

App 只保存配置；实际自拍杆固件保存延时并独立倒计时，随后通过标准 BLE HID 发送音量增加键。用户之后无需打开 EasyFind，但要完成系统蓝牙配对并打开手机相机。自拍杆还应通过自定义配置服务主动通知 `PhoneFindRequested` 事件，App 在前台反馈声音/震动，在后台安排本地通知。

真实硬件还需要实现《自拍杆固件协议-v0.1.md》，并完成 iPhone/Android 的 HID、相机和后台通知兼容性验证。

## 本阶段验证

- iOS 模拟器构建通过。
- iPhone 目标在关闭签名的情况下构建通过；尚未安装到实体 iPhone。
- 协议检查 19 项通过，覆盖事务号、迟到回复、错误回显、设备拒绝、参数边界、能力检查和找手机事件帧。
- UI 测试 10 项通过：原有找标签功能 5 项、功能窗口 5 项。
- 功能窗口 UI 测试覆盖系统已连接状态、保存、App 重启后读回、未保存草稿、取消倒计时、0 秒事件、保存失败和找手机事件。
- 模拟器实际运行页面已截图检查。

新增源文件位于 `ios/EasyFind/Sources/SelfieStick/`，入口位于 `Sources/App/EasyFindTabBarController.swift`。未修改 SDK 二进制和原有标签的 BLE 报文。

如需重新运行 UI 测试，可使用以下命令。构建缓存放在临时目录，避免测试进程加载缓存时触发 macOS 文档目录访问检查：

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project ios/EasyFind/EasyFind.xcodeproj -scheme EasyFind \
  -destination 'platform=iOS Simulator,name=EasyFind Demo' \
  -derivedDataPath /tmp/EasyFind-SelfieQA \
  -parallel-testing-enabled NO \
  -skip-testing:EasyFindUITests/EasyFindUITests/testDemoVideo \
  CODE_SIGNING_ALLOWED=NO test
```
