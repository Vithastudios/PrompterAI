import CoreData
import CloudKit

class DataManager {
    static let shared = DataManager()
    
    lazy var persistentContainer: NSPersistentCloudKitContainer = {
        let container = NSPersistentCloudKitContainer(name: "PrompterAI")
        
        if let description = container.persistentStoreDescriptions.first {
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            
            description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
                containerIdentifier: "iCloud.com.vithastudios.teleprompter"
            )
        }
        
        container.loadPersistentStores { _, error in
            if let error = error {
                print("CoreData Load Error: \(error.localizedDescription)")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        return container
    }()
    
    func createScript(title: String, content: String, completion: ((Bool) -> Void)? = nil) {
        let context = persistentContainer.viewContext
        context.perform {
            let script = ScriptEntity(context: context)
            script.id = UUID()
            script.title = title
            script.content = content
            script.createdAt = Date()
            script.lastPosition = 0
            script.isFavorite = false
            
            self.saveContext()
            completion?(true)
        }
    }
    
    func fetchScripts(completion: @escaping ([ScriptEntity]) -> Void) {
        let context = persistentContainer.viewContext
        let request = NSFetchRequest<ScriptEntity>(entityName: "ScriptEntity")
        request.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)]
        
        context.perform {
            do {
                let results = try request.execute()
                completion(results)
            } catch {
                print("Fetch Error: \(error)")
                completion([])
            }
        }
    }
    
    func deleteScript(script: ScriptEntity) {
        let context = persistentContainer.viewContext
        context.delete(script)
        saveContext()
    }
    
    func saveContext() {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Save Error: \(error)")
            }
        }
    }
}
