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
    
    let videoEngine = VideoEngine()
    let audioEngine = AudioEngine()
    let scrollEngine = ScrollEngine()
    let neuralEngine = NeuralFlowEngine()
    let dataManager = DataManager.shared
    
    weak var textView: UITextView?
    weak var previewLayer: AVCaptureVideoPreviewLayer?
    
    var isManualDragging = false
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupBindings()
    }
    
    private func setupBindings() {
        audioEngine.onWordDetected = { [weak self] word, energy in
            guard let self = self else { return }
            self.neuralEngine.processDetectedWord(word, energy: energy)
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
        videoEngine.stopRecording { [weak self] in
            guard let self = self else { return }
            
            self.isRecording = false
            self.isPlaying = false
            self.scrollEngine.setSpeed(0)
            
let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }
    }
    
    func togglePlayPause() {
        isPlaying.toggle()
        
        if isPlaying {
            scrollEngine.setSpeed(currentSpeed)
            audioEngine.startListening()
        } else {
            scrollEngine.setSpeed(0)
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
        
        let prefix = String(scriptText.prefix(characterIndex))
        let words = prefix.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        return max(0, words.count - 1)
    }
    
    func updateFontSize(_ size: CGFloat) {
        fontSize = size
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
}
