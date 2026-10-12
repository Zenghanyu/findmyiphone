import XCTest
import AVFoundation

/// 模拟器 Mock 模式 UI 测试：用 `-uiMock` 启动参数驱动，覆盖全部页面状态。
/// 真机构建不含 Mock 代码（`#if targetEnvironment(simulator)`），本测试仅跑模拟器。
final class EasyFindUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func makeApp(arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiMock"] + arguments
        return app
    }

    private func attach(_ screenshot: XCUIScreenshot, _ name: String) {
        let att = XCTAttachment(screenshot: screenshot)
        att.name = name
        att.lifetime = .keepAlways
        add(att)

        // 同时落盘到宿主机，便于直接查看（XCUITest runner 运行在 macOS 上）。
        let dir = URL(fileURLWithPath: "/tmp/easyfind_ui")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent(name + ".png")
        try? screenshot.pngRepresentation.write(to: file)
    }

    /// 首页 idle + 扫描 + Tag 清单弹层 + 进入测距（寻找态）。
    func testIdleScanListAndRanging() throws {
        let app = makeApp(arguments: [])
        app.launch()

        let scanButton = app.buttons["扫描标签"]
        XCTAssertTrue(scanButton.waitForExistence(timeout: 10), "首页应显示「扫描标签」按钮")
        attach(XCUIScreen.main.screenshot(), "01-home-idle")

        scanButton.tap()
        // 等 3 个 Mock 标签依次出现（0.6s/个 + 余量）
        XCTAssertTrue(app.staticTexts["车钥匙"].waitForExistence(timeout: 5), "应发现 Mock 标签「车钥匙」")
        XCTAssertTrue(app.staticTexts["背包"].waitForExistence(timeout: 3), "应发现 Mock 标签「背包」")
        XCTAssertTrue(app.staticTexts["雨伞"].waitForExistence(timeout: 3), "应发现 Mock 标签「雨伞」")
        XCTAssertTrue(app.staticTexts["发现 3 个标签 · 点击开始测距"].exists, "清单标题应显示 3 个标签")
        attach(XCUIScreen.main.screenshot(), "02-tag-list-panel")

        app.staticTexts["车钥匙"].tap()
        // 面板应收起（不再遮挡按钮），随后进入测距
        XCTAssertTrue(app.buttons["结束"].waitForExistence(timeout: 3), "点 tag 后面板应收起并显示「结束」按钮")
        XCTAssertFalse(app.staticTexts["发现 3 个标签 · 点击开始测距"].exists, "点 tag 后 Tag 清单应收起")
        sleep(3)
        attach(XCUIScreen.main.screenshot(), "03-ranging-finding")

        // 结束测距回到 idle
        app.buttons["结束"].tap()
        sleep(1)
        attach(XCUIScreen.main.screenshot(), "04-back-to-idle")
    }

    /// 测距全剧本：方向丢失 → 恢复 → 就在附近 → 响铃。
    func testRangingStates() throws {
        let app = makeApp(arguments: [])
        app.launch()

        let scanButton = app.buttons["扫描标签"]
        XCTAssertTrue(scanButton.waitForExistence(timeout: 10))
        scanButton.tap()
        XCTAssertTrue(app.staticTexts["车钥匙"].waitForExistence(timeout: 5))
        app.staticTexts["车钥匙"].tap()

        // tick 21-32（约 5.25-8s）：方向丢失
        sleep(6)
        attach(XCUIScreen.main.screenshot(), "05-ranging-direction-lost")

        // tick 41+（约 10.25s+）：就在附近
        sleep(5)
        attach(XCUIScreen.main.screenshot(), "06-ranging-nearby")

        // 响铃中
        let soundButton = app.buttons["响铃"]
        if soundButton.exists {
            soundButton.tap()
            sleep(1)
            attach(XCUIScreen.main.screenshot(), "07-sound-playing")
        }
    }

    /// 异常：蓝牙关闭错误页。
    func testBluetoothOffError() throws {
        let app = makeApp(arguments: ["-uiMockScenario", "bluetoothOff"])
        app.launch()

        let retry = app.buttons["重试"]
        XCTAssertTrue(retry.waitForExistence(timeout: 10), "应显示错误页与「重试」按钮")
        XCTAssertTrue(app.staticTexts["蓝牙已关闭，请在控制中心开启蓝牙"].exists, "应显示蓝牙关闭提示")
        attach(XCUIScreen.main.screenshot(), "08-error-bluetooth-off")
    }

    /// 异常：蓝牙权限拒绝错误页。
    func testPermissionDeniedError() throws {
        let app = makeApp(arguments: ["-uiMockScenario", "permissionDenied"])
        app.launch()

        let retry = app.buttons["重试"]
        XCTAssertTrue(retry.waitForExistence(timeout: 10), "应显示错误页与「重试」按钮")
        XCTAssertTrue(app.staticTexts["蓝牙权限未开启，请在系统设置中允许 EasyFind 使用蓝牙"].exists, "应显示权限提示")
        attach(XCUIScreen.main.screenshot(), "09-error-permission-denied")
    }

    /// 异常：测距会话建立失败。
    func testRangingFailure() throws {
        let app = makeApp(arguments: ["-uiMockScenario", "rangingFailure"])
        app.launch()

        let scanButton = app.buttons["扫描标签"]
        XCTAssertTrue(scanButton.waitForExistence(timeout: 10))
        scanButton.tap()
        XCTAssertTrue(app.staticTexts["车钥匙"].waitForExistence(timeout: 5))
        app.staticTexts["车钥匙"].tap()

        XCTAssertTrue(app.staticTexts["UWB 会话建立失败（模拟）"].waitForExistence(timeout: 5), "应显示失败提示")
        attach(XCUIScreen.main.screenshot(), "10-error-ranging-failure")
    }
}

