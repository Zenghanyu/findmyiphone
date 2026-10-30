import XCTest

final class ButtonReview: XCTestCase {
  let app = XCUIApplication(bundleIdentifier: "com.easyfind.companion")

  override func setUpWithError() throws {
    continueAfterFailure = false
    app.launchArguments = ["-uiMock", "-selfieDemo", "-phoneFindAuthorized"]
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
    let button = app.navigationBars.buttons.matching(identifier: "BackButton")
      .allElementsBoundByIndex.first(where: { $0.isHittable })
    XCTAssertNotNil(button, "A visible navigation back button is required")
    button?.tap()
  }

  func waitUntilHittable(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
    let visible = XCTNSPredicateExpectation(
      predicate: NSPredicate { _, _ in element.exists && element.isHittable }, object: element)
    return XCTWaiter.wait(for: [visible], timeout: timeout) == .completed
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
    XCTAssertEqual(
      hourly.value as? String, "0", "Separate physical taps must each update the state")
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
    if let original {
      app.buttons["延时\(original)秒"].tap()
      app.buttons["保存延时"].tap()
    } else {
      back()
    }

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
    XCTAssertTrue(app.images["墨水屏效果预览"].waitForExistence(timeout: 10))
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

  func testUnavailableDeviceCannotSaveSettings() throws {
    app.terminate()
    app.launchArguments = []
    app.launch()
    app.buttons["设备标签"].tap()
    app.buttons["遥控拍照入口"].tap()
    let save = app.buttons["保存延时"]
    XCTAssertTrue(save.waitForExistence(timeout: 5))
    XCTAssertFalse(save.isEnabled)
    shot("backend-device-unavailable")
    back()
    shot("device-normal")
    app.buttons["墨水屏标签"].tap()
    XCTAssertTrue(app.images["墨水屏效果预览"].waitForExistence(timeout: 15))
    shot("display-normal")
    app.buttons["提醒标签"].tap()
    shot("reminders-normal")
  }

  func testInkPreviewBeforeUploadWithoutDevice() throws {
    app.terminate()
    // Keep isolated storage but exercise the real upload availability rules.
    app.launchArguments = ["-uiMock", "-inkUseBluetooth"]
    app.launch()
    app.buttons["墨水屏标签"].tap()
    let preview = app.images["墨水屏效果预览"]
    XCTAssertTrue(preview.waitForExistence(timeout: 15), app.debugDescription)
    XCTAssertEqual(preview.value as? String, "240 × 240 像素")
    shot("ink-screen-preview")

    app.buttons["上传到墨水屏"].tap()
    XCTAssertTrue(preview.waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts.matching(identifier: "请先选择墨水屏").firstMatch.exists)
    XCTAssertFalse(app.buttons["确认上传"].isEnabled)
    shot("ink-preview-without-device")
    back()

    // A new template must invalidate the previous processing result.
    app.swipeUp()
    app.buttons["模板"].tap()
    XCTAssertTrue(app.navigationBars["模板图库"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.buttons["AI 生图"].exists)
    XCTAssertFalse(app.buttons["AI image"].exists)
    app.buttons["花开时节"].tap()
    app.buttons["使用这张模板"].tap()
    XCTAssertTrue(app.buttons["确认上传"].waitForExistence(timeout: 5))
    back()
    app.swipeDown()
    XCTAssertTrue(preview.waitForExistence(timeout: 15))
    XCTAssertEqual(preview.value as? String, "240 × 240 像素")
    shot("ink-new-template-preview")
  }

  /// Requires the isolated fixture started by scripts/test-backend.sh.
  func testHTTPFeedback() throws {
    app.buttons["设备标签"].tap()
    app.buttons["设备设置"].tap()
    app.buttons["后端服务设置"].tap()
    let address = app.textFields["后端服务地址"]
    XCTAssertTrue(address.waitForExistence(timeout: 5))
    address.tap()
    address.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.5)).tap()
    let existing = address.value as? String ?? ""
    address.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing.count))
    address.typeText("http://127.0.0.1:8001")
    XCTAssertEqual(address.value as? String, "http://127.0.0.1:8001")
    let token = app.secureTextFields["后端访问令牌"]
    token.tap()
    token.typeText("integration-local-only")
    app.buttons["保存服务设置"].tap()
    let settingsBack = app.navigationBars["设备设置"].buttons["BackButton"]
    // iOS may present Password AutoFill in a separate window after resigning
    // the secure field. Scope to the sheet and wait for the actual back control.
    for _ in 0..<3 {
      if waitUntilHittable(settingsBack, timeout: 1) { break }
      let sheetLater = app.sheets.buttons["以后"].firstMatch
      let later = sheetLater.exists ? sheetLater : app.buttons["以后"].firstMatch
      if waitUntilHittable(later, timeout: 2) { later.tap() }
    }
    XCTAssertTrue(waitUntilHittable(settingsBack), app.debugDescription)
    shot("backend-service-configured")
    settingsBack.tap()
    app.buttons["设备标签"].tap()
    app.buttons["设备设置"].tap()
    app.swipeUp()
    app.buttons["意见反馈"].tap()
    let details = app.textViews["反馈内容"]
    XCTAssertTrue(details.waitForExistence(timeout: 5))
    details.tap()
    details.typeText("Integration feedback")
    app.swipeUp()
    app.buttons["发送反馈"].tap()
    XCTAssertTrue(
      app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "已收到反馈，编号：")).firstMatch
        .waitForExistence(timeout: 10))
    shot("backend-feedback-receipt")
  }

  func testReminderAuthorizationHintFollowsLanguage() throws {
    let chinese = "请允许系统通知，提醒规则已保存，授权后会自动安排。"
    let english =
      "Please allow notifications. Your reminder settings are saved and will be scheduled once permission is granted."
    // Run on a simulator where notification permission has not been granted.
    app.buttons["提醒标签"].tap()
    XCTAssertTrue(app.staticTexts[chinese].waitForExistence(timeout: 5))

    app.buttons["设备标签"].tap()
    app.buttons["设备设置"].tap()
    app.swipeUp()
    app.segmentedControls["语言切换"].buttons["En"].tap()
    app.buttons["提醒标签"].tap()
    XCTAssertTrue(app.staticTexts[english].waitForExistence(timeout: 5))
    XCTAssertFalse(app.staticTexts[chinese].exists)
    shot("reminder-authorization-english")

    app.terminate()
    app.launch()
    app.buttons["提醒标签"].tap()
    XCTAssertTrue(app.staticTexts[english].waitForExistence(timeout: 5))

    app.buttons["设备标签"].tap()
    app.buttons["设备设置"].tap()
    app.swipeUp()
    app.segmentedControls["语言切换"].buttons["中"].tap()
    app.buttons["提醒标签"].tap()
    XCTAssertTrue(app.staticTexts[chinese].waitForExistence(timeout: 5))
    XCTAssertFalse(app.staticTexts[english].exists)
    shot("reminder-authorization-chinese")
  }

  func testAppearanceLanguageAndDeviceNamePersist() throws {
    app.buttons["设备标签"].tap()
    app.buttons["设备设置"].tap()
    app.buttons["设备名称"].tap()
    let name = app.textFields["设备名称输入框"]
    XCTAssertTrue(name.waitForExistence(timeout: 5))
    let oldName = name.value as? String ?? ""
    name.tap()
    name.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: oldName.count))
    name.typeText("My EasyFind")
    app.buttons["保存设备名称"].tap()
    app.swipeUp()
    app.segmentedControls["外观主题"].buttons["深色"].tap()
    app.segmentedControls["语言切换"].buttons["En"].tap()
    XCTAssertTrue(app.navigationBars["Device Settings"].exists)
    shot("settings-dark-english")
    app.terminate()
    app.launch()
    app.buttons["设备标签"].tap()
    XCTAssertTrue(app.staticTexts["My EasyFind"].exists)
    XCTAssertTrue(app.staticTexts["My Device"].exists)
    shot("device-dark-english")
    app.buttons["设备设置"].tap()
    app.swipeUp()
    XCTAssertTrue(app.segmentedControls["外观主题"].buttons["Dark"].isSelected)
    app.buttons["墨水屏标签"].tap()
    XCTAssertTrue(app.buttons["Templates"].waitForExistence(timeout: 5))
    app.buttons["Templates"].tap()
    XCTAssertTrue(app.navigationBars["Templates"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.buttons["AI 生图"].exists)
    XCTAssertFalse(app.buttons["AI image"].exists)
    back()
    app.buttons["设备标签"].tap()
    app.swipeUp()
    app.segmentedControls["外观主题"].buttons["Light"].tap()
    app.segmentedControls["语言切换"].buttons["中"].tap()
    shot("settings-light-chinese")
    app.segmentedControls["外观主题"].buttons["跟随系统"].tap()
  }

  func testReminderSwipeDeleteAndCameraAvailability() throws {
    let itemTitle = "Swipe test " + UUID().uuidString.prefix(6)
    app.buttons["提醒标签"].tap()
    app.buttons["新增提醒"].tap()
    let title = app.textFields["提醒事项"]
    XCTAssertTrue(title.waitForExistence(timeout: 5), app.debugDescription)
    title.tap()
    title.typeText(itemTitle)
    app.buttons["保存提醒"].tap()
    let rowTitle = app.staticTexts[itemTitle]
    XCTAssertTrue(rowTitle.waitForExistence(timeout: 5))
    for _ in 0..<3 {
      if rowTitle.frame.midY < app.frame.height - 180 { break }
      app.swipeUp()
    }
    XCTAssertTrue(waitUntilHittable(rowTitle), app.debugDescription)
    let toggle = app.switches["开启" + itemTitle + "提醒"].firstMatch
    XCTAssertEqual(toggle.value as? String, "1")
    toggle.tap()
    XCTAssertEqual(toggle.value as? String, "0")
    toggle.tap()
    XCTAssertEqual(toggle.value as? String, "1")
    rowTitle.swipeLeft()
    let delete = app.buttons["删除" + itemTitle]
    XCTAssertTrue(delete.waitForExistence(timeout: 3), app.debugDescription)
    shot("reminder-swipe-revealed")
    XCTAssertTrue(waitUntilHittable(delete), app.debugDescription)
    delete.tap()
    XCTAssertEqual(app.state, .runningForeground)
    XCTAssertFalse(rowTitle.exists)
    app.terminate()
    app.launch()
    app.buttons["提醒标签"].tap()
    XCTAssertFalse(rowTitle.exists, "Deletion must survive restarting the app")
    app.buttons["墨水屏标签"].tap()
    app.buttons["拍照入口"].tap()
    let closeCamera = app.buttons["DismissImagePickerButton"]
    if closeCamera.waitForExistence(timeout: 5) {
      shot("camera-system-picker")
      closeCamera.tap()
      XCTAssertTrue(waitUntilHittable(app.buttons["拍照入口"]))
    } else {
      XCTAssertTrue(
        app.staticTexts["此设备无法使用相机"].waitForExistence(timeout: 5), app.debugDescription)
      app.alerts.buttons["好"].tap()
    }
  }
}
