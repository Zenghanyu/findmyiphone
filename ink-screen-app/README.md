# 墨水屏刷图 App / BrushSDK

基于 BrushSDK 2026.8.21 的独立 iOS App 源码，包含蓝牙/NFC 刷图、图片裁剪与图片存储等功能。它与仓库现有 `ios/EasyFind` 工程分开，开发入口为 `ios/BrushSDK.xcodeproj`。

## 当前照片处理

HINK-T0154A10-A2 的 240×240 六色屏（规格 3/4）普通 BLE 照片路径使用激进 DPID 风格降采样：

`原始像素裁剪 → 不透明 sRGB → DPID 240×240 → 面板色域映射 → 六色量化与边缘扩散 → 预览及上传`

- 直接刷图和图片存储共用这套采样。DPID 参数为指数 1.5、权重比上限 32、自适应混合 90%。
- 当前关闭六色量化前的二次 L* 锐化。已提供开关对照脚本，开启与否尚待用户决定，本源码包保留已验证的关闭状态。
- 预览颜色与上传 RGB 标记由同一索引图生成；上传使用精确色码标记，避免把标称屏幕颜色当作传输色码。
- 型号和传输方式有显式门控，其他面板、纯 NFC 与 NFC 供电 BLE 仍走原有路径；NFC 唤醒的普通 BLE 使用普通 BLE 路径。

该 DPID 是逆双边加权思路的面积覆盖工程变体；它可能提高细线及纹理的可见度，也可能加粗结构、强化噪点和增加混叠。面板 Lab 暂按 D65/2° 解释，生成的六色图是标称预览，不是实屏校准结果。

## 目录

```text
ink-screen-app/
├── ios/
│   ├── BrushSDK.xcodeproj/       Xcode 工程及共享 BrushSDK scheme
│   ├── BrushSDK/                 App 源码、UI 资源与 SDK 依赖
│   ├── en.lproj/
│   └── zh-Hans.lproj/
├── tools/image_resampling/      Python 模型、对照脚本与 C 回归工具
│   └── results/                 已记录的 JSON 测试结果与照片来源元数据
├── docs/BrushSDK-upstream.html  随原工程提供的 SDK 说明
└── PACKAGE_MANIFEST.json        iOS 工程与依赖文件的 SHA256 清单
```

保留 `XTDitherBleProtocol.xcframework`（设备和模拟器切片）、`libFMCompress.a` 以及工程资源。未打入 Xcode 用户状态、Python/编译器运行时、编译产物、下载照片或生成的图片/HTML 报告。`tools/image_resampling/results/` 中的 JSON 是验证记录和来源信息；可运行脚本重新生成本地图片报告。

## 在 Mac 上打开

1. 打开 `ios/BrushSDK.xcodeproj`，选择共享 `BrushSDK` scheme。工程采用 Xcode 同步文件夹格式，需要支持该格式的 Xcode 16+；源码的具体 SDK 兼容性仍需在实际 Xcode 环境验证。
2. 真机运行时在 Signing & Capabilities 选择自己的 Team、可用的 Bundle Identifier，并配置设备所需的 NFC/Bluetooth 能力。源码包移除了原开发者的 Team 绑定，没有签名私钥或证书。
3. 使用支持蓝牙/NFC 的 iPhone 验证真实传输。模拟器不能代替 NFC 或实屏测试。

本机为 Windows，交付物是源码工程，未编译 iOS App，也未生成可安装 IPA。共享 scheme 和工程结构经过静态检查，不代表 iOS 构建成功。

## Windows 本地算法回归

从本文件所在目录运行，使用 Python 3.11+：

```powershell
python -m venv .venv
.venv/Scripts/Activate.ps1
python -m pip install -r tools/image_resampling/requirements.txt
python -m pip install --target tools/image_resampling/.runtime ziglang==0.13.0
$env:OPENBLAS_NUM_THREADS='1'
python tools/image_resampling/test_native.py
python tools/image_resampling/test_hink.py
python tools/image_resampling/test_dpid.py
```

可设置 `XT_ZIG` 指向已有的 `zig.exe`，避免重复安装。上述工具直接编译当前工程内的 C 核心；不是 iOS 编译，也不执行 UIKit。

已在原本地工程通过 59 项 C 核心检查，并用 8 张网上照片核对 RGB、六色色码、标称预览及上传标记与对照完全一致。本次整理后另从此目录运行全部 59 项 C 检查，结果见 [源码包验证记录](tools/image_resampling/results/package_verification.json)。

网上照片实验不作为源码包附件，需联网重新生成：

```powershell
python tools/image_resampling/fetch_picsum_photos.py
python tools/image_resampling/compare_web_photos.py
python tools/image_resampling/verify_web_photos.py
python tools/image_resampling/compare_post_sharpen.py
```

二次锐化对照保存在本地 `tools/image_resampling/results/dpid_post_sharpen/index.html`。它在相同 DPID 输入上比较 L* 强度 0 与 0.8，仅生成报告，不修改 App。

## 实现与待验证范围

- [DPID 算法及接入](tools/image_resampling/DPID_implementation.md)
- [HINK 硬件转换](tools/image_resampling/HINK_T0154A10_A2_implementation.md)
- [本地验证与范围](tools/image_resampling/LOCAL_APP_VERIFICATION.md)

仍需 Mac/iPhone 完成 iOS 构建、UIKit 输入方向与颜色管理、相册/裁剪交互、图片存储、真实 BLE 刷图、色序/方向及峰值内存和耗时验收。
