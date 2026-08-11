import Foundation

// Guardia de seguridad BENIGNA y compatible con las reglas de Apple.
//
// Apple penaliza el uso de APIs privadas y de tecnicas de "detencion de
// jailbreak" agresivas (p.ej. sysctl/ptrace para detectar debuggers), que
// frecuentemente provocan rechazo en App Review.
//
// Este modulo SOLO usa FileManager (API publica) para comprobar rutas de
// herramientas de jailbreak, de forma INFORMATIVA. La app NO degrada funcional,
// no bloquea compra ni usa APIs privadas, de modo que no compromete la
// aprobacion. La proteccion real anti-copia del sistema reside en:
//   - Persistencia del estado premium en Keychain (sobrevive reinstalaciones).
//   - Validacion SIEMPRE contra el entitlement de StoreKit.
//   - Privacy Manifest completo y veraz.
final class SecurityGuard {

    static let shared = SecurityGuard()
    private init() {}

    private let jailbreakPaths = [
        "/Applications/Cydia.app",
        "/Applications/Sileo.app",
        "/Library/MobileSubstrate/MobileSubstrate.dylib",
        "/usr/sbin/frida-server",
        "/etc/apt"
    ]

    // Informa de indicios de jailbreak. Solo informativo: estas huellas son
    // raras en dispositivos de produccion y casi siempre indican un entorno de
    // desarrollo, no una vulnerabilidad en la app. No se bloquea ninguna
    // funcionalidad en base a esto.
    var hasJailbreakIndicators: Bool {
        jailbreakPaths.contains { FileManager.default.fileExists(atPath: $0) }
    }
}
