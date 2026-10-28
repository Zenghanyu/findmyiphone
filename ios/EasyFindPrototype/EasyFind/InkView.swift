import PhotosUI
import SwiftUI

struct InkView: View {
  @Environment(AppModel.self) private var model
  @State private var photoItem: PhotosPickerItem?
  @State private var photoError = false

  var body: some View {
    ScrollView {
      VStack(spacing: 18) {
        ScreenHeader(title: "墨水屏", subtitle: "")
        ScreenPreview()
        NavigationLink(value: InkRoute.upload) {
          HStack {
            Image(systemName: "arrow.up.from.line")
            Text("上传画面")
          }
          .font(.headline).frame(maxWidth: .infinity, minHeight: 50)
          .background(Color.efAccent, in: RoundedRectangle(cornerRadius: 16))
          .foregroundStyle(Color.efOnAccent)
        }
        .buttonStyle(PressFeedbackStyle())
        .accessibilityIdentifier("上传到墨水屏")
        Text("选择画面")
          .font(.headline).frame(maxWidth: .infinity, alignment: .leading).padding(.top, 4)
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
          PhotosPicker(selection: $photoItem, matching: .images) {
            FeatureActionCard(title: "相册", systemImage: "photo.on.rectangle")
          }
          .buttonStyle(PressFeedbackStyle())
          .accessibilityIdentifier("相册")
          NavigationLink(value: InkRoute.capture) {
            FeatureActionCard(title: "拍照", systemImage: "camera")
          }
          NavigationLink(value: InkRoute.templates) {
            FeatureActionCard(title: "模板", systemImage: "square.grid.2x2")
          }
          NavigationLink(value: InkRoute.ai) {
            FeatureActionCard(title: "AI 生图", systemImage: "sparkles")
          }
        }
        .buttonStyle(PressFeedbackStyle())
      }
      .padding(.horizontal, 20).padding(.bottom, 28)
    }
    .background(Color.efBackground.ignoresSafeArea())
    .navigationTitle("EasyFind")
    .navigationBarTitleDisplayMode(.inline)
    .navigationDestination(for: InkRoute.self) { route in
      switch route {
      case .templates: TemplatePickerView(isCapture: false)
      case .capture: CameraCaptureScreen()
      case .ai: AIArtworkView()
      case .upload: UploadView()
      }
    }
    .onChange(of: photoItem) { _, newItem in
      guard let newItem else { return }
      Task {
        if let data = try? await newItem.loadTransferable(type: Data.self) {
          await model.importPhoto(data)
        } else {
          await MainActor.run { photoError = true }
        }
      }
    }
    .alert("无法读取这张照片，请重新选择。", isPresented: $photoError) { Button("好", role: .cancel) {} }
  }

}

struct ScreenPreview: View {
  @Environment(AppModel.self) private var model
  @State private var showsOriginal = false

  var body: some View {
    VStack(spacing: 12) {
      Picker("预览模式", selection: $showsOriginal) {
        Text("六色效果").tag(false)
        Text("原图").tag(true)
      }
      .pickerStyle(.segmented)
      Group {
        if showsOriginal {
          if let data = model.selectedPhotoData, let image = UIImage(data: data) {
            Image(uiImage: image).resizable().scaledToFill()
              .frame(width: 235, height: 235).clipped()
              .accessibilityLabel("所选图片预览")
          } else {
            ArtworkView(kind: model.artwork).frame(width: 235, height: 235)
          }
        } else if let result = model.inkArtwork.prepared {
          Image(uiImage: result.preview).resizable().interpolation(.none).scaledToFit()
            .frame(width: 235, height: 235)
            .accessibilityLabel("墨水屏效果预览")
            .accessibilityValue(
              "\(result.preview.cgImage?.width ?? 0) × \(result.preview.cgImage?.height ?? 0) 像素，六色"
            )
        } else {
          VStack(spacing: 12) {
            if model.inkArtwork.processing {
              ProgressView("正在生成六色效果…")
            } else if let error = model.inkArtwork.error {
              Text(error).font(.caption)
              Button("重新生成预览") {
                model.inkArtwork.invalidate()
                model.prepareInkArtwork()
              }
            } else {
              ProgressView()
            }
          }
          .frame(width: 235, height: 235)
        }
      }
      .padding(.top, 4)
      HStack {
        Text(showsOriginal ? "原图 · 居中裁剪" : "240 × 240 · 六色效果")
          .font(.caption).foregroundStyle(Color.efSubtext)
        Spacer()
        HStack(spacing: 5) {
          ForEach(["111111", "DDDDDD", "C54038", "E5C94B", "4C784E", "3A5890"], id: \.self) { hex in
            Circle().fill(Color(hex: hex)).frame(width: 8, height: 8)
              .overlay(Circle().stroke(Color.efSubtext.opacity(0.4), lineWidth: 0.5))
          }
        }
        .accessibilityLabel("黑白红黄绿蓝六色面板")
      }
      if !showsOriginal {
        Text("HINK 240×240 六色屏 · 实屏颜色以设备显示为准")
          .font(.caption2).foregroundStyle(Color.efSubtext)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
    .padding(15)
    .background(Color.efPaper, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.efLine))
    .task(
      id: InkArtworkController.Key(revision: model.artworkRevision, antiLost: model.ink.antiLost)
    ) {
      model.prepareInkArtwork()
    }
  }
}

struct TemplatePickerView: View {
  @Environment(AppModel.self) private var model
  @Environment(\.dismiss) private var dismiss
  let isCapture: Bool
  @State private var selection: ArtworkKind?

