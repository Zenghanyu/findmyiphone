import SwiftUI

struct FeedbackView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var category = "功能建议"
  @State private var details = ""
  @State private var contact = ""
  private enum Field: Hashable { case details, contact }
  @FocusState private var focusedField: Field?

  private var cleanDetails: String {
    details.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  @Environment(AppModel.self) private var model
  @State private var submitting = false
  @State private var receipt: String?
  @State private var error: String?

  var body: some View {
    NavigationStack {
      Form {
        Section("反馈类型") {
          Picker("反馈类型", selection: $category) {
            Text("问题").tag("问题反馈")
            Text("建议").tag("功能建议")
            Text("其他").tag("其他")
          }
          .pickerStyle(.segmented)
          .labelsHidden()
        }
        Section("反馈内容") {
          ZStack(alignment: .topLeading) {
            TextEditor(text: $details)
              .focused($focusedField, equals: .details)
              .frame(minHeight: 140)
              .scrollContentBackground(.hidden)
              .accessibilityIdentifier("反馈内容")
            if details.isEmpty {
              Text("请描述你的问题或建议")
                .foregroundStyle(Color.efSubtext)
                .padding(.top, 8)
                .padding(.leading, 5)
                .allowsHitTesting(false)
            }
          }
        }
        Section {
          TextField("邮箱或手机号（选填）", text: $contact)
            .focused($focusedField, equals: .contact)
            .textInputAutocapitalization(.never)
            .accessibilityIdentifier("反馈联系方式")
        } footer: {
          Text("反馈会提交到已配置的服务。联系方式可留空。")
        }
        Section {
          Button(submitting ? "正在提交…" : "发送反馈") {
            focusedField = nil
            submitting = true
            error = nil
            Task {
              defer { submitting = false }
              do {
                receipt = try await model.backend.client().submitFeedback(
                  category: category, details: cleanDetails, contact: contact
                ).id
              } catch { self.error = error.localizedDescription }
            }
          }
          .disabled(cleanDetails.isEmpty || submitting || receipt != nil)
          .accessibilityIdentifier("发送反馈")
          if let receipt { Text("已收到反馈，编号：" + receipt).font(.footnote) }
          if let error { Text(error).font(.footnote).foregroundStyle(.red) }
        }
      }
      .scrollContentBackground(.hidden)
      .background(Color.efBackground)
      .scrollDismissesKeyboard(.interactively)
      .navigationTitle("意见反馈")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("取消") { dismiss() }
        }
        ToolbarItemGroup(placement: .keyboard) {
          Spacer()
          Button("完成输入") { focusedField = nil }
        }
      }
    }
  }
}
