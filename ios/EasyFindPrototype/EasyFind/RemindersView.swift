import SwiftUI

struct RemindersView: View {
    @Environment(AppModel.self) private var model
    @State private var editor: ReminderEditorMode?
    @State private var showHourlySettings = false

    var body: some View {
        @Bindable var model = model
        ScrollView {
            VStack(spacing: 20) {
                ScreenHeader(title: "提醒", subtitle: "")
                VStack(spacing: 18) {
                    Toggle("自动报时", isOn: $model.hourlyReminderEnabled)
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
                        Text("\(model.hourlyInterval) · 每天").font(.caption).foregroundStyle(Color.efSubtext)
                        Spacer()
                        Button("设置") { showHourlySettings = true }
                            .font(.subheadline.weight(.medium)).foregroundStyle(Color.efAccent)
                            .frame(minWidth: 44, minHeight: 44)
                            .buttonStyle(PressFeedbackStyle())
                    }
                }
                .padding(18)
                .background(Color.efPaper, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.efLine))
                HStack {
                    Text("事项 \(model.reminders.count)").font(.headline)
                    Spacer()
                    Button { editor = .new } label: { Label("新增", systemImage: "plus") }
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
                        Text("暂无事项").font(.headline)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 38)
                    .background(Color.efPaper, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.efLine))
                } else {
                    VStack(spacing: 0) {
                        ForEach($model.reminders) { $reminder in
                            HStack(spacing: 14) {
                                Text(reminder.time)
                                    .font(.system(size: 19, weight: .medium, design: .rounded)).monospacedDigit()
                                    .frame(width: 62, alignment: .leading)
                                Button { editor = .edit(reminder) } label: {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(reminder.title).foregroundStyle(Color.efText).lineLimit(2)
                                        Text(reminder.repeatRule).font(.caption).foregroundStyle(Color.efSubtext)
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                }
                                .buttonStyle(PressFeedbackStyle())
                                .accessibilityIdentifier("编辑\(reminder.title)")
                                Toggle("", isOn: $reminder.isEnabled)
                                    .labelsHidden()
                                    .toggleStyle(MonochromeToggleStyle(hidesLabel: true))
                                    .accessibilityIdentifier("提醒开关-\(reminder.id.uuidString)")
                                    .accessibilityLabel("开启\(reminder.title)提醒")
                            }
                            .padding(.vertical, 13)
                            if reminder.id != model.reminders.last?.id { Divider().background(Color.efLine) }
                        }
                    }
                    .padding(.horizontal, 16)
                    .background(Color.efPaper, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.efLine))
                }
            }
            .padding(.horizontal, 20).padding(.bottom, 28)
        }
        .background(Color.efBackground.ignoresSafeArea())
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
            _time = State(initialValue: TimeHelper.date(from: reminder.time))
            _repeatRule = State(initialValue: reminder.repeatRule)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("例如：出门带钥匙", text: $title)
                        .accessibilityIdentifier("提醒事项")
                    DatePicker("提醒时间", selection: $time, displayedComponents: .hourAndMinute)
                    Picker("重复", selection: $repeatRule) {
                        ForEach(["每天", "工作日", "仅一次"], id: \.self) { Text($0) }
                    }
                }
                if showValidation {
                    Text("请填写提醒事项。").foregroundStyle(.red).font(.footnote)
                }
                Section {
                    Text("提醒方式：本机演示保存，不发送系统通知。").font(.footnote).foregroundStyle(Color.efSubtext)
                }
                if case .edit(let reminder) = mode {
                    Section {
                        Button("删除提醒", role: .destructive) {
                            model.deleteReminder(reminder)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(mode.isNew ? "新建提醒" : "编辑提醒")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .fontWeight(.semibold)
                        .accessibilityIdentifier("保存提醒")
                }
            }
        }
    }

    private func save() {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { showValidation = true; return }
        let timeString = TimeHelper.string(from: time)
        switch mode {
        case .new:
            model.reminders.append(ReminderItem(id: UUID(), time: timeString, title: cleanTitle, repeatRule: repeatRule, isEnabled: true))
        case .edit(let reminder):
            guard let index = model.reminders.firstIndex(where: { $0.id == reminder.id }) else { return }
            model.reminders[index].title = cleanTitle
            model.reminders[index].time = timeString
            model.reminders[index].repeatRule = repeatRule
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
                    DatePicker("开始时间", selection: $start, displayedComponents: .hourAndMinute)
                    DatePicker("结束时间", selection: $end, displayedComponents: .hourAndMinute)
                    Picker("报时间隔", selection: $interval) {
                        Text("每小时").tag("每小时")
                        Text("每两小时").tag("每两小时")
                    }
                }
                if showValidation { Text("结束时间需晚于开始时间。").foregroundStyle(.red).font(.footnote) }
                Section { Text("提醒方式：当前仅保存本机演示规则。").font(.footnote).foregroundStyle(Color.efSubtext) }
            }
            .navigationTitle("自动报时")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
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
        guard end > start else { showValidation = true; return }
        model.hourlyStart = TimeHelper.string(from: start)
        model.hourlyEnd = TimeHelper.string(from: end)
        model.hourlyInterval = interval
        dismiss()
    }
}

private enum TimeHelper {
    static func date(from string: String) -> Date {
        let parts = string.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return Date() }
        return Calendar.current.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: Date()) ?? Date()
    }

    static func string(from date: Date) -> String {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", components.hour ?? 0, components.minute ?? 0)
    }
}

private extension ReminderEditorMode {
    var isNew: Bool {
        if case .new = self { return true }
        return false
    }
}
