import AVFoundation
import PhotosUI
import SwiftUI

struct InkView: View {
  @Environment(AppModel.self) private var model
  @State private var photoItem: PhotosPickerItem?
  @State private var photoError = false
  @State private var cameraError = false
  @State private var showCamera = false
  @State private var cropImage: CropImage?
  @State private var pendingCameraImage: UIImage?
  @State private var loadingPhoto = false

  var body: some View {
    GeometryReader { proxy in
      let imageSide = min(170, max(110, proxy.size.height * 0.22))
      let photosTitle = model.t("相册", "Photos")
      ScrollView {
        VStack(spacing: 12) {
          ScreenHeader(title: model.t("显示", "Display"), subtitle: "")
          ScreenPreview(imageSide: imageSide)
          VStack(spacing: 9) {
            PhotosPicker(selection: $photoItem, matching: .images) {
              DisplayActionRow(title: photosTitle, systemImage: "photo.on.rectangle")
            }
            .buttonStyle(PressFeedbackStyle())
            .accessibilityIdentifier("相册")
            .disabled(loadingPhoto)
            Button {
              Task {
                guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
                  cameraError = true
                  return
                }
                guard await AVCaptureDevice.requestAccess(for: .video) else {
                  cameraError = true
                  return
                }
                showCamera = true
              }
            } label: {
              DisplayActionRow(title: model.t("拍照", "Camera"), systemImage: "camera")
            }
            .accessibilityIdentifier("拍照入口")
            .disabled(loadingPhoto)
            NavigationLink(value: InkRoute.templates) {
              DisplayActionRow(title: model.t("模板", "Templates"), systemImage: "square.grid.2x2")
            }
          }
          .buttonStyle(PressFeedbackStyle())
          NavigationLink(value: InkRoute.upload) {
            HStack {
              Image(systemName: "arrow.up.from.line")
              Text(model.t("上传画面", "Upload to display"))
            }
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(Color.efAccent, in: RoundedRectangle(cornerRadius: 16))
            .foregroundStyle(Color.efOnAccent)
          }
          .buttonStyle(PressFeedbackStyle())
          .accessibilityIdentifier("上传到墨水屏")
          Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity)
      }
    }
    .background(Color.efBackground.ignoresSafeArea())
    .navigationTitle("EasyFind")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      if model.selectedPhotoData != nil {
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            if let data = model.selectedPhotoData, let image = UIImage(data: data) {
              cropImage = CropImage(image: image)
            }
          } label: {
            Image(systemName: "crop")
          }
          .accessibilityLabel(model.t("裁剪图片", "Crop image")).accessibilityIdentifier("裁剪图片")
        }
      }
    }
    .navigationDestination(for: InkRoute.self) { route in
      switch route {
      case .templates: TemplatePickerView()
      case .upload: UploadView()
      case .ai: AIArtworkView()
      case .capture: CameraCaptureScreen()
      }
    }
    .onChange(of: photoItem) { _, newItem in
      guard let newItem, !loadingPhoto else { return }
      loadingPhoto = true
      Task {
        defer {
          loadingPhoto = false
          photoItem = nil
        }
        if let data = try? await newItem.loadTransferable(type: Data.self),
          let normalized = try? await PhotoRepository.normalized(data),
          let image = UIImage(data: normalized)
        {
          cropImage = CropImage(image: image)
        } else {
          await MainActor.run { photoError = true }
        }
      }
    }
    .onChange(of: showCamera) { _, isPresented in
      guard !isPresented, let pendingCameraImage else { return }
      self.pendingCameraImage = nil
      Task {
        do {
          cropImage = CropImage(image: try await PhotoRepository.normalized(pendingCameraImage))
        } catch { model.errorMessage = error.localizedDescription }
      }
    }
    .fullScreenCover(isPresented: $showCamera) {
      CameraCaptureView(
        onImage: { image in
          pendingCameraImage = image
          showCamera = false
        },
        onCancel: { showCamera = false },
        onUnavailable: {
          showCamera = false
          cameraError = true
        }
      )
      .ignoresSafeArea()
    }
    .fullScreenCover(item: $cropImage) { source in
      PhotoCropView(
        image: source.image,
        onCancel: { cropImage = nil },
        onComplete: { data in
          model.selectedPhotoData = data
          cropImage = nil
        }
      )
    }
    .alert(
      model.t("无法读取这张照片，请重新选择。", "This photo couldn’t be read. Please choose another."),
      isPresented: $photoError
    ) {
      Button(model.t("好", "OK"), role: .cancel) {}
    }
    .alert(model.t("此设备无法使用相机", "Camera unavailable on this device"), isPresented: $cameraError) {
      Button(model.t("好", "OK"), role: .cancel) {}
    }
  }
}

