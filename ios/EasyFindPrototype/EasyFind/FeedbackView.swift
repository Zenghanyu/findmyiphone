import SwiftUI

struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var category = "功能建议"
    @State private var details = ""
    @State private var contact = ""

    private var cleanDetails: String {
        details.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var shareText: String {
        var text = "EasyFind 用户反馈\n类型：\(category)\n内容：\(cleanDetails)"
        let cleanContact = contact.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanContact.isEmpty {
            text += "\n联系方式：\(cleanContact)"
        }
        return text
    }

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
                        .textInputAutocapitalization(.never)
                        .accessibilityIdentifier("反馈联系方式")
                } footer: {
                    Text("填写后可通过邮件、信息等方式发送给开发者。")
                }
                Section {
                    ShareLink(item: shareText) {
                        Label("发送反馈", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity, minHeight: 36)
                    }
                    .disabled(cleanDetails.isEmpty)
                    .foregroundStyle(Color.efAccent)
                    .accessibilityIdentifier("发送反馈")
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
            }
        }
    }
}
