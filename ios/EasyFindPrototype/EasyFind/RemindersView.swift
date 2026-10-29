import SwiftUI

struct RemindersView: View {
  @Environment(AppModel.self) private var model
  @State private var editor: ReminderEditorMode?
  @State private var showHourlySettings = false
  @State private var openReminderID: UUID?

  var body: some View {
    @Bindable var model = model
    ScrollView {
      VStack(spacing: 20) {
        ScreenHeader(title: model.t("提醒", "Reminders"), subtitle: "")
        if !model.notifications.authorized {
          Button(model.t("开启系统通知", "Enable notifications")) {
            Task { await model.authorizeReminders() }
          }
        }
        if let error = model.notifications.error {
          Text(error).font(.caption).foregroundStyle(Color.efSubtext)
        }
        VStack(spacing: 18) {
          Toggle(model.t("自动报时", "Hourly chime"), isOn: $model.hourlyReminderEnabled)
            .toggleStyle(MonochromeToggleStyle())
            .font(.headline)
            .accessibilityIdentifier("自动报时")
          HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(model.hourlyStart)
            Text("—").font(.subheadline).foregroundStyle(Color.efSubtext)
            Text(model.hourlyEnd)
          }
          .font(.system(size: 34, weight: .medium, design: .rounded))
          .frame(maxWidth: .infinity, alignment: .leading)
          HStack {
            Text(
              "\(model.t(model.hourlyInterval, model.hourlyInterval == "每小时" ? "Hourly" : "Every 2 hours")) · \(model.repeatText("每天"))"
            )
            .font(.caption).foregroundStyle(Color.efSubtext)
            Spacer()
            Button(model.t("设置", "Edit")) { showHourlySettings = true }
              .font(.subheadline.weight(.medium)).foregroundStyle(Color.efAccent)
              .frame(minWidth: 44, minHeight: 44)
              .buttonStyle(PressFeedbackStyle())
          }
        }
        .padding(18)
        .background(Color.efPaper, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.efLine))
        HStack {
          Text(model.t("事项 \(model.reminders.count)", "Items \(model.reminders.count)")).font(
            .headline)
          Spacer()
          Button {
            editor = .new
          } label: {
            Label(model.t("新增", "Add"), systemImage: "plus")
          }
          .font(.subheadline.weight(.medium))
          .padding(.horizontal, 12)
          .frame(minHeight: 36)
          .background(Color.efTint, in: Capsule())
          .buttonStyle(PressFeedbackStyle())
          .accessibilityIdentifier("新增提醒")
        }
        .padding(.top, 2)
        if model.reminders.isEmpty {
          VStack(spacing: 12) {
            Image(systemName: "bell").font(.title2).foregroundStyle(Color.efText)
            Text(model.t("暂无事项", "No reminders")).font(.headline)
          }
          .frame(maxWidth: .infinity).padding(.vertical, 38)
          .background(Color.efPaper, in: RoundedRectangle(cornerRadius: 12))
          .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.efLine))
        } else {
          VStack(spacing: 0) {
            ForEach(model.reminders) { reminder in
              ReminderSwipeRow(
                reminder: reminder,
                openReminderID: $openReminderID,
                onToggle: { model.setReminderEnabled(id: reminder.id, enabled: $0) },
                onEdit: { editor = .edit(reminder) },
                onDelete: {
                  openReminderID = nil
                  model.deleteReminder(reminder)
                }
              )
              if reminder.id != model.reminders.last?.id {
                Divider().background(Color.efLine).padding(.leading, 16)
              }
            }
          }
          .background(Color.efPaper, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
          .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.efLine))
        }
      }
      .padding(.horizontal, 20).padding(.bottom, 28)
    }
    .background(Color.efBackground.ignoresSafeArea().onTapGesture { openReminderID = nil })
    .navigationTitle("EasyFind")
    .navigationBarTitleDisplayMode(.inline)
    .sheet(item: $editor) { mode in
      ReminderEditorView(mode: mode)
        .presentationDetents([.medium, .large])
    }
    .sheet(isPresented: $showHourlySettings) {
      HourlySettingsView().presentationDetents([.medium, .large])
    }
  }
}

private struct ReminderSwipeRow: View {
  @Environment(AppModel.self) private var model
  let reminder: ReminderItem
  @Binding var openReminderID: UUID?
  let onToggle: (Bool) -> Void
  let onEdit: () -> Void
  let onDelete: () -> Void
  @State private var dragTranslation: CGFloat = 0

