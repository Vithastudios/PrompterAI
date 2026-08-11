import Photos
import Foundation

class VideoSaver {
    static let shared = VideoSaver()
    
    func saveToLibrary(videoURL: URL, completion: @escaping (Bool, String?) -> Void) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async {
                    completion(false, "Permiso de fotos denegado. Activalo en Ajustes.")
                }
                return
            }
            
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)
            }) { success, error in
                DispatchQueue.main.async {
                    if success {
                        completion(true, nil)
                    } else {
                        completion(false, error?.localizedDescription ?? "No se pudo guardar el video.")
                    }
                }
            }
        }
    }
}
