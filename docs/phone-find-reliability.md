# 长期后台找手机：改造与验收

日期：2026-10-18。目标是用户首次完成配对、授权与 App 接入后，长期不打开 App，仍能按设备按钮请求手机响铃。实现依靠 Core Bluetooth 保存连接任务、通知订阅和按事件恢复 App；进程无需一直执行。用户上划强退、关闭蓝牙、手机关机、未完成重启后首次解锁，以及超出无线范围，仍是需要单独处理和验证的边界。

本轮未烧录开发板、未进行新版真机联调。2026-10-12 的锁屏、静音及重复触发记录属于旧版，不能当作此次协议扩展或长期后台恢复的验收结果。当前 Xcode 26.6 / Swift 6.3.3 可编译模拟器；仓库真机 FindMyTagKit 由 Swift 6.4 构建，真机需 Xcode 27 或供应商提供兼容 SDK。详见 [本机运行说明](../本机运行说明.md)。

## 代码现状与问题

改造前已有 `bluetooth-central` 后台模式、固定恢复标识、App 生命周期持有的蓝牙服务、已知设备 UUID、断线重连以及 iOS 26 AlarmKit。这些是长期使用的基础，无需增加静音音频、持续定位或第二个 App。

检查源码发现以下会中断交付的路径：

| 原有问题 | 用户可能看到的结果 | 本轮处理 |
| --- | --- | --- |
| 固件在未连接、未加密或 App 尚未订阅时直接丢弃长按事件 | 按键恰好发生在重连期间，连接恢复后也不响 | 请求在 RAM 中保存 30 秒，恢复后投递 |
| 通知只发送一次，没有请求 ID 和应用确认 | 通知丢失无法重试，盲目重发又可能重复响铃 | 随机 ID、剩余有效期、每 2 秒重试、终态确认 |
| 配置超时会关闭传输；连接失败或服务发现错误存在等待前台重试的路径 | App 在后台遇到一次错误后失去后续按钮事件 | 配置失败保留后台通道；传输层自动恢复并保留系统待重连请求 |
| 恢复时重复发现服务或订阅，依赖再次收到订阅回调 | 缓存的 GATT 或已恢复订阅不能及时进入就绪 | 使用恢复的服务、特征和 `isNotifying`，订阅早到的事件先缓冲 |
| 没有串行 ATT 写入队列 | 启用、配置读取与找手机确认交错，错误难以恢复 | 单次只保留一个 Write with response 在途 |

## 开发方案与实现

1. **恢复蓝牙通道**：启动时创建同一恢复标识的 manager；恢复回调先设置 delegate，待蓝牙可用再继续发现。优先连接已记住的设备，离开范围时保留系统管理的连接请求。连接失败采用最多 60 秒的系统启动延迟逐步退避；发现、订阅或 ATT 写入错误修复通道。配置读取失败不会主动取消健康订阅。
2. **扩展固件投递**：长按产生非零 64 位随机 ID，连续长按合并。连接、加密和订阅准备好后发送；新版 App 每次连接先启用可靠模式，再读取配置。通知发送成功仅说明已尝试提交，不清除可靠请求。
3. **提交后确认**：App 在系统接受提醒后保存处理记录，再回传请求 ID 与处理结果。用户关闭响铃或缺少授权也属于明确终态。暂时提交失败、记录保存失败不确认，允许固件重试。并发同一 ID 不重复提交；成功记录可跨进程恢复，最多保存 128 条。
4. **限制迟到行为**：30 秒有效期从首次按键计算，重试和连续按键不延长；断线保留、设备重启丢弃。App 使用已观察到的剩余有效期避免重试延长请求。拍照仍不排队，恢复连接不会补拍。
5. **保留兼容路径**：帧版本仍为 `01`。旧 App 未启用可靠模式时，固件在 READ_CONFIG 后等待 500 ms，按原格式只通知一次；新版 App 仍接受旧固件事件。完整的缓存、确认与去重需要同时更新 App 和固件。

协议字段、状态码、金帧见 [BLE 协议](selfie-stick-protocol-v0.1.md)。核心代码位于 App 的 `SelfieStickBluetoothTransport.swift`、`PhoneFindDelivery.swift`、`SelfieStickService.swift`，以及固件的 `find_delivery.h`、`remote_protocol.h`、`main.cpp`。