  private let revealWidth: CGFloat = 72
  private var isOpen: Bool { openReminderID == reminder.id }
  private var isRevealing: Bool { isOpen || dragTranslation < 0 }
  private var currentOffset: CGFloat {
    isOpen ? -revealWidth + max(0, dragTranslation) : min(0, dragTranslation)
  }

  var body: some View {
    ZStack(alignment: .trailing) {
      Button(role: .destructive, action: onDelete) {
        Image(systemName: "trash")
          .font(.system(size: 18, weight: .medium))
          .foregroundStyle(Color.efText)
          .frame(width: revealWidth, height: 64)
          .background(Color.efTint)
          .contentShape(Rectangle())
      }
      .buttonStyle(PressFeedbackStyle())
      .opacity(isRevealing ? 1 : 0)
      .disabled(!isRevealing)
      .accessibilityHidden(!isRevealing)
      .accessibilityLabel(model.t("删除\(reminder.title)", "Delete \(reminder.title)"))
      .accessibilityIdentifier("删除提醒-\(reminder.id.uuidString)")
      .zIndex(1)

      HStack(spacing: 10) {
        Button {
          if isOpen { openReminderID = nil } else { onEdit() }
        } label: {
          HStack(spacing: 14) {
            Text(reminder.time)
              .font(.system(size: 19, weight: .medium, design: .rounded)).monospacedDigit()
              .frame(width: 62, alignment: .leading)
            VStack(alignment: .leading, spacing: 3) {
              Text(reminder.title).foregroundStyle(Color.efText).lineLimit(2)
              Text(model.repeatText(reminder.repeatRule)).font(.caption).foregroundStyle(
                Color.efSubtext)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .contentShape(Rectangle())
        }
        .buttonStyle(PressFeedbackStyle())
        .accessibilityIdentifier("编辑\(reminder.title)")
        Toggle("", isOn: Binding(get: { reminder.isEnabled }, set: onToggle))
          .labelsHidden()
          .toggleStyle(MonochromeToggleStyle(hidesLabel: true))
          .accessibilityIdentifier("提醒开关-\(reminder.id.uuidString)")
          .accessibilityLabel(model.t("开启\(reminder.title)提醒", "Enable \(reminder.title)"))
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 13)
      .background(Color.efPaper)
      .offset(x: currentOffset)
      .allowsHitTesting(!isOpen)
    }
    .contentShape(Rectangle())
    .highPriorityGesture(
      DragGesture(minimumDistance: 10)
        .onChanged { value in
          guard abs(value.translation.width) > abs(value.translation.height) else { return }
          dragTranslation =
            isOpen
            ? max(0, value.translation.width)
            : max(-revealWidth, min(0, value.translation.width))
        }
        .onEnded { value in
          guard abs(value.translation.width) > abs(value.translation.height) else {
            dragTranslation = 0
            return
          }
          openReminderID = value.translation.width < -36 ? reminder.id : nil
          dragTranslation = 0
        }
    )
    .onTapGesture { if isOpen { openReminderID = nil } }
    .clipped()
    .animation(.easeOut(duration: 0.18), value: dragTranslation)
    .animation(.easeOut(duration: 0.18), value: isOpen)
  }
}

enum ReminderEditorMode: Identifiable {
  case new
  case edit(ReminderItem)

  var id: String {
    switch self {
    case .new: "new"
    case .edit(let reminder): reminder.id.uuidString
    }
  }
}

struct ReminderEditorView: View {
  @Environment(AppModel.self) private var model
  @Environment(\.dismiss) private var dismiss
  let mode: ReminderEditorMode
  @State private var title: String
  @State private var time: Date
  @State private var repeatRule: String
  @State private var showValidation = false

  init(mode: ReminderEditorMode) {
    self.mode = mode
    switch mode {
    case .new:
      _title = State(initialValue: "")
      _time = State(initialValue: TimeHelper.date(from: "09:00"))
      _repeatRule = State(initialValue: "每天")
    case .edit(let reminder):
      _title = State(initialValue: reminder.title)
      _time = State(initialValue: reminder.onceAt ?? TimeHelper.date(from: reminder.time))
      _repeatRule = State(initialValue: reminder.repeatRule)
    }
  }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          TextField(model.t("例如：出门带钥匙", "e.g. Take your keys"), text: $title)
            .accessibilityIdentifier("提醒事项")
          DatePicker(
            model.t("提醒时间", "Time"), selection: $time,
            displayedComponents: repeatRule == "仅一次" ? [.date, .hourAndMinute] : [.hourAndMinute])
          Picker(model.t("重复", "Repeat"), selection: $repeatRule) {
            ForEach(["每天", "工作日", "仅一次"], id: \.self) { rule in
              Text(model.repeatText(rule)).tag(rule)
            }
          }
        }
        if showValidation {
          Text(
            title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
              ? model.t("请填写提醒事项。", "Enter a reminder.")
              : model.t("请选择未来的提醒时间。", "Choose a future date and time.")
          ).foregroundStyle(.red).font(.footnote)
        }
        if case .edit(let reminder) = mode {
          Section {
            Button(model.t("删除提醒", "Delete Reminder"), role: .destructive) {
              model.deleteReminder(reminder)
              dismiss()
            }
          }
        }
      }
      .navigationTitle(
        mode.isNew ? model.t("新建提醒", "New Reminder") : model.t("编辑提醒", "Edit Reminder")
      )
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(model.t("取消", "Cancel")) { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button(model.t("保存", "Save")) { save() }
            .fontWeight(.semibold)
            .accessibilityIdentifier("保存提醒")
        }
      }
    }
  }

  private func save() {
    let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !cleanTitle.isEmpty, repeatRule != "仅一次" || time > Date() else {
      showValidation = true
      return
    }
    let timeString = TimeHelper.string(from: time)
    switch mode {
    case .new:
      model.reminders.append(
        ReminderItem(
          id: UUID(), time: timeString, title: cleanTitle, repeatRule: repeatRule, isEnabled: true,
          onceAt: repeatRule == "仅一次" ? time : nil))
    case .edit(let reminder):
      guard let index = model.reminders.firstIndex(where: { $0.id == reminder.id }) else { return }
      var items = model.reminders
      items[index].title = cleanTitle
      items[index].time = timeString
      items[index].repeatRule = repeatRule
      items[index].onceAt = repeatRule == "仅一次" ? time : nil
      model.reminders = items
    }
    model.reminders.sort { $0.time < $1.time }
    dismiss()
  }
}

