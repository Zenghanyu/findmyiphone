import AVFoundation
import SwiftUI

struct CameraCaptureScreen: View {
  @Environment(AppModel.self) private var model
  @Environment(\.dismiss) private var dismiss
  @State private var allowed = false
  @State private var checked = false
  var body: some View {
    Group {
      if allowed, UIImagePickerController.isSourceTypeAvailable(.camera) {
        CameraPicker { data in
          Task {
            await model.importPhoto(data)
            dismiss()
          }
        } cancel: {
          dismiss()
        }
      } else if checked {
        ContentUnavailableView(
          "相机不可用", systemImage: "camera", description: Text("请检查相机权限，并使用带摄像头的 iPhone。"))
      } else {
        ProgressView()
      }
    }.navigationTitle("拍照")
      .task {
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
          allowed = await AVCaptureDevice.requestAccess(for: .video)
        }
        checked = true
      }
  }
}

private struct CameraPicker: UIViewControllerRepresentable {
  let capture: (Data) -> Void
  let cancel: () -> Void
  func makeCoordinator() -> Coordinator { Coordinator(parent: self) }
  func makeUIViewController(context: Context) -> UIImagePickerController {
    let controller = UIImagePickerController()
    controller.sourceType = .camera
    controller.allowsEditing = true
    controller.delegate = context.coordinator
    return controller
  }
  func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
  final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate
  {
    let parent: CameraPicker
    init(parent: CameraPicker) { self.parent = parent }
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.cancel() }
    func imagePickerController(
      _ picker: UIImagePickerController,
      didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
      if let image = (info[.editedImage] ?? info[.originalImage]) as? UIImage,
        let data = image.jpegData(compressionQuality: 0.95)
      {
        parent.capture(data)
      }
    }
  }
}
