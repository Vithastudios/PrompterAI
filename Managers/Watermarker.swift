import AVFoundation
import UIKit

struct Watermarker {
    static func applyWatermark(to sourceURL: URL,
                               text: String = "Prompter AI",
                               completion: @escaping (URL?) -> Void) {
        
        let asset = AVURLAsset(url: sourceURL)
        guard let track = asset.tracks(withMediaType: .video).first else {
            completion(nil)
            return
        }
        
        let videoSize = track.naturalSize.applying(track.preferredTransform)
        let renderSize = CGSize(width: abs(videoSize.width), height: abs(videoSize.height))
        guard renderSize.width > 0, renderSize.height > 0 else {
            completion(nil)
            return
        }
        
        let fps = 30
        let composition = AVMutableVideoComposition()
        composition.renderSize = renderSize
        composition.frameDuration = CMTime(value: 1, timescale: CMTimeScale(fps))
        
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: asset.duration)
        
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
        let transform = videoTransform(for: track, renderSize: renderSize)
        layerInstruction.setTransform(transform, at: .zero)
        instruction.layerInstructions = [layerInstruction]
        composition.instructions = [instruction]
        
        // Capa de marca de agua
        let margin: CGFloat = 24
        let fontSize: CGFloat = 28
        let textLayer = CATextLayer()
        textLayer.string = text
        textLayer.fontSize = fontSize
        textLayer.foregroundColor = UIColor.white.withAlphaComponent(0.75).cgColor
        textLayer.shadowColor = UIColor.black.cgColor
        textLayer.shadowOpacity = 0.8
        textLayer.shadowOffset = CGSize(width: 0, height: -1)
        textLayer.shadowRadius = 2
        textLayer.alignmentMode = .center
        textLayer.contentsScale = UIScreen.main.scale
        
        let maxWidth = renderSize.width - margin * 2
        let textSize = (text as NSString).size(withAttributes: [
            .font: UIFont.systemFont(ofSize: fontSize)
        ])
        let width = min(maxWidth, textSize.width + 20)
        
        let parentLayer = CALayer()
        parentLayer.frame = CGRect(origin: .zero, size: renderSize)
        parentLayer.backgroundColor = UIColor.clear.cgColor
        
        let videoLayer = CALayer()
        videoLayer.frame = CGRect(origin: .zero, size: renderSize)
        
        textLayer.frame = CGRect(
            x: (renderSize.width - width) / 2,
            y: renderSize.height - fontSize - margin,
            width: width,
            height: fontSize + 12
        )
        
        parentLayer.addSublayer(videoLayer)
        parentLayer.addSublayer(textLayer)
        
        composition.animationTool = AVVideoCompositionCoreAnimationTool(
            postProcessingAsVideoLayer: videoLayer,
            in: parentLayer
        )
        
        guard let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
            completion(nil)
            return
        }
        
        exporter.videoComposition = composition
        exporter.outputFileType = .mov
        
        let dir = FileManager.default.temporaryDirectory
        let filename = "watermarked_\(Int(Date().timeIntervalSince1970)).mov"
        let outputURL = dir.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: outputURL)
        exporter.outputURL = outputURL
        
        exporter.exportAsynchronously {
            switch exporter.status {
            case .completed:
                completion(outputURL)
            default:
                completion(nil)
            }
        }
    }
    
    private static func videoTransform(for track: AVAssetTrack, renderSize: CGSize) -> CGAffineTransform {
        let natural = track.naturalSize.applying(track.preferredTransform)
        let x = (renderSize.width - abs(natural.width)) / 2
        let y = (renderSize.height - abs(natural.height)) / 2
        return track.preferredTransform.translatedBy(x: x, y: y)
    }
}
