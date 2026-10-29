import SwiftUI
import UIKit

struct CropImage: Identifiable {
  let id = UUID()
  let image: UIImage
}

struct PhotoCropView: View {
  let image: UIImage
  let onCancel: () -> Void
  let onComplete: (Data) -> Void

  @Environment(AppModel.self) private var model
  @State private var scale: CGFloat = 1
  @State private var lastScale: CGFloat = 1
  @State private var offset = CGSize.zero
  @State private var lastOffset = CGSize.zero
  @State private var saving = false
  @State private var error: String?

  var body: some View {
    NavigationStack {
      GeometryReader { proxy in
        let cropSide = max(1, min(proxy.size.width - 40, proxy.size.height - 175))
        VStack(spacing: 24) {
          Spacer(minLength: 8)
          cropCanvas(side: cropSide)
          Text(model.t("拖动并缩放照片", "Drag and pinch to adjust"))
            .font(.subheadline)
            .foregroundStyle(Color.efSubtext)
          Spacer(minLength: 8)
          if let error { Text(error).font(.caption).foregroundStyle(.red) }
          PrimaryButton(title: model.t("使用画面", "Use Photo"), isDisabled: saving) {
            saving = true
            Task {
              defer { saving = false }
              do {
                let data = try await PhotoRepository.cropped(
                  image, canvasSide: cropSide, zoom: scale, offset: offset)
                onComplete(data)
              } catch { self.error = error.localizedDescription }
            }
          }.accessibilityIdentifier("使用裁剪画面")
        }
        .padding(20)
      }
      .interactiveDismissDisabled(saving)
      .background(Color.efBackground.ignoresSafeArea())
      .navigationTitle(model.t("裁切照片", "Crop Photo"))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(model.t("取消", "Cancel"), action: onCancel).disabled(saving)
        }
      }
    }
  }

  private func cropCanvas(side: CGFloat) -> some View {
    let baseScale = max(side / image.size.width, side / image.size.height)
    let imageSize = CGSize(
      width: image.size.width * baseScale, height: image.size.height * baseScale)

    return ZStack {
      Color.efPaper
      Image(uiImage: image)
        .resizable()
        .frame(width: imageSize.width, height: imageSize.height)
        .scaleEffect(scale)
        .offset(offset)
        .gesture(
          DragGesture()
            .onChanged { value in
              offset = clampedOffset(
                CGSize(
                  width: lastOffset.width + value.translation.width,
                  height: lastOffset.height + value.translation.height),
                side: side,
                imageSize: imageSize
              )
            }
            .onEnded { _ in lastOffset = offset }
        )
        .gesture(
          MagnificationGesture()
            .onChanged { value in
              scale = min(4, max(1, lastScale * value))
              offset = clampedOffset(offset, side: side, imageSize: imageSize)
            }
            .onEnded { _ in
              lastScale = scale
              offset = clampedOffset(offset, side: side, imageSize: imageSize)
              lastOffset = offset
            }
        )
      CropGrid()
        .stroke(Color.white.opacity(0.6), lineWidth: 0.7)
        .allowsHitTesting(false)
      Rectangle()
        .stroke(Color.white, lineWidth: 2)
        .allowsHitTesting(false)
    }
    .frame(width: side, height: side)
    .clipped()
    .contentShape(Rectangle())
    .accessibilityLabel(model.t("照片裁切区域", "Photo crop area"))
    .accessibilityIdentifier("照片裁切区域")
    .accessibilityHint(model.t("拖动照片调整位置，双指缩放调整大小", "Drag to reposition and pinch to zoom"))
  }

  private func clampedOffset(_ proposed: CGSize, side: CGFloat, imageSize: CGSize) -> CGSize {
    let width = imageSize.width * scale
    let height = imageSize.height * scale
    let horizontalLimit = max(0, (width - side) / 2)
    let verticalLimit = max(0, (height - side) / 2)
    return CGSize(
      width: min(horizontalLimit, max(-horizontalLimit, proposed.width)),
      height: min(verticalLimit, max(-verticalLimit, proposed.height))
    )
  }

}

private struct CropGrid: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    for fraction in [1.0 / 3.0, 2.0 / 3.0] {
      path.move(to: CGPoint(x: rect.width * fraction, y: 0))
      path.addLine(to: CGPoint(x: rect.width * fraction, y: rect.height))
      path.move(to: CGPoint(x: 0, y: rect.height * fraction))
      path.addLine(to: CGPoint(x: rect.width, y: rect.height * fraction))
    }
    return path
  }
}

struct CameraCaptureView: UIViewControllerRepresentable {
  let onImage: (UIImage) -> Void
  let onCancel: () -> Void
  let onUnavailable: () -> Void

  func makeCoordinator() -> Coordinator { Coordinator(self) }

  func makeUIViewController(context: Context) -> UIImagePickerController {
    let picker = UIImagePickerController()
    picker.delegate = context.coordinator
    if UIImagePickerController.isSourceTypeAvailable(.camera) {
      picker.sourceType = .camera
      picker.cameraCaptureMode = .photo
    } else {
      DispatchQueue.main.async(execute: onUnavailable)
    }
    return picker
  }

  func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

  final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate
  {
    private let parent: CameraCaptureView

    init(_ parent: CameraCaptureView) { self.parent = parent }

    func imagePickerController(
      _ picker: UIImagePickerController,
      didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
      if let image = info[.originalImage] as? UIImage {
        parent.onImage(image)
      } else {
        parent.onCancel()
      }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
      parent.onCancel()
    }
  }
}
