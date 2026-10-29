# 照片降采样实验与 App 接入

本次按“照片的细节和轮廓”为主设计。2026-10-23 在 Windows 上完成 Python 模型、C 核心编译与测试，并修改 Objective-C 调用链；没有编译或运行 iOS App。

**当前已启用激进 DPID 采样**：本项目 3/4 号 HINK 六色屏的 BLE 照片路径，改为在原图降采样时进行对比度自适应加权，参数为指数 1.5、最大权重比 32、自适应混合 90%，关闭后续 L* 锐化。见 [DPID 实现说明](DPID_implementation.md) 与 `results/dpid240/index.html`。

此前的 HINK-T0154A10-A2 240×240 六色、Lab/XYZ 与边缘扩散实现见 [硬件实现说明](HINK_T0154A10_A2_implementation.md)。预览与上传仍来自同一六色索引图，纯 NFC 暂留原路径。下文是保留的通用 Lanczos 缩图记录，不是当前 HINK 的 DPID 采样算法。

## 旧流程复现的范围

`resample.py::legacy_resize` 模拟 `SLImageClipController → UIView+SLImage → MainViewController` 的几何流程：

1. 原图重绘到 `imageView` 的点尺寸乘手机屏幕倍率。
2. 按选择区域裁剪。源码的全图快捷路径不减高度；部分裁剪路径会将高度减 1 个截图像素。
3. 再次重绘为设备像素尺寸。

UIKit/Core Graphics 默认插值核没有在源码里指定，Windows 无法采集它的真实输出。因此分别保存双线性、双三次、Lanczos 三种插值假设，**不能将其中任意一列称为 iPhone 的像素级复现**。模型还简化了 UIView 浮点边界取整。默认视图宽 350 点、截图倍率 2，可通过参数更换。图片存储入口原本没有截图步骤，故这些旧流程列特指普通刷图入口。

本实验比较发生在 SDK 抖点、色阶转换之前；未模拟闭源 SDK，也未将边缘梯度解释为“信息保留率”。

## 新方案

1. 裁剪坐标直接映射到原始 CGImage，保留原始像素。方向和用户 90° 旋转通过元数据组合，不生成界面截图。
2. 统一将输入转换为白底、不透明、8 位 sRGB RGBA。
3. 使用可分离 Lanczos-3。缩小时按缩放比例扩大滤波支持域，进行抗混叠；每次一维过滤都将结果限制在目标像素覆盖区域的源值范围内，抑制振铃。
4. 在目标分辨率上做受限亮度增强：3×3 高斯近似核 `[1,2,1]²/16`，强度 0.65。细节量 2～8/255、邻域范围 8～32/255 使用平滑门控；单次调整上限 `min(8, 0.12 × 邻域范围)`，再限制到邻域亮度范围和 RGB 色域。三个通道增加相同的量。
5. 同尺寸和纯放大操作不锐化。增强只作用于缩小后的照片输入，不能用于 SDK 输出的离散调色板图。

C 核心内部采用 RGBA，返回给 SDK 的 UIImage 则转回 UIKit 常用的 BGRA 字节布局，减少对既有像素取值约定的影响。

这里保持 sRGB 编码空间的细线覆盖对比度，不额外引入线性光重采样。小于一个目标像素的结构仍受输出分辨率限制，无法全部恢复。

## App 改动

新增 `ios/BrushSDK/Core/Support/ImageDither/` 中的四个文件：

- `XTPhotoResampleCore.h/.c`：跨平台的滤波、亮度增强、方向/裁剪映射；Windows 测试编译的正是这个文件。
- `XTPhotoResampler.h/.m`：UIKit/CGImage 输入输出、裁剪、等比填充和圆屏处理。

接入位置：

- `SLImageClipController.m`：将裁剪框换算为原图归一化坐标，通过 CGImage 裁剪，替换控件截图。
- `MainViewController.m`：在后台准备设备分辨率图；400×400 圆屏还从原图准备旋转后的输入。失败时保留错误提示。
- `BrushScreenController.h/.m`：复用已经准备的圆屏输入；保留既有 69.7°、399/400 裁剪的几何对齐，避免先降到 400 再旋转，以及切换算法时重复锐化。
- `XTImageStorageViewController.m`：自动居中裁剪后调用同一重采样器。

项目使用 `PBXFileSystemSynchronizedRootGroup`，新增 `.c/.m` 位于 App 同步源码目录，无需向传统 Sources 列表手工追加文件。Python 工具、输出和本地编译器放在同步目录之外。

## 本地运行

在 `<checkout>/ink-screen-app` 用 PowerShell 执行：