该方案提高交付成功率，不提供任何情况下的可达承诺。固件的 30 秒窗口用于覆盖短暂重连，不用于数分钟后的迟到响铃。闹钟确认表示系统接受了请求，不代表用户确实听到铃声。系统调度与本地记录不是同一事务；极端情况下，系统已接受后、记录落盘前进程崩溃，仍存在去重窗口，不能宣称严格一次交付。设备有效期限制发送窗口；OS 首次延迟交付通知的时机也不由固件控制。系统是否重新启动 App，仍由 iOS 的 Core Bluetooth 后台恢复规则决定。

## 可重复的软件验证

以下命令均从仓库根目录执行。主机测试不需要手机或开发板；输出为成功也不能证明真实 BLE、锁屏唤醒或 AlarmKit 已验收。

```sh
clang++ -std=c++11 -Wall -Wextra -Werror \
  -I firmware/EasyFind-XIAO/include \
  firmware/EasyFind-XIAO/tests/protocol_test.cpp -o /tmp/easyfind-protocol-test
/tmp/easyfind-protocol-test

clang++ -std=c++11 -Wall -Wextra -Werror \
  -I firmware/EasyFind-XIAO/include \
  firmware/EasyFind-XIAO/tests/find_delivery_test.cpp -o /tmp/easyfind-find-delivery-test
/tmp/easyfind-find-delivery-test

xcrun swiftc -parse-as-library -module-cache-path /tmp/easyfind-swift-module-cache \
  ios/EasyFind/Sources/SelfieStick/SelfieStickProtocol.swift \
  ios/EasyFind/Sources/SelfieStick/PhoneFindDelivery.swift \
  ios/EasyFind/Tests/PhoneFindDeliveryTests.swift \
  -o /tmp/easyfind-phone-find-tests
/tmp/easyfind-phone-find-tests
```

固件测试覆盖控制命令与可靠事件金帧、非法参数、重试间隔、通知或确认丢失、有效期、连按合并、断线、旧客户端协商和计时回绕。Swift 主机测试覆盖报文兼容、系统接受前不确认、并发去重、持久化后重放、过期、禁用/未授权终态，以及存储失败不确认。

本机 PlatformIO Core 6.2.0 已安装在项目 `.venv`，工具链缓存放在 `build/platformio`。从仓库根目录执行下面的命令，只生成镜像，不上传：

```sh
PLATFORMIO_CORE_DIR="$PWD/build/platformio" .venv/bin/pio run --project-dir firmware/EasyFind-XIAO
```

构建原始镜像位于 `firmware/EasyFind-XIAO/.pio/build/xiao_esp32s3_remote/firmware.bin`，本轮另复制到 `outputs/firmware/0.2.0/easyfind-remote.bin`。该文件是应用分区镜像，不能当作完整 Flash 备份写到地址 0；实际安装应由 PlatformIO 在核对目标端口后执行。

App 模拟器构建：

```sh
xcodebuild -project ios/EasyFind/EasyFind.xcodeproj -scheme EasyFind \
  -configuration Debug -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build
```

UI 回归可在 Xcode Test 中选择 `SelfieStickUITests`。新增用例覆盖配置读取失败后仍能找手机，以及停止后重放相同请求不会重新响铃；模拟设备支持确认丢失和重复请求注入。`-selfieDemo` 和 `-featureTestControls` 仅用于模拟页面与状态，不能作为真机提醒证据。主机测试使用独立入口，不包含在 UI Test target 中。

## 真机准备与诊断证据

先解决真机 SDK 兼容与签名，安装新版 App，再核对目标开发板端口并烧录新版固件。在系统蓝牙配对，打开 App 一次建立自身连接；允许蓝牙与系统闹钟、打开并保存响铃。确认读取能力包含 `1F`，串口出现 `find.reliable=enabled`。只更新一端不能验收完整方案。

测试时脱离 Xcode 调试器，正常返回桌面并锁屏。后台长测期间不要为检查状态打开 App。测试结束后通过 Xcode Devices and Simulators 下载 App 容器，读取 `Documents/phone-find-diagnostics.log`，与开发板串口、按键和实际响铃时间对齐。日志最多约 128 KiB，长测时需及时导出，避免覆盖关键证据。

