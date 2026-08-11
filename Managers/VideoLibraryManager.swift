import Foundation
import CoreData
import AVFoundation

// Gestiona el registro persistente de los videos grabados por el usuario y el
// acceso a los archivos .mov guardados en Documents/Videos.
class VideoLibraryManager {
    static let shared = VideoLibraryManager()
    
    private let dataManager = DataManager.shared
    
    var onError: ((String) -> Void)?
    
    func videosDirectory() -> URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("Videos", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    
    func fileName(withExtension ext: String = "mov") -> String {
        return "Prompter_\(Int(Date().timeIntervalSince1970)).\(ext)"
    }
    
    // Mueve el archivo de origen a Documents/Videos con un nombre persistente y
    // registra la metadata en CoreData. Devuelve la URL final.
    func importVideo(from sourceURL: URL, resolutionName: String, duration: TimeInterval = 0, completion: @escaping (URL?, Error?) -> Void) {
        let dest = videosDirectory().appendingPathComponent(fileName())
        do {
            try FileManager.default.moveItem(at: sourceURL, to: dest)
        } catch {
            // Fallback: si no se pudo mover (p.ej. cruce de volumen), copiar.
            do {
                try FileManager.default.copyItem(at: sourceURL, to: dest)
                try? FileManager.default.removeItem(at: sourceURL)
            } catch {
                completion(nil, error)
                return
            }
        }
        
        let effectiveDuration = duration > 0 ? duration : self.assetDuration(at: dest)
        saveRecord(fileURL: dest, resolutionName: resolutionName, duration: effectiveDuration)
        completion(dest, nil)
    }
    
    private func assetDuration(at url: URL) -> TimeInterval {
        let asset = AVURLAsset(url: url)
        return CMTimeGetSeconds(asset.duration)
    }
    
    private func saveRecord(fileURL: URL, resolutionName: String, duration: TimeInterval) {
        let context = dataManager.persistentContainer.viewContext
        context.perform { [weak self] in
            let entity = VideoEntity(context: context)
            entity.id = UUID()
            entity.filename = fileURL.lastPathComponent
            entity.createdAt = Date()
            entity.duration = duration
            entity.resolutionName = resolutionName
            entity.fileURL = fileURL.path
            
            if let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
               let sizeNumber = attrs[.size] as? NSNumber {
                entity.fileSize = sizeNumber.int64Value
            } else {
                entity.fileSize = 0
            }
            
            _ = self?.dataManager.saveContext()
        }
    }
    
    func fetchVideos(completion: @escaping ([VideoEntity]) -> Void) {
        let context = dataManager.persistentContainer.viewContext
        let request = NSFetchRequest<VideoEntity>(entityName: "VideoEntity")
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        
        context.perform {
            do {
                let results = try request.execute()
                completion(results)
            } catch {
                self.onError?("Error al cargar videos: \(error.localizedDescription)")
                completion([])
            }
        }
    }
    
    func deleteVideo(_ video: VideoEntity) {
        let context = dataManager.persistentContainer.viewContext
        if let path = video.fileURL, FileManager.default.fileExists(atPath: path) {
            try? FileManager.default.removeItem(atPath: path)
        }
        context.delete(video)
        _ = dataManager.saveContext()
    }
    
    func url(for video: VideoEntity) -> URL? {
        guard let path = video.fileURL else { return nil }
        let url = URL(fileURLWithPath: path)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
}
