import SwiftUI
import PhotosUI

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
                    HStack { Image(systemName: "arrow.up.from.line"); Text("上传画面") }
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
                    NavigationLink(value: InkRoute.capture) { FeatureActionCard(title: "拍照", systemImage: "camera") }
                    NavigationLink(value: InkRoute.templates) { FeatureActionCard(title: "模板", systemImage: "square.grid.2x2") }
                    NavigationLink(value: InkRoute.ai) { FeatureActionCard(title: "AI 生图", systemImage: "sparkles") }
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
            case .capture: TemplatePickerView(isCapture: true)
            case .ai: AIArtworkView()
            case .upload: UploadView()
            }
        }
        .onChange(of: photoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    await MainActor.run { model.selectedPhotoData = data }
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

    var body: some View {
        VStack(spacing: 12) {
            Group {
                if let data = model.selectedPhotoData, let image = UIImage(data: data) {
                    Image(uiImage: image).resizable().scaledToFill()
                        .frame(maxWidth: 235).frame(height: 235).clipped()
                        .accessibilityLabel("所选图片预览")
                } else {
                    ArtworkView(kind: model.artwork).frame(maxWidth: 235)
                }
            }
            .padding(.top, 4)
            HStack {
                Text(model.selectedPhotoData == nil ? model.artwork.shortTitle : "所选图片")
                    .font(.caption).foregroundStyle(Color.efSubtext)
                Spacer()
                HStack(spacing: 5) {
                    ForEach(["111111", "555555", "999999", "DDDDDD"], id: \.self) { hex in
                        Circle().fill(Color(hex: hex)).frame(width: 8, height: 8)
                    }
                }
                .accessibilityLabel("黑白灰面板")
            }
        }
        .padding(15)
        .background(Color.efPaper, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.efLine))
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
                ScreenHeader(title: isCapture ? "拍照" : "模板图库", subtitle: isCapture ? "拍下此刻，为屏幕添一份新意。" : "留一点空白，放一点喜欢。")
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(ArtworkKind.allCases) { kind in
                        Button { selection = kind } label: {
                            VStack(spacing: 7) {
                                ArtworkView(kind: kind)
                                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.efAccent, lineWidth: (selection ?? model.artwork) == kind ? 3 : 0))
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
    @State private var result: ArtworkKind?
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
                PrimaryButton(title: "生成预览", systemImage: "sparkles", isDisabled: prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                    fieldFocused = false
                    if prompt.range(of: "花|植物|flower", options: .regularExpression) != nil { result = .bloom }
                    else if prompt.range(of: "城市|建筑|city", options: .regularExpression) != nil { result = .city }
                    else { result = .mountain }
                }
                if let result {
                    VStack(spacing: 12) {
                        ArtworkView(kind: result).frame(maxWidth: 235)
                        Text("本地风格效果示意，未调用生成模型").font(.caption).foregroundStyle(Color.efSubtext)
                    }
                    .padding(16).frame(maxWidth: .infinity)
                    .background(Color.efPaper, in: RoundedRectangle(cornerRadius: 12))
                    PrimaryButton(title: "使用这张画面") {
                        model.artwork = result
                        model.selectedPhotoData = nil
                        dismiss()
                    }
                }
            }
            .padding(22)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.efBackground.ignoresSafeArea())
        .navigationTitle("AI 生图")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct UploadView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var progress = 0
    @State private var isUploading = false
    @State private var uploadTask: Task<Void, Never>?

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                ScreenHeader(title: "更新屏幕", subtitle: "把这一张喜欢，带在身边。")
                ScreenPreview()
                ConnectedLabel().frame(maxWidth: .infinity, alignment: .leading)
                ProgressView(value: Double(progress), total: 100).tint(Color.efAccent)
                    .accessibilityValue("\(progress)%")
                Text(progress == 100 ? "屏幕已更新 · 效果演示" : isUploading ? "正在更新 · \(progress)%" : "准备就绪")
                    .font(.caption).foregroundStyle(Color.efSubtext).frame(maxWidth: .infinity)
                PrimaryButton(title: progress == 100 ? "完成" : isUploading ? "正在上传…" : "确认上传", isDisabled: isUploading) {
                    if progress == 100 { dismiss() } else { startUpload() }
                }
                DemoNote(text: "上传进度仅演示界面状态，不会向实体设备传输数据。")
            }
            .padding(22)
        }
        .background(Color.efBackground.ignoresSafeArea())
        .navigationTitle("更新屏幕")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            uploadTask?.cancel()
            uploadTask = nil
            isUploading = false
        }
    }

    private func startUpload() {
        isUploading = true
        progress = 0
        uploadTask = Task { @MainActor in
            while progress < 100 && !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(120))
                guard !Task.isCancelled else { return }
                progress = min(100, progress + 10)
            }
            isUploading = false
        }
    }
}
