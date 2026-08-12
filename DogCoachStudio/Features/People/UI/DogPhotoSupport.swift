import SwiftUI
import UIKit

enum DogPhotoStore {
    private static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appending(path: "DogPhotos", directoryHint: .isDirectory)
    }

    static func save(_ data: Data) throws -> String {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let id = UUID().uuidString + ".jpg"
        try data.write(to: directory.appending(path: id), options: .atomic)
        return id
    }

    static func url(for id: String) -> URL { directory.appending(path: id) }

    static func remove(_ id: String) {
        try? FileManager.default.removeItem(at: url(for: id))
    }
}

struct DogPhotoView: View {
    let assetID: String?
    let size: CGFloat

    var body: some View {
        Group {
            if let assetID, let image = UIImage(contentsOfFile: DogPhotoStore.url(for: assetID).path()) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Image(systemName: "dog.fill").resizable().scaledToFit().padding(size * 0.22).foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .background(.quaternary)
        .clipShape(.circle)
        .accessibilityHidden(true)
    }
}

struct CameraCaptureView: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onCapture: onCapture) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controller = UIImagePickerController()
        controller.sourceType = .camera
        controller.cameraCaptureMode = .photo
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onCapture: (UIImage) -> Void
        init(onCapture: @escaping (UIImage) -> Void) { self.onCapture = onCapture }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { onCapture(image) }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { picker.dismiss(animated: true) }
    }
}
