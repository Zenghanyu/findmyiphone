# BrushSDK 选取与适配

来源：[asfigh665/findmyiphone](https://github.com/asfigh665/findmyiphone/tree/8b55b44/ink-screen-app)，`fork/feat/ink-screen-app-dpid` / `8b55b44`，原目录 `ink-screen-app/ios/BrushSDK/`，SDK 标识 2026.8.21。保留各源码文件原有版权声明与二进制依赖，不改变其权利归属。

本目录仅引入 `BLE`、`Support/Device`、`Support/ImageDither`、`Support/Tool` 与 `XTDitherBleProtocol.xcframework`（设备/模拟器切片），用于 HINK 240×240 六色普通 BLE 路径。没有引入上游完整 App、NFC 界面、HUD 或媒体资源。

本地修改 `BLE/XTBleWriteHelper.{h,m}`：移除 XTTool/XTMBManager 界面依赖，用 Foundation 做参数检查；通过 `statusHandler`/`progressHandler` 报告状态与实际包进度；取消后回调前检查 handler。业务方通过 `Infrastructure/EFInkBridge` 访问，不直接创建 SDK 界面。进度最高 95%，收到刷新指令接受后才完成；这不等于实屏已完成刷新。

选取的源码已清理行尾空白；此项归一化不改变算法或设备协议。

`Tests/image_core_test.c` 是本项目增加的主机 C 回归入口，不编入 App。检查 DPID 常量图、白色码值、六色标记、尺寸/缓冲区校验与原图裁剪。运行方法见根目录 `scripts/test-backend.sh`。

上游 Objective-C 仍有隐式保留 self 的警告，升级 SDK 时需保留回调隔离并重新运行构建和真机传输验收。