struct HourlySettingsView: View {
  @Environment(AppModel.self) private var model
  @Environment(\.dismiss) private var dismiss
  @State private var start = Date()
  @State private var end = Date()
  @State private var interval = "每小时"
  @State private var showValidation = false

  var body: some View {
    NavigationStack {
      Form {
        Section {
          DatePicker(
            model.t("开始时间", "Start"), selection: $start, displayedComponents: .hourAndMinute)
          DatePicker(model.t("结束时间", "End"), selection: $end, displayedComponents: .hourAndMinute)
          Picker(model.t("报时间隔", "Interval"), selection: $interval) {
            Text(model.t("每小时", "Hourly")).tag("每小时")
            Text(model.t("每两小时", "Every 2 hours")).tag("每两小时")
          }
        }
        if showValidation {
          Text(model.t("结束时间需晚于开始时间。", "End time must be later than start time.")).foregroundStyle(
            .red
          ).font(.footnote)
        }
      }
      .navigationTitle(model.t("自动报时", "Hourly Chime"))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(model.t("取消", "Cancel")) { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button(model.t("保存", "Save")) { save() }
            .fontWeight(.semibold)
            .accessibilityIdentifier("保存规则")
        }
      }
      .onAppear {
        start = TimeHelper.date(from: model.hourlyStart)
        end = TimeHelper.date(from: model.hourlyEnd)
        interval = model.hourlyInterval
      }
    }
  }

  private func save() {
    guard end > start else {
      showValidation = true
      return
    }
    model.saveHourly(
      start: TimeHelper.string(from: start), end: TimeHelper.string(from: end), interval: interval)
    dismiss()
  }
}

private enum TimeHelper {
  static func date(from string: String) -> Date {
    let parts = string.split(separator: ":").compactMap { Int($0) }
    guard parts.count == 2 else { return Date() }
    return Calendar.current.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: Date())
      ?? Date()
  }

  static func string(from date: Date) -> String {
    let components = Calendar.current.dateComponents([.hour, .minute], from: date)
    return String(format: "%02d:%02d", components.hour ?? 0, components.minute ?? 0)
  }
}

extension ReminderEditorMode {
  fileprivate var isNew: Bool {
    if case .new = self { return true }
    return false
  }
}
