import Foundation
import Security

// Acceso simple al Keychain para persistir datos sensibles de la app.
//
// Contrario a UserDefaults, el Keychain sobrevive a la desinstalacion en la
// mayoria de casos, cifra los datos y es resistente a manipulacion simple.
// Se usa para recordar el estado premium comprado entre aperturas e incluso
// tras reinstalar la app, complementando la verificacion real de StoreKit.
final class KeychainStore {

    private let service = "com.vithastudios.teleprompter"

    static let shared = KeychainStore()
    private init() {}

    // Guarda una cadena. `accessGroup` opcional para compartir entre app y
    // extensiones (no se usa aqui).
    @discardableResult
    func set(_ value: String, forKey key: String) -> Bool {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        // Borrar un valor anterior antes de insertar el nuevo.
        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData as String] = data
        let status = SecItemAdd(attributes as CFDictionary, nil)
        return status == errSecSuccess
    }

    // Lee una cadena guardada.
    func string(forKey key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    // Elimina un valor.
    @discardableResult
    func remove(forKey key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        return SecItemDelete(query as CFDictionary) == errSecSuccess
    }
}