| 证据 | 能说明什么 |
| --- | --- |
| 固件 `find.request`、`find.delivery`、`find.expired` | 请求产生、尝试投递、有效期与尝试次数 |
| 固件 `find.ack ... accepted=1` | ID 匹配的请求被 App 按终态处理；status 0/1/2 需同时记录 |
| App `service.start`、`ble.restored`、`ble.connected`、`ble.subscribed` | App 启动与蓝牙恢复过程 |
| App `find.received`、`alarm.accepted`、`alarm.state=alerting` | 收到请求、系统接受调度、进入响铃状态 |
| 用户录像、秒表与锁屏停止操作 | 实际可闻铃声、延迟、停止及是否重复响铃 |

`find.delivery submitted=1` 不等于 App 已收到；`alarm.accepted` 不等于已经听到声音。不能用 Xcode Stop、模拟器 terminate 或用户上划来证明“系统因内存清理后的恢复”；需要真实系统清理证据，并记录设备控制台或 jetsam 日志。手机重启后首次解锁前的行为单独记录，不纳入已保证范围。

## 24 小时、72 小时、7 天验收矩阵

所有项目当前均为**待真机验收**。每轮记录 iPhone 型号、iOS 版本、App 构建、固件版本、供电方式、授权、低电量模式及蓝牙设置。每个检查点至少按键 10 次，逐次停止后再按下一次；记录成功数、重复响铃数、最大延迟及失败日志。响应目标：正常已连接时按键松开至响铃不超过 5 秒；短暂重连场景要求 App 在请求的 30 秒有效期内收到事件，系统接受后约 2 秒响铃。此为验收目标，不是 iOS 服务保证。

| 场景 | 24 小时 | 72 小时 | 7 天 | 通过条件 |
| --- | --- | --- | --- | --- |
| 连续锁屏，App 不再打开、设备始终在范围内 | 到时触发 | 到时触发 | 到时触发 | 各 10/10 次响铃，无重复；正常连接延迟达标 |
| 先离开范围 30 分钟，再返回；不打开 App | 执行 | 执行 | 执行 | 系统自动重连，返回后新请求可用 |
| 断线期间按键，30 秒内回到范围 | 执行 | 执行 | 执行 | 窗口内恢复并收到请求；同 ID 只处理一次 |
| 断线期间按键，超过 30 秒后返回 | 执行 | 执行 | 执行 | 旧请求不补响，新按键可触发 |
| 设备断电后开机，手机保持锁屏 | 执行 | 执行 | 执行 | 旧请求丢弃，重连后新按键可用 |
| 手机蓝牙关闭后开启，不打开 App | 执行 | 执行 | 执行 | 开启后恢复连接；关闭时不能触发，过期请求不补响 |
| 静音、专注、低电量模式分别测试 | 执行 | 执行 | 执行 | 记录每种状态下授权、延迟、实际声音；通知兼容路径另记 |
| 真实系统内存清理 App 后触发 | 有证据时执行 | 有证据时执行 | 有证据时执行 | 有清理和状态恢复证据，无需用户打开 App |
| 手机重启，首次解锁后不打开 App | 单独执行 | 单独执行 | 单独执行 | 记录是否恢复及首次可用时间，未实测前不承诺 |
| 用户上划强退，之后按键 | 记录边界 | 记录边界 | 记录边界 | 记录系统实际行为；重新打开后恢复，不作为必达场景 |

另做即时故障回归：关闭响铃、撤回授权、连续长按、重复可靠事件、确认丢失、配置保存超时及系统停止响铃。用户禁用或未授权时应终结该请求，不持续重试；启用后由新按键触发。确认丢失后重复通知应补确认，不能在用户已停止后重新响铃。保留原远程拍照回归，确保重连不补拍。

## 平台依据

- [Apple：Core Bluetooth 后台处理与状态保存/恢复](https://developer.apple.com/library/archive/documentation/NetworkingInternetWeb/Conceptual/CoreBluetooth_concepts/CoreBluetoothBackgroundProcessingForIOSApps/PerformingTasksWhileYourAppIsInTheBackground.html)
- [Apple：Core Bluetooth 状态恢复重新启动条件（QA1962）](https://developer.apple.com/library/archive/qa/qa1962/_index.html)
- [Apple：使用 AlarmKit 安排闹钟](https://developer.apple.com/documentation/alarmkit/scheduling-an-alarm-with-alarmkit)

社区经验可用于设计实验，但不能替代当前 iOS、实际固件与目标机型的长测结果。