private struct DisplayActionRow: View {
  let title: String
  let systemImage: String

  var body: some View {
    HStack(spacing: 16) {
      Image(systemName: systemImage)
        .font(.system(size: 25, weight: .regular))
        .frame(width: 44, height: 44)
        .background(Color.efTint, in: RoundedRectangle(cornerRadius: 13))
      Text(title)
        .font(.system(size: 16, weight: .medium))
      Spacer()
    }
    .foregroundStyle(Color.efText)
    .padding(.horizontal, 16)
    .frame(maxWidth: .infinity, minHeight: 62)
    .background(Color.efPaper, in: RoundedRectangle(cornerRadius: 17))
    .overlay(RoundedRectangle(cornerRadius: 17).stroke(Color.efLine.opacity(0.65)))
    .contentShape(RoundedRectangle(cornerRadius: 17))
  }
}

struct ScreenPreview: View {
  @Environment(AppModel.self) private var model
  @State private var showsOriginal = false
  var imageSide: CGFloat = 235

  var body: some View {
    VStack(spacing: 12) {
      Picker(model.t("预览模式", "Preview mode"), selection: $showsOriginal) {
        Text(model.t("六色效果", "Six colors")).tag(false)
        Text(model.t("原图", "Original")).tag(true)
      }
      .pickerStyle(.segmented)
      Group {
        if showsOriginal {
          if let data = model.selectedPhotoData, let image = UIImage(data: data) {
            Image(uiImage: image).resizable().scaledToFill()
              .frame(width: imageSide, height: imageSide).clipped()
              .accessibilityLabel(model.t("所选图片预览", "Selected photo preview"))
              .accessibilityIdentifier("所选图片预览")
          } else {
            ArtworkView(kind: model.artwork).frame(width: imageSide, height: imageSide)
          }
        } else if let result = model.inkArtwork.prepared {
          Image(uiImage: result.preview).resizable().interpolation(.none).scaledToFit()
            .frame(width: imageSide, height: imageSide)
            .accessibilityLabel(model.t("墨水屏效果预览", "Ink display preview"))
            .accessibilityIdentifier("墨水屏效果预览")
            .accessibilityValue(
              model.t(
                "\(result.preview.cgImage?.width ?? 0) × \(result.preview.cgImage?.height ?? 0) 像素，六色",
                "\(result.preview.cgImage?.width ?? 0) × \(result.preview.cgImage?.height ?? 0) pixels, six colors"
              )
            )
        } else {
          VStack(spacing: 12) {
            if model.inkArtwork.processing {
              ProgressView(model.t("正在生成六色效果…", "Preparing six-color preview…"))
            } else if let error = model.inkArtwork.error {
              Text(error).font(.caption)
              Button(model.t("重新生成预览", "Retry preview")) {
                model.inkArtwork.invalidate()
                model.prepareInkArtwork()
              }
            } else {
              ProgressView()
            }
          }
          .frame(width: imageSide, height: imageSide)
        }
      }
      .padding(.top, 4)
      HStack {
        Text(
          showsOriginal
            ? model.t("原图 · 居中裁剪", "Original · square crop")
            : model.t("240 × 240 · 六色效果", "240 × 240 · Six colors")
        )
        .font(.caption).foregroundStyle(Color.efSubtext)
        Spacer()
        HStack(spacing: 5) {
          ForEach(["111111", "DDDDDD", "C54038", "E5C94B", "4C784E", "3A5890"], id: \.self) { hex in
            Circle().fill(Color(hex: hex)).frame(width: 8, height: 8)
              .overlay(Circle().stroke(Color.efSubtext.opacity(0.4), lineWidth: 0.5))
          }
        }
        .accessibilityLabel(
          model.t("黑白红黄绿蓝六色面板", "Black, white, red, yellow, green and blue panel"))
      }
      if !showsOriginal {
        Text(model.t("HINK 六色屏 · 实屏颜色以设备为准", "HINK six colors · Actual colors may vary"))
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
  @State private var selection: ArtworkKind?

  var body: some View {
    ScrollView {
      VStack(spacing: 18) {
        ScreenHeader(title: model.t("模板图库", "Templates"), subtitle: "")
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
                Text(model.t(kind.title, kind.englishTitle)).font(.subheadline.weight(.medium))
              }
            }
            .buttonStyle(PressFeedbackStyle()).foregroundStyle(Color.efText)
            .accessibilityAddTraits((selection ?? model.artwork) == kind ? .isSelected : [])
            .accessibilityIdentifier(kind.title)
          }
        }
        PrimaryButton(title: model.t("使用画面", "Use Image")) {
          model.artwork = selection ?? model.artwork
          model.selectedPhotoData = nil
          dismiss()
        }.accessibilityIdentifier("使用这张模板")
      }
      .padding(22)
    }
    .background(Color.efBackground.ignoresSafeArea())
    .navigationTitle(model.t("模板图库", "Templates"))
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        NavigationLink(model.t("AI 生图", "AI image"), value: InkRoute.ai).accessibilityIdentifier(
          "AI 生图")
      }
    }
  }
}

