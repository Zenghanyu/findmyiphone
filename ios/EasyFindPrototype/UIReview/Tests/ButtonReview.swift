import XCTest

final class ButtonReview: XCTestCase {
    let app = XCUIApplication(bundleIdentifier: "com.easyfind.companion")

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launch()
        XCTAssertTrue(app.buttons["设备标签"].waitForExistence(timeout: 10))
    }

    func shot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func back() {
        let bar = app.navigationBars.firstMatch
        bar.buttons.element(boundBy: 0).tap()
    }

    func testSwitchStatesAndRepeatedTaps() throws {
        app.buttons["提醒标签"].tap()
        let hourly = app.switches["自动报时"].firstMatch
        XCTAssertTrue(hourly.waitForExistence(timeout: 3))
        let original = hourly.value as? String
        XCTAssertTrue(original == "0" || original == "1")
        if original != "1" { hourly.tap() }
        XCTAssertEqual(hourly.value as? String, "1")
        shot("toggle-on")
        hourly.tap()
        XCTAssertEqual(hourly.value as? String, "0")
        shot("toggle-off")
        let switchHit = hourly.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5))
        switchHit.tap()
        XCTAssertEqual(hourly.value as? String, "1")
        switchHit.tap()
        XCTAssertEqual(hourly.value as? String, "0", "Separate physical taps must each update the state")
        let wide = hourly.frame.width > 100
        let left = hourly.coordinate(withNormalizedOffset: CGVector(dx: wide ? 0.85 : 0.15, dy: 0.5))
        let right = hourly.coordinate(withNormalizedOffset: CGVector(dx: wide ? 0.97 : 0.85, dy: 0.5))
        left.press(forDuration: 0.05, thenDragTo: right)
        XCTAssertEqual(hourly.value as? String, "1", "Dragging right should turn the switch on")
        right.press(forDuration: 0.05, thenDragTo: left)
        XCTAssertEqual(hourly.value as? String, "0", "Dragging left should turn the switch off")
        if original == "1" { hourly.tap() }

        app.buttons["设备标签"].tap()
        app.buttons["找手机入口"].tap()
        let phone = app.switches.firstMatch
        XCTAssertTrue(phone.waitForExistence(timeout: 3))
        let phoneOriginal = phone.value as? String
        phone.tap()
        XCTAssertNotEqual(phone.value as? String, phoneOriginal)
        phone.tap()
        XCTAssertEqual(phone.value as? String, phoneOriginal)
        back()
        app.buttons["提醒标签"].tap()
    }

    func testButtonHierarchyAndNavigation() throws {
        app.buttons["设备标签"].tap()
        let camera = app.buttons["遥控拍照入口"]
        XCTAssertTrue(camera.waitForExistence(timeout: 3))
        shot("device-after")

        camera.tap()
        XCTAssertTrue(app.buttons["延时10秒"].waitForExistence(timeout: 3))
        let original = [0, 3, 5, 10].first { app.buttons["延时\($0)秒"].isSelected }
        let draft = original == 10 ? 3 : 10
        let draftButton = app.buttons["延时\(draft)秒"]
        draftButton.tap()
        shot("camera-after")
        back()
        camera.tap()
        XCTAssertFalse(draftButton.isSelected, "Returning without Save must discard the draft")
        draftButton.tap()
        app.buttons["保存延时"].tap()
        XCTAssertTrue(camera.waitForExistence(timeout: 3))
        camera.tap()
        XCTAssertTrue(draftButton.isSelected, "Save must commit the new delay")
        if let original { app.buttons["延时\(original)秒"].tap(); app.buttons["保存延时"].tap() } else { back() }

        app.buttons["找手机入口"].tap()
        XCTAssertGreaterThanOrEqual(app.switches.count, 1)
        let phoneSwitch = app.switches.firstMatch
        let oldValue = phoneSwitch.value as? String
        phoneSwitch.tap()
        XCTAssertNotEqual(phoneSwitch.value as? String, oldValue)
        phoneSwitch.tap()
        shot("phone-after")
        back()

        app.buttons["墨水屏标签"].tap()
        XCTAssertTrue(app.buttons["上传到墨水屏"].waitForExistence(timeout: 3))
        shot("ink-after")
        app.buttons["上传到墨水屏"].tap()
        app.buttons["确认上传"].tap()
        XCTAssertTrue(app.buttons["完成"].waitForExistence(timeout: 8))
        shot("upload-after")
        app.buttons["完成"].tap()

        app.buttons["提醒标签"].tap()
        XCTAssertTrue(app.buttons["新增提醒"].waitForExistence(timeout: 3))
        XCTAssertGreaterThanOrEqual(app.switches.count, 1)
        shot("reminders-after")
        app.buttons["新增提醒"].tap()
        XCTAssertTrue(app.buttons["保存提醒"].waitForExistence(timeout: 3))
        app.buttons["保存提醒"].tap()
        XCTAssertTrue(app.staticTexts["请填写提醒事项。"].waitForExistence(timeout: 3))
        shot("reminder-editor-after")
        app.buttons["取消"].tap()
        app.buttons["设置"].tap()
        XCTAssertTrue(app.buttons["保存规则"].waitForExistence(timeout: 3))
        shot("hourly-editor-after")
        app.buttons["取消"].tap()
    }
}