  var body: some View {
    ScrollView {
      VStack(spacing: 18) {
        ScreenHeader(
          title: isCapture ? "拍照" : "模板图库", subtitle: isCapture ? "拍下此刻，为屏幕添一份新意。" : "留一点空白，放一点喜欢。")
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
          ForEach(ArtworkKind.allCases) { kind in
            Button {
              selection = kind
            } label: {
              VStack(spacing: 7) {
                ArtworkView(kind: kind)
                  .overlay(
                    RoundedRectangle(cornerRadius: 5).stroke(
                      Color.efAccent, lineWidth: (selection ?? model.artwork) == kind ? 3 : 0))
                Text(kind.title).font(.subheadline.weight(.medium))
                Text(isCapture ? "取景示意" : "插画 · 六色").font(.caption).foregroundStyle(Color.efSubtext)
              }
            }
            .buttonStyle(PressFeedbackStyle()).foregroundStyle(Color.efText)
            .accessibilityAddTraits((selection ?? model.artwork) == kind ? .isSelected : [])
            .accessibilityIdentifier(kind.title)
          }
        }
        PrimaryButton(title: isCapture ? "使用这张画面" : "使用这张模板") {
          model.artwork = selection ?? model.artwork
          model.selectedPhotoData = nil
          dismiss()
        }
        if isCapture { DemoNote(text: "拍照入口使用模板展示取景与选图流程，当前不会调用摄像头。") }
      }
      .padding(22)
    }
    .background(Color.efBackground.ignoresSafeArea())
    .navigationTitle(isCapture ? "拍照" : "模板图库")
    .navigationBarTitleDisplayMode(.inline)
  }
}

struct AIArtworkView: View {
  @Environment(AppModel.self) private var model
  @Environment(\.dismiss) private var dismiss
  @State private var prompt = ""
  @FocusState private var fieldFocused: Bool

  var body: some View {
    ScrollView {
      VStack(spacing: 18) {
        ScreenHeader(title: "AI 生图", subtitle: "描述一句，想象就有了画面。")
        VStack(alignment: .leading, spacing: 10) {
          Text("画面描述").font(.caption).foregroundStyle(Color.efSubtext)
          TextField("例如：落日下的山野，安静的绿色", text: $prompt, axis: .vertical)
            .lineLimit(3...5)
            .textInputAutocapitalization(.never)
            .focused($fieldFocused)
            .padding(13)
            .background(Color.efBackground, in: RoundedRectangle(cornerRadius: 12))
            .accessibilityIdentifier("画面描述")
          Text("简洁插画 · 方形构图 · 适配六色屏").font(.caption).foregroundStyle(Color.efSubtext)
        }
        .padding(19)
        .background(Color.efPaper, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        PrimaryButton(
          title: model.generator.running ? "正在生成…" : "生成预览", systemImage: "sparkles",
          isDisabled: model.generator.running
            || prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        ) {
          fieldFocused = false
          do { model.generator.generate(prompt: prompt, api: try model.backend.client()) } catch {
            model.errorMessage = error.localizedDescription
          }
        }
        if model.generator.running { Button("取消生成") { model.generator.cancel() } }
        if let error = model.generator.error { Text(error).font(.footnote).foregroundStyle(.red) }
        NavigationLink("配置后端服务") { ServiceSettingsView() }
        if let data = model.generator.imageData, let image = UIImage(data: data) {
          Image(uiImage: image).resizable().scaledToFit().frame(maxWidth: 235)
          PrimaryButton(title: "使用这张画面") {
            Task {
              await model.importPhoto(data)
              dismiss()
            }
          }
        }
      }
      .padding(22)
    }
    .scrollDismissesKeyboard(.interactively)
    .background(Color.efBackground.ignoresSafeArea())
    .navigationTitle("AI 生图")
    .navigationBarTitleDisplayMode(.inline)
    .onDisappear { model.generator.cancel() }
  }
}

struct UploadView: View {
  @Environment(AppModel.self) private var model
  @Environment(\.dismiss) private var dismiss
  var body: some View {
    ScrollView {
      VStack(spacing: 18) {
        ScreenHeader(title: "更新屏幕", subtitle: "")
        ScreenPreview()
        Text(model.ink.selectedID.map { "目标设备：" + $0 } ?? "请先选择墨水屏")
          .font(.caption).frame(maxWidth: .infinity, alignment: .leading)
        if model.ink.busy || model.ink.phase == .accepted {
          ProgressView(value: model.ink.progress).tint(Color.efAccent)
        }
        Text(model.ink.message).font(.caption).foregroundStyle(Color.efSubtext)
        PrimaryButton(
          title: model.ink.phase == .accepted ? "完成" : model.ink.busy ? "正在上传…" : "确认上传",
          isDisabled: model.ink.phase != .accepted
            && (!model.ink.canUpload || model.inkArtwork.prepared == nil)
        ) {
          if model.ink.phase == .accepted {
            dismiss()
            return
          }
          if let image = model.inkArtwork.prepared { model.ink.upload(image) }
        }
        if model.ink.busy { Button("取消上传", role: .destructive) { model.ink.cancel() } }
        NavigationLink("选择墨水屏") { InkBindingView() }
      }.padding(22)
    }
    .background(Color.efBackground.ignoresSafeArea())
    .navigationTitle("更新屏幕").navigationBarTitleDisplayMode(.inline)
    .onAppear { model.ink.reset() }
    .onDisappear { if model.ink.busy { model.ink.cancel() } }
  }
}
