import XCTest

final class SelfieStickUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    private func launch(reset: Bool = true, failure: Bool = false, authorized: Bool = true, controls: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiMock", "-selfieDemo", authorized ? "-phoneFindAuthorized" : "-phoneFindUnauthorized"]
        if controls { app.launchArguments.append("-featureTestControls") }
        if reset { app.launchArguments.append("-selfieReset") }
        if failure { app.launchArguments.append("-selfieSaveFailure") }
        app.launch()
        return app
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication, up: Bool) {
        for _ in 0..<6 {
            if element.isHittable { return }
            if up { app.swipeUp() } else { app.swipeDown() }
        }
        XCTAssertTrue(element.isHittable)
    }
    private func waitForText(_ text: String, element: XCUIElement) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS %@", text), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 8), .completed)
    }
    private func open(_ identifier: String, in app: XCUIApplication) {
        XCTAssertTrue(app.buttons[identifier].waitForExistence(timeout: 5))
        app.buttons[identifier].tap()
        let status = app.staticTexts["selfie.connectionStatus"]
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        waitForText("已连接", element: status)
    }
    private func selectAndSave(_ seconds: Int, app: XCUIApplication) {
        let preset = app.buttons["selfie.delay.\(seconds)"]
        reveal(preset, in: app, up: false)
        preset.tap()
        let save = app.buttons["selfie.save"]
        XCTAssertTrue(save.isHittable, "保存按钮应固定在底部")
        XCTAssertTrue(save.isEnabled)
        save.tap()
        waitForText("已保存", element: app.staticTexts["selfie.saveMessage"])
        waitForText("\(seconds) 秒", element: app.staticTexts["selfie.savedDelay"])
    }
    private func screenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testFigmaNavigationUsesSharedSystemConnectedDevice() {
        let app = launch(controls: false)
        XCTAssertTrue(app.tabBars.buttons["查找"].exists)
        XCTAssertTrue(app.tabBars.buttons["功能"].exists)
        XCTAssertTrue(app.buttons["features.remotePhoto"].waitForExistence(timeout: 5))
        screenshot("功能入口")
        XCTAssertFalse(app.buttons["搜索自拍杆"].exists)
        XCTAssertFalse(app.buttons["selfie.demoFindPhone"].exists)
        open("features.remotePhoto", in: app)
        XCTAssertFalse(app.tabBars.buttons["功能"].isHittable)
        screenshot("远程拍照")
        app.buttons["features.back"].tap()
        open("features.findPhone", in: app)
        screenshot("查找手机-提醒关闭")
        app.buttons["features.back"].tap()
        XCTAssertTrue(app.buttons["features.remotePhoto"].exists)
    }

    func testSavedDelaySurvivesNavigationAndRelaunch() {
        let app = launch()
        open("features.remotePhoto", in: app)
        waitForText("3 秒", element: app.staticTexts["selfie.savedDelay"])
        app.buttons["selfie.delay.5"].tap()
        XCTAssertTrue(app.staticTexts["selfie.savedDelay"].label.contains("3 秒"))
        selectAndSave(5, app: app)
        app.buttons["features.back"].tap()
        open("features.remotePhoto", in: app)
        XCTAssertEqual(app.staticTexts["selfie.selectedDelay"].label, "5 秒")
        app.terminate()
        app.launchArguments.removeAll { $0 == "-selfieReset" }
        app.launch()
        open("features.remotePhoto", in: app)
        waitForText("5 秒", element: app.staticTexts["selfie.savedDelay"])
        XCTAssertEqual(app.staticTexts["selfie.selectedDelay"].label, "5 秒")
    }

    func testDeviceCountdownUsesSavedDelayAndCanBeCancelled() {
        let app = launch()
        open("features.remotePhoto", in: app)
        selectAndSave(10, app: app)
        app.buttons["selfie.delay.0"].tap()
        let press = app.buttons["selfie.demoPress"]
        reveal(press, in: app, up: true)
        press.tap()
        waitForText("设备倒计时", element: app.staticTexts["selfie.demoStatus"])
        let remaining = Int(app.staticTexts["selfie.countdown"].label) ?? 0
        XCTAssertTrue((1...10).contains(remaining))
        let cancel = app.buttons["selfie.cancelCountdown"]
        reveal(cancel, in: app, up: true)
        cancel.tap()
        waitForText("倒计时已取消", element: app.staticTexts["selfie.demoStatus"])
        selectAndSave(0, app: app)
        reveal(press, in: app, up: true)
        press.tap()
        waitForText("快门已触发（模拟） · 第 1 次", element: app.staticTexts["selfie.demoStatus"])
    }

    func testReverseFindPhoneCanStopAndRingAgain() {
        let app = launch()
        open("features.findPhone", in: app)
        let press = app.buttons["selfie.demoFindPhone"]
        reveal(press, in: app, up: true)
        press.tap()
        waitForText("手机正在提醒", element: app.staticTexts["selfie.phoneFindStatus"])
        let stop = app.buttons["selfie.phoneFindAction"]
        reveal(stop, in: app, up: false)
        screenshot("查找手机-提醒开启")
        stop.tap()
        waitForText("已找到手机", element: app.staticTexts["selfie.phoneFindStatus"])
        XCTAssertFalse(stop.isEnabled)
        reveal(press, in: app, up: true)
        press.tap()
        waitForText("手机正在提醒", element: app.staticTexts["selfie.phoneFindStatus"])
    }

    func testPhoneSoundPreferenceRequiresSaveAndPersists() {
        let app = launch()
        open("features.findPhone", in: app)
        let sound = app.buttons["phoneFind.soundEnabled"]
        XCTAssertEqual(sound.value as? String, "开启")
        sound.tap()
        app.buttons["features.back"].tap()
        open("features.findPhone", in: app)
        XCTAssertEqual(sound.value as? String, "开启", "未保存的选项不应生效")
        sound.tap()
        app.buttons["phoneFind.save"].tap()
        waitForText("设置已保存", element: app.staticTexts["phoneFind.saveMessage"])
        app.terminate()
        app.launchArguments.removeAll { $0 == "-selfieReset" }
        app.launch()
        open("features.findPhone", in: app)
        XCTAssertEqual(sound.value as? String, "关闭")
    }

    func testLostFindAcknowledgementDoesNotRingAgainAfterStop() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiMock", "-selfieDemo", "-phoneFindAuthorized", "-featureTestControls",
                               "-selfieReset", "-selfieDropFirstFindAck"]
        app.launch()
        open("features.findPhone", in: app)
        let press = app.buttons["selfie.demoFindPhone"]
        reveal(press, in: app, up: true)
        press.tap()
        waitForText("手机正在提醒", element: app.staticTexts["selfie.phoneFindStatus"])
        let stop = app.buttons["selfie.phoneFindAction"]
        reveal(stop, in: app, up: false)
        stop.tap()
        waitForText("已找到手机", element: app.staticTexts["selfie.phoneFindStatus"])
        // Explicitly replay the same physical request after stop; automation
        // speed must not determine whether the 2-second retry came before stop.
        let repeatRequest = app.buttons["selfie.demoRepeatFindPhone"]
        reveal(repeatRequest, in: app, up: true)
        repeatRequest.tap()
        let rerang = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS %@", "手机正在提醒"),
                                               object: app.staticTexts["selfie.phoneFindStatus"])
        XCTAssertEqual(XCTWaiter.wait(for: [rerang], timeout: 4), .timedOut)
        XCTAssertFalse(stop.isEnabled)
    }

    func testConfigurationReadFailureKeepsPhoneFindListening() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiMock", "-selfieDemo", "-phoneFindAuthorized", "-featureTestControls",
                               "-selfieReset", "-selfieConfigReadFailure"]
        app.launch()
        XCTAssertTrue(app.buttons["features.findPhone"].waitForExistence(timeout: 5))
        app.buttons["features.findPhone"].tap()
        waitForText("未连接", element: app.staticTexts["selfie.connectionStatus"])
        let press = app.buttons["selfie.demoFindPhone"]
        reveal(press, in: app, up: true)
        press.tap()
        waitForText("手机正在提醒", element: app.staticTexts["selfie.phoneFindStatus"])
    }

    func testUnauthorizedDesignDisablesSoundAndSave() {
        let app = launch(authorized: false, controls: false)
        open("features.findPhone", in: app)
        if #available(iOS 26.0, *) {
            waitForText("开启系统闹钟，查找手机", element: app.staticTexts["selfie.phoneFindStatus"])
        } else {
            waitForText("开启通知，接收提醒", element: app.staticTexts["selfie.phoneFindStatus"])
        }
        XCTAssertTrue(app.buttons["selfie.phoneFindAction"].isEnabled)
        XCTAssertFalse(app.buttons["phoneFind.soundEnabled"].isEnabled)
        XCTAssertFalse(app.buttons["phoneFind.save"].isEnabled)
        screenshot("查找手机-待授权")
    }

    func testDisabledSoundDoesNotStartSystemAlarm() {
        guard #available(iOS 26.0, *) else { return }
        let app = launch()
        open("features.findPhone", in: app)
        app.buttons["phoneFind.soundEnabled"].tap()
        app.buttons["phoneFind.save"].tap()
        let press = app.buttons["selfie.demoFindPhone"]
        reveal(press, in: app, up: true)
        press.tap()
        waitForText("已找到手机", element: app.staticTexts["selfie.phoneFindStatus"])
        XCTAssertFalse(app.buttons["selfie.phoneFindAction"].isEnabled)
    }

    func testRejectedSaveNeverAppearsAsSaved() {
        let app = launch(failure: true)
        open("features.remotePhoto", in: app)
        app.buttons["selfie.delay.5"].tap()
        app.buttons["selfie.save"].tap()
        waitForText("设备保存失败", element: app.staticTexts["selfie.saveMessage"])
        XCTAssertTrue(app.staticTexts["selfie.savedDelay"].label.contains("3 秒"))
        XCTAssertEqual(app.staticTexts["selfie.selectedDelay"].label, "5 秒")
        XCTAssertTrue(app.buttons["selfie.save"].isEnabled)
    }
}