```powershell
python tools/image_resampling/experiment.py
python tools/image_resampling/experiment.py --crop 0.1 0.2 0.6 0.6 --output tools/image_resampling/results/partial_crop
python tools/image_resampling/experiment.py --input 'D:/photos/example.jpg' --view-width 350 --screen-scale 3 --output tools/image_resampling/results/my_photo
python tools/image_resampling/test_native.py
python tools/image_resampling/make_preview.py
```

依赖见 `requirements.txt`。当前测试使用本机 scikit-image 内置样例 astronaut、chelsea、coffee、motorcycle_left，以及代码生成的细线图。无需网络获取样例。字体使用本机 Arial。

`test_native.py` 默认调用工具目录的 `.runtime/ziglang/zig.exe cc`，可在另一台 Windows 机器安装到相同的局部目录：

```powershell
python -m pip install --target tools/image_resampling/.runtime ziglang==0.13.0
```

这个编译器只用于 Windows 本地测试，不是 App 依赖。`.runtime/`、`.build/`、`__pycache__/` 已加入工具目录的忽略规则。

## 结果与验证

- `results/index.html`：5 个样例 × 2 个目标尺寸，共 10 组；每组有三种旧插值假设、直接 Lanczos、新照片方案。
- `results/partial_crop/index.html`：另外 10 组部分区域裁剪对照。
- `results/metrics.json`：基于直接 Lanczos 输出选定边缘位置，计算 Sobel 梯度，仅作局部对比度诊断。
- `results/native_tests.json`：21 项检查通过，包含全部 8 种 EXIF 方向 × 4 种用户旋转（32 种组合）、所有 6 种设备尺寸、单像素轴、缩小/放大、纯色不变、灰阶阶跃无过冲、棋盘格抗混叠、低幅噪声不增强、增强上限、RGB 同量调整、行填充和无效参数。
- 这些照片样例的 C 输出与 Python 新方案输出逐像素一致；测试允许的浮点舍入容差为 1/255。
- 本机 1200 万像素 → 400×400 的单次核心处理约 0.22～0.25 秒（含 Python 测试缓冲区准备），不代表 iPhone 性能。

已目视检查猫毛/胡须、摩托车结构、细线和斜边的局部对照。锐化是保守默认值，最终视觉效果需要结合设备调色板和真实照片确认。

## iOS 上仍需验证

Windows 检查覆盖可移植的 C 像素处理和裁剪方向数学；UIKit 包装层只做了静态检查。Mac/iPhone 验证应覆盖编译、相册 EXIF/镜像/透明及广色域输入、裁剪拖动和缩放、圆屏实际旋转位置、连续切换算法、SDK 预览/写屏结果，以及大照片的峰值内存和耗时。

不能用本地 C 编译成功代替 iOS 构建成功，也不能用这里的 RGB 对比图代替墨水屏实测。

## 网上照片对照（2026-10-23）

- `fetch_picsum_photos.py`：通过 Lorem Picsum 元数据取得作者、Unsplash 来源与目录原生尺寸，保存 JPEG、SHA256 和下载记录到 `web_sources/`。图片交付服务可能重编码，不声称与摄影师原始文件逐字节相同。
- `compare_web_photos.py`：执行 App 实际 C 核心，同一原生尺寸居中正方形裁剪 → 240×240；输出 RGB、最终六色色码、标称预览、对照 PNG 和内嵌图片的 HTML。
- `results/web_photos/index.html`：网上新照片的完整对照。RGB 行隔离采样差异；六色行比较 Lanczos＋0.8 L* 后增强与激进 DPID＋关闭后增强的完整流程。
- `results/web_photos/manifest.json`：输入尺寸、裁剪、色彩空间处理、来源和文件哈希。无 ICC 的输入按 sRGB 处理。

```powershell
python tools/image_resampling/fetch_picsum_photos.py
python tools/image_resampling/compare_web_photos.py
```

六色预览不是实屏照片；像素对比不能证明恢复了原图信息。DPID 也可能加粗结构、强化噪点并增加混叠。网上照片的许可未额外核验，来源信息不构成再分发授权。

## DPID 二次锐化开关对照（2026-10-24）

运行 `python tools/image_resampling/compare_post_sharpen.py`，在同一批已保存的 DPID 240×240 RGB 输入上，以 App 实际 C 核心比较 L* 后增强强度 0 与 0.8。其余量化、色域与扩散参数相同，不修改 App 设置。

`results/dpid_post_sharpen/index.html` 包含 8 张照片的六色、量化前连续色、局部放大与原位手动切换。`metrics.json` 记录每张输入哈希及 L* 改变量；关闭分支必须逐像素等于已查看的当前 App 对照，a*/b* 必须保持不变，单像素 L* 改动不超过 2。六色误差扩散的色点重排不能解释为信息保留率。
