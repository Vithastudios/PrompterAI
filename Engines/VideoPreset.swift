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
    case ultra // 4K60 H.265
    case high   // 1080p60 H.265
    case medium // 1080p30 H.264
    case low    // 720p30 H.264
    
    var preset: VideoPreset {
        switch self {
        case .ultra:
            return VideoPreset(codec: .hevc, width: 3840, height: 2160, bitRate: 40_000_000, frameRate: 60, name: "4K60")
        case .high:
            return VideoPreset(codec: .hevc, width: 1920, height: 1080, bitRate: 12_000_000, frameRate: 60, name: "1080p60")
        case .medium:
            return VideoPreset(codec: .h264, width: 1920, height: 1080, bitRate: 8_000_000, frameRate: 30, name: "1080p30")
        case .low:
            return VideoPreset(codec: .h264, width: 1280, height: 720, bitRate: 4_500_000, frameRate: 30, name: "720p30")
        }
    }
}

enum VideoPresetResolver {
    static func resolve() -> VideoPreset {
        let machine = machineName().lowercased()
        
        // Ultra 4K60: solo los chips A17 Pro / A18 en adelante
        let ultra: [String] = ["iphone15pro", "iphone16"]
        if ultra.contains(where: { machine.hasPrefix($0) }) {
            return VideoQuality.ultra.preset
        }
        
        // High 1080p60: A15 / A16 (iPhone 13 y 14)
        let high: [String] = [
            "iphone13", "iphone14",
            "iphonese3"
        ]
        if high.contains(where: { machine.hasPrefix($0) }) {
            return VideoQuality.high.preset
        }
        
        // iOS 17 soporta iPhone XS (2018) en adelante -> 1080p30 H.264
        return VideoQuality.medium.preset
    }
    
    private static func machineName() -> String {
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
