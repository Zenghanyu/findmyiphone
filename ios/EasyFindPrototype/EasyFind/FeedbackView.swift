import PhotosUI
import SwiftUI

struct FeedbackView: View {
  @Environment(AppModel.self) private var model
  @Environment(\.dismiss) private var dismiss
  @State private var details = ""
  @State private var contact = ""
  @State private var photoItems: [PhotosPickerItem] = []
  @State private var attachments: [Data] = []
  @State private var showContactPrompt = false
  @State private var showPhotoError = false
  @State private var showContactEditor = false
  @State private var sent = false
  @State private var submitting = false
  @State private var loadingPhotos = false
  @State private var receipt: String?
  @State private var error: String?
  @FocusState private var editing: Bool

  private var cleanDetails: String {
    details.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  var body: some View {
    NavigationStack {
      ZStack {
        Color.efBackground.ignoresSafeArea()
        if sent {
          FeedbackSuccessView(receipt: receipt ?? "", onDone: { dismiss() })
        } else {
          composer
        }
      }
      .interactiveDismissDisabled(submitting || loadingPhotos)
      .navigationTitle(sent ? model.t("发送成功", "Feedback sent") : model.t("意见反馈", "Feedback"))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        if !sent {
          ToolbarItem(placement: .cancellationAction) {
            Button(model.t("取消", "Cancel")) { dismiss() }
              .disabled(submitting || loadingPhotos)
          }
        }
      }
      .alert(
        model.t("能否留下您的联系方式？", "May we have your contact details?"), isPresented: $showContactPrompt
      ) {
        Button(model.t("跳过", "Skip")) { completeSend() }
        Button(model.t("填写", "Add")) { showContactEditor = true }
      } message: {
        Text(model.t("联系方式选填，便于后续沟通。", "Contact details are optional and help us follow up."))
      }
      .sheet(isPresented: $showContactEditor) {
        FeedbackContactView(
          contact: $contact,
          onCancel: { showContactEditor = false },
          onSend: completeSend
        )
      }
      .alert(model.t("图片读取失败", "Couldn’t load one or more photos"), isPresented: $showPhotoError) {
        Button(model.t("好", "OK"), role: .cancel) {}
      }
    }
  }

  private var composer: some View {
    ScrollView {
      VStack(spacing: 16) {
        composerCard.disabled(submitting)
        if let error {
          Text(error).font(.footnote).foregroundStyle(.red).accessibilityIdentifier("反馈错误")
        }
      }.padding(20)
    }
    .scrollDismissesKeyboard(.interactively)
    .safeAreaInset(edge: .bottom) {
      SendFeedbackButton(
        title: submitting ? model.t("正在提交…", "Sending…") : model.t("发送反馈", "Send feedback"),
        systemImage: "paperplane.fill",
        isDisabled: cleanDetails.isEmpty || submitting || loadingPhotos,
        action: {
          editing = false
          showContactPrompt = true
        }
      ).accessibilityIdentifier("发送反馈")
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(
          LinearGradient(
            colors: [Color.efBackground.opacity(0), Color.efBackground],
            startPoint: .top,
            endPoint: .bottom
          )
          .ignoresSafeArea()
        )
    }
    .onChange(of: photoItems) { _, items in
      guard !items.isEmpty else { return }
      Task { await loadPhotos(items) }
    }
  }

  private var composerCard: some View {
    VStack(alignment: .leading, spacing: 0) {
      ZStack(alignment: .topLeading) {
        TextEditor(text: $details)
          .disabled(submitting)
          .focused($editing)
          .frame(minHeight: 300)
          .scrollContentBackground(.hidden)
          .accessibilityIdentifier("反馈内容")
        if details.isEmpty {
          Text(model.t("请描述你的问题或建议", "Describe a problem or suggestion"))
            .foregroundStyle(Color.efSubtext)
            .padding(.top, 8)
            .padding(.leading, 5)
            .allowsHitTesting(false)
        }
      }

      if !attachments.isEmpty {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 10) {
            ForEach(Array(attachments.enumerated()), id: \.offset) { index, data in
              attachmentThumbnail(data: data, index: index)
            }
          }
          .padding(.vertical, 4)
        }
        .frame(height: 76)
        .padding(.bottom, 8)
      }

      Divider().background(Color.efLine)

