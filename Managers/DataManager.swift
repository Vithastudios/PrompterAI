import CoreData
import CloudKit

class DataManager {
    static let shared = DataManager()
    
    var onError: ((String) -> Void)?
    
    lazy var persistentContainer: NSPersistentCloudKitContainer = {
        let container = NSPersistentCloudKitContainer(name: "PrompterAI")
        
        if let description = container.persistentStoreDescriptions.first {
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            
            description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
                containerIdentifier: "iCloud.com.vithastudios.teleprompter"
            )
        }
        
        container.loadPersistentStores { [weak self] _, error in
            if let error = error {
                self?.notifyError("CoreData Load Error: \(error.localizedDescription)")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        return container
    }()
    
    func createScript(title: String, content: String, completion: ((Bool, Error?) -> Void)? = nil) {
        let context = persistentContainer.viewContext
        context.perform {
            let script = ScriptEntity(context: context)
            script.id = UUID()
            script.title = title
            script.content = content
            script.createdAt = Date()
            script.updatedAt = Date()
            script.lastPosition = 0
            script.isFavorite = false
            
            if let error = self.saveContext() {
                completion?(false, error)
            } else {
                completion?(true, nil)
            }
        }
    }
    
    func updateScript(_ script: ScriptEntity, title: String? = nil, content: String? = nil, lastPosition: Int32? = nil, isFavorite: Bool? = nil) {
        let context = persistentContainer.viewContext
        context.perform {
            if let title = title { script.title = title }
            if let content = content { script.content = content }
            if let lastPosition = lastPosition { script.lastPosition = lastPosition }
            if let isFavorite = isFavorite { script.isFavorite = isFavorite }
            script.updatedAt = Date()
            
            _ = self.saveContext()
        }
    }
    
    func fetchScripts(completion: @escaping ([ScriptEntity], Error?) -> Void) {
        let context = persistentContainer.viewContext
        let request = NSFetchRequest<ScriptEntity>(entityName: "ScriptEntity")
        request.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)]
        
        context.perform {
            do {
                let results = try request.execute()
                completion(results, nil)
            } catch {
                self.notifyError("Fetch Error: \(error.localizedDescription)")
                completion([], error)
            }
        }
    }
    
    func deleteScript(script: ScriptEntity, completion: ((Bool, Error?) -> Void)? = nil) {
        let context = persistentContainer.viewContext
        context.delete(script)
        if let error = saveContext() {
            completion?(false, error)
        } else {
            completion?(true, nil)
        }
    }
    
    @discardableResult
    func saveContext() -> Error? {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
                return nil
            } catch {
                notifyError("Save Error: \(error.localizedDescription)")
                return error
            }
        }
        return nil
    }
    
    private func notifyError(_ message: String) {
        print(message)
        onError?(message)
    }
}