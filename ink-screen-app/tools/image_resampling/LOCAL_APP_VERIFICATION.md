# App 本地接入与验证

2026-10-24 在 Windows 上完成的验证记录。本记录产生于本地验证阶段；本目录随后整理为独立的仓库源码包。

## App 当前行为

HINK-T0154A10-A2 240×240 六色屏（规格 3/4）的普通 BLE 刷图使用已对照的激进 DPID：指数 1.5、范围权重比上限 32、自适应混合 90%。NFC 唤醒的普通 BLE 使用同一路径。

- 直接导入：`MainViewController.imageClippingComplete:` → `XTPhotoResampler.resizeImageUsingDPID:toSize:`。
- 图片存储：`XTImageStorageViewController.prepareSelectedImage:` → `XTPhotoResampler.aspectFillImageUsingDPID:toSize:`。
- 裁剪：`SLImageClipController` 提取原生像素区域，再执行降采样，避免提前缩成屏幕截图。
- 六色转换：`XTInkPhotoProcessor` 使用同一硬件色板与边缘扩散，关闭后续 L* 锐化。预览与上传标记来自同一色码图；上传取精确 RGB 标记，不取标称实物颜色预览。

以上接入已在前序算法实现中落入 App 源码，本次重新核对并验证。未将其他面板或纯 NFC 传输切换到这个面板专用流程。Xcode 工程使用同步文件夹，新增 C/Objective-C 文件位于目标的 `BrushSDK` 同步根目录内，未被成员例外排除。

## 本次验证

重新编译并运行 App 实际可移植 C 核心，合计 67 项检查通过：

| 检查组 | 通过数 | 覆盖内容 |
|---|---:|---|
| `test_native.py` | 21 | 原有采样回归、8 种 EXIF 方向与 4 种用户旋转、各设备尺寸、边界与缓冲区 |
| `test_hink.py` | 16 | 硬件量化与独立模型一致性、六色色码、预览标记、翻转、色域投影 |
| `test_dpid.py` | 22 | 非整数缩放、平坦区、低幅噪声、源像素极值、非法参数、完整六色链路 |
| `verify_web_photos.py` | 8 | 保存的 8 张网上照片：当前 C 源码的 RGB、六色色码、标称预览和上传标记均与已查看的对照逐像素一致 |

`results/local_app_verification.json` 记录检查数量及相关 App 源码 SHA256，`results/web_photos/verification.json` 记录逐照片结果。最后一组只校验现有对照，不重新生成期望图片；没有校准实屏色彩，也没有把像素一致解释为画质分数。

```powershell
$env:OPENBLAS_NUM_THREADS='1'
python tools/image_resampling/test_native.py
python tools/image_resampling/test_hink.py
python tools/image_resampling/test_dpid.py
python tools/image_resampling/verify_web_photos.py
```

## 尚未执行

本机是 Windows，没有运行 iOS 构建、UIKit 运行时或蓝牙实屏测试。C 核心通过不能替代这三项验证。后续 Mac/iPhone 验收应覆盖直接导入、拖动裁剪、EXIF/镜像照片、图片存储、广色域/透明输入及实际刷屏的色序、方向、耗时与内存。