// MARK: - 演示视频（自动演示模式下连续抓帧，合成 mp4）

extension EasyFindUITests {
    /// 在 `-uiMockAutoplay` 下抓 45s 帧并合成为 `/tmp/easyfind_demo.mp4`，
    /// 用于在模拟器上查看完整动画流程（扫描→弹层→测距→方向丢失→就近→回 idle 循环）。
    func testDemoVideo() throws {
        let app = makeApp(arguments: ["-uiMockAutoplay"])
        app.launch()

        let dir = URL(fileURLWithPath: "/tmp/easyfind_demo_frames")
        try? FileManager.default.removeItem(at: dir)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        var count = 0
        let deadline = Date().addingTimeInterval(45)
        while Date() < deadline {
            let img = XCUIScreen.main.screenshot().image
            let f = dir.appendingPathComponent(String(format: "%04d.png", count))
            try? img.pngData()?.write(to: f)
            count += 1
            Thread.sleep(forTimeInterval: 0.18)
        }
        XCTAssertGreaterThan(count, 40, "应抓到足够帧数")

        // AVFoundation 合成 mp4（帧率 5fps，播放 45s 的抓帧内容约 18s）
        let first = UIImage(contentsOfFile: dir.appendingPathComponent("0000.png").path)!
        let w = Int(first.size.width), h = Int(first.size.height)
        let out = URL(fileURLWithPath: "/tmp/easyfind_demo.mp4")
        try? FileManager.default.removeItem(at: out)

        let writer = try AVAssetWriter(outputURL: out, fileType: .mp4)
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: w,
            AVVideoHeightKey: h,
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
                kCVPixelBufferWidthKey as String: w,
                kCVPixelBufferHeightKey as String: h,
            ])
        input.expectsMediaDataInRealTime = false
        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        let timescale: Int32 = 5
        for i in 0..<count {
            while !input.isReadyForMoreMediaData { usleep(2000) }
            let f = dir.appendingPathComponent(String(format: "%04d.png", i))
            guard let cg = UIImage(contentsOfFile: f.path)?.cgImage else { continue }
            var pb: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &pb)
            guard let pix = pb else { continue }
            CVPixelBufferLockBaseAddress(pix, [])
            let ctx = CGContext(
                data: CVPixelBufferGetBaseAddress(pix),
                width: w, height: h,
                bitsPerComponent: 8,
                bytesPerRow: CVPixelBufferGetBytesPerRow(pix),
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)!
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
            CVPixelBufferUnlockBaseAddress(pix, [])
            adaptor.append(pix, withPresentationTime: CMTime(value: CMTimeValue(i), timescale: timescale))
        }
        input.markAsFinished()
        let sem = DispatchSemaphore(value: 0)
        writer.finishWriting { sem.signal() }
        sem.wait()
        XCTAssertEqual(writer.status, .completed, "视频合成失败: \(writer.error?.localizedDescription ?? "?")")
    }
}
