import AVFoundation
import Foundation

struct VideoPreset {
    let codec: AVVideoCodecType
    let width: Int
    let height: Int
    let bitRate: Int
    let frameRate: Int
    let name: String
}

enum VideoQuality {
    case ultra // 4K portrait H.265
    case high   // 1080p portrait H.265
    case medium // 1080p portrait H.264
    case low    // 720p portrait H.264
    
    // La captura usa videoRotationAngle = 90 (portrait), por lo que los
    // buffers entregados ya vienen en orientacion vertical. Las dimensiones
    // del writer deben coincidir con esos buffers (ancho/alto portrait).
    var preset: VideoPreset {
        switch self {
        case .ultra:
            return VideoPreset(codec: .hevc, width: 2160, height: 3840, bitRate: 40_000_000, frameRate: 60, name: "4K60")
        case .high:
            return VideoPreset(codec: .hevc, width: 1080, height: 1920, bitRate: 12_000_000, frameRate: 60, name: "1080p60")
        case .medium:
            return VideoPreset(codec: .h264, width: 1080, height: 1920, bitRate: 8_000_000, frameRate: 30, name: "1080p30")
        case .low:
            return VideoPreset(codec: .h264, width: 720, height: 1280, bitRate: 4_500_000, frameRate: 30, name: "720p30")
        }
    }
}

enum VideoPresetResolver {
    static func resolve(isPremium: Bool = true) -> VideoPreset {
        // Plan Free: calidad limitada (1080p30 H.264), independiente del hardware.
        guard isPremium else {
            return VideoQuality.medium.preset
        }
        
        let identifier = machineIdentifier()
        
        // Ultra 4K60: solo chips A17 Pro / A18 en adelante
        //   iPhone 15 Pro/Max = iPhone16,1 / iPhone16,2 (A17 Pro)
        //   iPhone 16 serie   = iPhone17,x (A18/A18 Pro)
        if identifier.hasPrefix("iPhone16,") || identifier.hasPrefix("iPhone17,") {
            return VideoQuality.ultra.preset
        }
        
        // High 1080p60: A15 / A16 (iPhone 13, SE3, 14)
        //   iPhone 13/13 mini/13 Pro/13 Pro Max = iPhone14,2..iPhone14,5
        //   iPhone SE 3 = iPhone14,6
        //   iPhone 14/14 Plus = iPhone14,7/iPhone14,8
        //   iPhone 14 Pro/Pro Max = iPhone15,2/iPhone15,3
        let high: [String] = [
            "iPhone14,2", "iPhone14,3", "iPhone14,4", "iPhone14,5",
            "iPhone14,6", "iPhone14,7", "iPhone14,8",
            "iPhone15,2", "iPhone15,3", "iPhone15,4", "iPhone15,5"
        ]
        if high.contains(where: { $0 == identifier }) {
            return VideoQuality.high.preset
        }
        
        // iOS 17 soporta iPhone XS (2018) en adelante -> 1080p30 H.264
        return VideoQuality.medium.preset
    }
    
    // uname().machine devuelve el identificador de hardware, p.ej. "iPhone15,2",
    // NO el nombre comercial ("iPhone15pro"). Mapear por identificador es lo correcto.
    private static func machineIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let mirror = Mirror(reflecting: systemInfo.machine)
        let identifier = mirror.children.reduce(into: "") { result, element in
            guard let value = element.value as? Int8, value != 0 else { return }
            result.append(String(UnicodeScalar(UInt8(value))))
        }
        return identifier
    }
}
