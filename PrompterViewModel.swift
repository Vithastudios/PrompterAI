import Foundation
import UIKit
import AVFoundation
import Combine

@MainActor
class PrompterViewModel: ObservableObject {
    
    @Published var scriptText: String = "Toca el boton + para importar tu guion..."
    @Published var isRecording: Bool = false
    @Published var isPlaying: Bool = false
    @Published var currentSpeed: CGFloat = 0.0
    @Published var fontSize: CGFloat = 32.0
    @Published var textColor: UIColor = .white
    @Published var errorMessage: String?
    @Published var statusMessage: String?
    @Published var resolutionLabel: String = "1080p30"
    @Published var lastVideoURL: URL?
    @Published var showScriptLibrary: Bool = false
    @Published var showSettings: Bool = false
    @Published var showPaywall: Bool = false
    @Published var isPremium: Bool = false
    
    let videoEngine = VideoEngine()
    let audioEngine = AudioEngine()
    let scrollEngine = ScrollEngine()
    let neuralEngine = NeuralFlowEngine()
    let dataManager = DataManager.shared
    
    weak var textView: UITextView?
    weak var previewLayer: AVCaptureVideoPreviewLayer?
    var currentScript: ScriptEntity?
    
    var isManualDragging = false
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupBindings()
        refreshResolution()
    }
    
    func setPremium(_ enabled: Bool) {
        isPremium = enabled
        videoEngine.isPremium = enabled
        refreshResolution()
    }
    
    private func refreshResolution() {
        resolutionLabel = VideoPresetResolver.resolve(isPremium: isPremium).name
    }
    
    private func setupBindings() {
        // El closure de deteccion de palabra corre en el hilo de audio. Capturamos el
        // engine (objeto no-actor y thread-safe) directamente en vez de `self`, para no
        // tocar el MainActor desde el hilo de audio.
        let neuralEngine = self.neuralEngine
        audioEngine.onWordDetected = { word, energy in
            neuralEngine.processDetectedWord(word, energy: energy)
        }
        
        neuralEngine.onSpeedAdjustment = { [weak self] multiplier in
            guard let self = self else { return }
            
            let baseSpeed: CGFloat = 2.0
            let finalSpeed = baseSpeed * multiplier
            
            DispatchQueue.main.async {
                self.currentSpeed = finalSpeed
                if self.isPlaying && !self.isManualDragging {
                    self.scrollEngine.setSpeed(finalSpeed)
                }
            }
        }
        
        neuralEngine.onPauseDetected = { [weak self] shouldPause in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if shouldPause, self.isPlaying, !self.isManualDragging {
                    self.scrollEngine.setSpeed(0)
                } else if !shouldPause, self.isPlaying, !self.isManualDragging {
                    self.scrollEngine.setSpeed(self.currentSpeed)
                }
            }
        }
    }
    