struct UploadView: View {
  @Environment(AppModel.self) private var model
  @Environment(\.dismiss) private var dismiss
  var body: some View {
    ScrollView {
      VStack(spacing: 18) {
        ScreenHeader(title: model.t("更新屏幕", "Update display"), subtitle: "")
        ScreenPreview()
        Text(
          model.ink.selectedID.map { model.t("目标设备：", "Display: ") + $0 }
            ?? model.t("请先选择墨水屏", "Select an ink display first")
        )
        .font(.caption).frame(maxWidth: .infinity, alignment: .leading)
        if model.ink.busy || model.ink.phase == .accepted {
          ProgressView(value: model.ink.progress).tint(Color.efAccent)
        }
        Text(model.ink.message).font(.caption).foregroundStyle(Color.efSubtext)
        PrimaryButton(
          title: model.ink.phase == .accepted
            ? model.t("完成", "Done")
            : model.ink.busy ? model.t("正在上传…", "Uploading…") : model.t("确认上传", "Confirm upload"),
          isDisabled: model.ink.phase != .accepted
            && (!model.ink.canUpload || model.inkArtwork.prepared == nil)
        ) {
          if model.ink.phase == .accepted {
            dismiss()
            return
          }
          if let image = model.inkArtwork.prepared { model.ink.upload(image) }
        }
        if model.ink.busy {
          Button(model.t("取消上传", "Cancel upload"), role: .destructive) { model.ink.cancel() }
        }
        NavigationLink(model.t("选择墨水屏", "Select ink display")) { InkBindingView() }
      }.padding(22)
    }
    .background(Color.efBackground.ignoresSafeArea())
    .navigationTitle(model.t("更新屏幕", "Update display")).navigationBarTitleDisplayMode(.inline)
    .onAppear { model.ink.reset() }
    .onDisappear { if model.ink.busy { model.ink.cancel() } }
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
        ScreenHeader(title: model.t("AI 生图", "AI Image"), subtitle: "")
        VStack(alignment: .leading, spacing: 10) {
          Text(model.t("画面描述", "Image description")).font(.caption).foregroundStyle(Color.efSubtext)
          TextField(
            model.t("例如：落日下的山野，安静的绿色", "e.g. Quiet green hills at sunset"), text: $prompt,
            axis: .vertical
          )
          .lineLimit(3...5)
          .textInputAutocapitalization(.never)
          .focused($fieldFocused)
          .padding(13)
          .background(Color.efBackground, in: RoundedRectangle(cornerRadius: 12))
          .accessibilityIdentifier("画面描述")
          Text(
            model.t("简洁插画 · 方形构图 · 适配六色屏", "Simple illustration · Square composition · Six colors")
          ).font(.caption).foregroundStyle(Color.efSubtext)
        }
        .padding(19)
        .background(Color.efPaper, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        PrimaryButton(
          title: model.generator.running
            ? model.t("正在生成…", "Generating…") : model.t("生成预览", "Generate preview"),
          systemImage: "sparkles",
          isDisabled: model.generator.running
            || prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        ) {
          fieldFocused = false
          do { model.generator.generate(prompt: prompt, api: try model.backend.client()) } catch {
            model.errorMessage = error.localizedDescription
          }
        }
        if model.generator.running {
          Button(model.t("取消生成", "Cancel generation")) { model.generator.cancel() }
        }
        if let error = model.generator.error { Text(error).font(.footnote).foregroundStyle(.red) }
        NavigationLink(model.t("配置后端服务", "Backend settings")) { ServiceSettingsView() }
        if let data = model.generator.imageData, let image = UIImage(data: data) {
          Image(uiImage: image).resizable().scaledToFit().frame(maxWidth: 235)
          PrimaryButton(title: model.t("使用这张画面", "Use image")) {
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
    .navigationTitle(model.t("AI 生图", "AI Image"))
    .navigationBarTitleDisplayMode(.inline)
    .onDisappear { model.generator.cancel() }
  }
}