      HStack {
        PhotosPicker(
          selection: $photoItems,
          maxSelectionCount: max(1, 10 - attachments.count),
          matching: .images
        ) {
          Image(systemName: "paperclip")
            .font(.system(size: 20, weight: .medium))
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .disabled(attachments.count >= 10 || loadingPhotos || submitting)
        .opacity(attachments.count >= 10 ? 0.3 : 1)
        .accessibilityLabel(model.t("添加图片，最多10张", "Add photos, up to 10"))
        .accessibilityIdentifier("反馈图片选择")
        Spacer()
        if !attachments.isEmpty {
          Text("\(attachments.count)/10")
            .font(.caption.monospacedDigit())
            .foregroundStyle(Color.efSubtext)
        }
      }
      .frame(height: 46)
    }
    .padding(16)
    .background(Color.efPaper, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.efLine.opacity(0.7)))
  }

  private func attachmentThumbnail(data: Data, index: Int) -> some View {
    ZStack(alignment: .topTrailing) {
      if let image = UIImage(data: data) {
        Image(uiImage: image)
          .resizable()
          .scaledToFill()
          .frame(width: 64, height: 64)
          .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
          .accessibilityLabel(model.t("反馈图片 \(index + 1)", "Feedback photo \(index + 1)"))
      }
      Button {
        attachments.remove(at: index)
      } label: {
        Image(systemName: "xmark")
          .font(.system(size: 9, weight: .bold))
          .foregroundStyle(Color.efOnAccent)
          .frame(width: 22, height: 22)
          .background(Color.efAccent, in: Circle())
      }
      .offset(x: 5, y: -5)
      .disabled(submitting || loadingPhotos)
      .accessibilityLabel(model.t("移除图片 \(index + 1)", "Remove photo \(index + 1)"))
    }
    .frame(width: 68, height: 68)
  }

  @MainActor private func loadPhotos(_ items: [PhotosPickerItem]) async {
    guard !loadingPhotos else { return }
    loadingPhotos = true
    defer { loadingPhotos = false }
    var loaded: [Data] = []
    let remaining = max(0, 10 - attachments.count)
    for item in items.prefix(remaining) {
      if let data = try? await item.loadTransferable(type: Data.self),
        let attachment = try? await PhotoRepository.feedbackAttachment(data)
      {
        loaded.append(attachment)
      }
    }
    await MainActor.run {
      attachments.append(contentsOf: loaded.prefix(max(0, 10 - attachments.count)))
      photoItems = []
      showPhotoError = loaded.count < items.prefix(remaining).count
    }
  }

  private func completeSend() {
    showContactEditor = false
    showContactPrompt = false
    guard !submitting else { return }
    editing = false
    submitting = true
    error = nil
    Task {
      defer { submitting = false }
      do {
        receipt = try await model.backend.client().submitFeedback(
          category: "功能建议", details: cleanDetails, contact: contact, attachments: attachments
        ).id
        withAnimation(.easeOut(duration: 0.25)) { sent = true }
      } catch { self.error = error.localizedDescription }
    }
  }
}

private struct FeedbackContactView: View {
  @Environment(AppModel.self) private var model
  @Binding var contact: String
  let onCancel: () -> Void
  let onSend: () -> Void

  var body: some View {
    NavigationStack {
      VStack(spacing: 20) {
        TextField(model.t("联系方式", "Contact details"), text: $contact)
          .textInputAutocapitalization(.never)
          .padding(16)
          .background(Color.efPaper, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
          .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.efLine))
          .accessibilityIdentifier("反馈联系方式")
        SendFeedbackButton(
          title: model.t("发送反馈", "Send feedback"), systemImage: "paperplane.fill", action: onSend)
        Spacer()
      }
      .padding(20)
      .background(Color.efBackground.ignoresSafeArea())
      .navigationTitle(model.t("联系方式", "Contact details"))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(model.t("取消", "Cancel"), action: onCancel)
        }
      }
    }
    .presentationDetents([.medium])
  }
}

private struct FeedbackSuccessView: View {
  @Environment(AppModel.self) private var model
  let receipt: String
  let onDone: () -> Void

  var body: some View {
    VStack(spacing: 24) {
      Spacer()
      Image(systemName: "checkmark")
        .font(.system(size: 38, weight: .semibold))
        .foregroundStyle(Color.efOnAccent)
        .frame(width: 88, height: 88)
        .background(Color.efAccent, in: Circle())
        .shadow(color: Color.efAccent.opacity(0.14), radius: 24)
      VStack(spacing: 10) {
        Text(model.t("感谢你的反馈", "Thank you for your feedback"))
          .font(.system(size: 28, weight: .bold))
          .foregroundStyle(Color.efText)
        Text(model.t("你的建议会让 EasyFind 变得更好", "Your feedback helps make EasyFind better."))
          .font(.body)
          .foregroundStyle(Color.efSubtext)
          .multilineTextAlignment(.center)
      }
      Text(model.t("已收到反馈，编号：", "Receipt: ") + receipt)
        .font(.footnote).foregroundStyle(Color.efSubtext).textSelection(.enabled)
        .accessibilityIdentifier("反馈回执")
      Spacer()
      SendFeedbackButton(title: model.t("完成", "Done"), systemImage: "checkmark", action: onDone)
    }
    .padding(24)
  }
}

private struct SendFeedbackButton: View {
  let title: String
  let systemImage: String
  var isDisabled = false
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 10) {
        Text(title)
        Image(systemName: systemImage)
          .font(.subheadline.weight(.semibold))
      }
      .font(.headline)
      .foregroundStyle(Color.efOnAccent)
      .frame(maxWidth: .infinity, minHeight: 56)
      .background(
        LinearGradient(
          colors: [Color(light: "242426", dark: "FFFFFF"), Color(light: "000000", dark: "D9D9DE")],
          startPoint: .top, endPoint: .bottom),
        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
      )
      .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.efAccent.opacity(0.65)))
      .shadow(color: Color.efAccent.opacity(0.12), radius: 14, y: 4)
    }
    .buttonStyle(PressFeedbackStyle())
    .disabled(isDisabled)
    .opacity(isDisabled ? 0.35 : 1)
    .accessibilityIdentifier(title)
  }
}