func attachUI(textView: UITextView, previewLayer: AVCaptureVideoPreviewLayer) {
        self.textView = textView
        self.previewLayer = previewLayer
        
        videoEngine.onAudioSampleBuffer = { [weak audioEngine] sampleBuffer in
            audioEngine?.consumeSampleBuffer(sampleBuffer)
        }
        
        textView.font = UIFont.systemFont(ofSize: fontSize, weight: .semibold)
        textView.textColor = textColor
        textView.text = scriptText
        
        scrollEngine.attach(to: textView)
        
        startEngines()
    }
    
    private func startEngines() {
        guard let preview = previewLayer else { return }
        
        neuralEngine.loadScript(scriptText)
        
        videoEngine.setupCamera(previewLayer: preview) { [weak self] success in
            guard let self = self else { return }
            
            if success {
                self.audioEngine.startListening()
            } else {
                self.errorMessage = "Error al iniciar camara."
            }
        }
    }
    
    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    private func startRecording() {
        videoEngine.isPremium = isPremium
        
        let filename = "Prompter_\(Int(Date().timeIntervalSince1970)).mov"
        let outputUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)
        
        videoEngine.startRecording(outputUrl: outputUrl) { [weak self] success in
            guard let self = self else { return }
            
            if success {
                self.isRecording = true
                self.isPlaying = true
                
                let generator = UIImpactFeedbackGenerator(style: .rigid)
                generator.impactOccurred()
            } else {
                self.errorMessage = "Fallo al iniciar grabacion"
            }
        }
    }
    
    private func stopRecording() {
        videoEngine.stopRecording { [weak self] url in
            guard let self = self else { return }
            
            self.isRecording = false
            self.isPlaying = false
            self.scrollEngine.setSpeed(0)
            self.saveCurrentPosition()
            
            guard let url = url else {
                self.errorMessage = "Fallo al finalizar la grabacion"
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.error)
                return
            }
            
            let finalize: (URL, URL?) -> Void = { [weak self] finalURL, tempURL in
                guard let self = self else { return }
                VideoSaver.shared.saveToLibrary(videoURL: finalURL) { ok, message in
                    if ok {
                        self.lastVideoURL = finalURL
                        self.statusMessage = self.isPremium ? "Video guardado en tu galeria" : "Video guardado (marca de agua)"
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                        // Limpiar archivos temporales/fuente tras guardar en Fotos.
                        for urlToDelete in [tempURL, finalURL].compactMap({ $0 }) {
                            try? FileManager.default.removeItem(at: urlToDelete)
                        }
                    } else {
                        self.errorMessage = message ?? "No se pudo guardar el video."
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.error)
                    }
                }
            }
            
            if isPremium {
                finalize(url, nil)
            } else {
                // applyWatermark completa en un hilo de fondo; hay que volver a main
                // antes de tocar el MainActor (self) al finalizar.
                Watermarker.applyWatermark(to: url) { [weak self] watermarked in
                    guard let self = self else { return }
                    DispatchQueue.main.async {
                        if let watermarked = watermarked {
                            self.finalize(watermarked, url)
                        } else {
                            self.finalize(url, nil)
                        }
                    }
                }
            }
        }
    }
    
    func togglePlayPause() {
        isPlaying.toggle()
        
        if isPlaying {
            scrollEngine.setSpeed(currentSpeed)
            audioEngine.startListening()
        } else {
            scrollEngine.setSpeed(0)
            saveCurrentPosition()
        }
    }
    func didStartManualScroll() {
        isManualDragging = true
        scrollEngine.handleManualDragBegan()
    }
    
    func didEndManualScroll() {
        isManualDragging = false
        scrollEngine.handleManualDragEnded()
        
        syncReadingPosition()
        
        if isPlaying {
            scrollEngine.setSpeed(currentSpeed)
        }
    }
    
    func syncReadingPosition() {
        guard let textView = textView else { return }
        
        let visibleCenterY = textView.contentOffset.y + textView.bounds.height / 2
        let point = CGPoint(x: textView.bounds.width / 2, y: visibleCenterY)
        
        let characterIndex = textView.layoutManager.characterIndex(
            for: point,
            in: textView.textContainer,
            fractionOfDistanceBetweenInsertionPoints: nil
        )
        
        let wordIndex = wordIndex(forCharacter: characterIndex)
        neuralEngine.syncPosition(to: wordIndex)
    }
    
    private func wordIndex(forCharacter characterIndex: Int) -> Int {
        guard !scriptText.isEmpty else { return 0 }
        
        // characterIndex viene de TextKit y esta en unidades UTF-16.
        // Construimos el prefijo marginando en UTF-16 para no mezclar con graphemes.
        let trimmed = scriptText.utf16.prefix(max(0, characterIndex))
        let prefixString = String(decoding: Array(trimmed), as: UTF16.self)
        let words = prefixString.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        return max(0, words.count - 1)
    }
    
    func updateFontSize(_ size: CGFloat) {
        fontSize = size
        textView?.font = UIFont.systemFont(ofSize: size, weight: .semibold)
    }
    
    func applyFontSize(_ size: CGFloat) {
        textView?.font = UIFont.systemFont(ofSize: size, weight: .semibold)
    }
    
    func updateTextColor(_ color: UIColor) {
        textColor = color
        textView?.textColor = color
    }
    
    func updateScript(_ text: String) {
        scriptText = text
        textView?.text = text
        neuralEngine.loadScript(text)
    }
    
    func loadScriptIntoTeleprompter(_ script: ScriptEntity?) {
        // Guardar la posicion del guion anterior antes de cambiarlo.
        saveCurrentPosition()
        
        currentScript = script
        guard let text = script?.content, !text.isEmpty else { return }
        updateScript(text)
        
        // Restaurar la ultima posicion leida de este guion.
        let position = Int(script?.lastPosition ?? 0)
        restorePosition(position)
    }
    
    func saveCurrentPosition() {
        guard let script = currentScript, let textView = textView else { return }
        syncReadingPosition()
        let position = Int32(neuralEngine.readingIndex())
        if position != script.lastPosition {
            script.lastPosition = position
            dataManager.updateScript(script, lastPosition: position)
        }
    }
    
    private func restorePosition(_ wordIndex: Int) {
        guard let textView = textView, !scriptText.isEmpty else { return }
        neuralEngine.syncPosition(to: wordIndex)
        
        let words = scriptText.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        guard !words.isEmpty, wordIndex >= 0, wordIndex < words.count else { return }
        
        // Hallar el offset UTF-16 de inicio de la palabra activa para posicionar el
        // scroll en ella. TextKit usa offsets UTF-16, por eso contamos en UTF-16.
        var utf16Offset = 0
        var currentWord = 0
        let tokens = scriptText.components(separatedBy: .whitespacesAndNewlines)
        for token in tokens {
            if currentWord == wordIndex { break }
            currentWord += 1
            utf16Offset += token.utf16.count + 1
        }
        
        let bounded = min(utf16Offset, scriptText.utf16.count)
        let glyphIndex = textView.layoutManager.glyphIndexForCharacter(at: bounded)
        let rect = textView.layoutManager.boundingRect(
            forGlyphRange: NSRange(location: glyphIndex, length: 1),
            in: textView.textContainer
        )
        let targetY = max(0, rect.origin.y - textView.bounds.height / 2)
        textView.setContentOffset(CGPoint(x: 0, y: targetY), animated: false)
    }

}
