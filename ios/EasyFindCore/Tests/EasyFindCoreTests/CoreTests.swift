import XCTest

@testable import EasyFindCore

final class CoreTests: XCTestCase {
  let zone = TimeZone(identifier: "Asia/Shanghai")!
  func hourly(_ enabled: Bool = false) throws -> HourlyRule {
    try HourlyRule(
      enabled: enabled, start: LocalTime("09:00"), end: LocalTime("21:00"), intervalHours: 1)
  }
  func testTimeValidation() throws {
    for text in ["9:00", "24:00", "12:60", "aa:bb", "09:00:00", "-1:00"] {
      XCTAssertThrowsError(try LocalTime(text), text)
    }
    XCTAssertEqual(try LocalTime("23:59").minutes, 1439)
  }
  func testWeekdaysAndHourlyStayWithinCapacity() throws {
    let reminder = try Reminder(
      id: UUID(), title: "喝水", time: LocalTime("10:30"), rule: .weekdays, enabled: true)
    let result = try ReminderPlanner.plan([reminder], hourly: hourly(true), timeZone: zone)
    XCTAssertEqual(result.count, 18)
    XCTAssertEqual(result.prefix(5).compactMap { $0.components.weekday }, [2, 3, 4, 5, 6])
    XCTAssertEqual(Set(result.map(\.id)).count, result.count)
    XCTAssertTrue(result.allSatisfy { $0.repeats && $0.components.timeZone == nil })
    XCTAssertEqual(result.last?.components.hour, 21)
  }
  func testDisabledAndExpiredRemindersAreNotRecreated() throws {
    let now = Date()
    let reminders = try [
      Reminder(
        id: UUID(), title: "旧事项", time: LocalTime("09:00"), rule: .once, enabled: true,
        onceAt: now.addingTimeInterval(-1)),
      Reminder(id: UUID(), title: "已关闭", time: LocalTime("09:00"), rule: .daily, enabled: false),
    ]
    XCTAssertTrue(try ReminderPlanner.plan(reminders, hourly: hourly(), now: now).isEmpty)
  }
  func testOnceUsesAnActualDate() throws {
    let when = Date(timeIntervalSince1970: 1_800_000_000)
    let reminder = try Reminder(
      id: UUID(), title: "出发", time: LocalTime("08:00"), rule: .once, enabled: true, onceAt: when)
    let result = try ReminderPlanner.plan(
      [reminder], hourly: hourly(), now: when.addingTimeInterval(-60), timeZone: zone)
    XCTAssertFalse(result[0].repeats)
    let restored = Calendar(identifier: .gregorian).date(from: result[0].components)
    XCTAssertEqual(restored, when)
  }
  func testOverflowAndInvalidRulesDoNotProducePartialPlan() throws {
    let reminders = try (0..<14).map { _ in
      Reminder(
        id: UUID(), title: "工作日", time: try LocalTime("09:00"), rule: .weekdays, enabled: true)
    }
    XCTAssertThrowsError(try ReminderPlanner.plan(reminders, hourly: hourly()))
    let invalid = try HourlyRule(
      enabled: true, start: LocalTime("21:00"), end: LocalTime("09:00"), intervalHours: 1)
    XCTAssertThrowsError(try ReminderPlanner.plan([], hourly: invalid))
  }
  func testFilePersistenceAndCorruption() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = JSONFileStore<[String: Int]>(url: root.appendingPathComponent("state.json"))
    XCTAssertNil(try store.load())
    try store.save(["delay": 3])
    try store.save(["delay": 10])
    XCTAssertEqual(try store.load(), ["delay": 10])
    try Data("invalid".utf8).write(to: store.url)
    XCTAssertThrowsError(try store.load())
    XCTAssertEqual(try String(contentsOf: store.url), "invalid")
  }
  func testAPIConfigurationRejectsCredentialsAndInsecureRemoteHost() throws {
    for address in [
      "http://example.com", "https://user:pass@example.com", "https://example.com?token=secret",
      "file:///tmp",
    ] {
      XCTAssertThrowsError(try APIClient(baseURL: URL(string: address)!, token: "test"))
    }
    XCTAssertNoThrow(try APIClient(baseURL: URL(string: "http://127.0.0.1:8000")!, token: "test"))
  }
}
