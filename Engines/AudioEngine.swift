import AVFoundation
import Speech
import Accelerate

class AudioEngine: NSObject, ObservableObject {
    
    @Published var isListening: Bool = false
    @Published var currentWord: String = ""
    @Published var audioEnergy: Float = 0.0
    
    var onWordDetected: ((String, Float) -> Void)?
    var onEnergyUpdate: ((Float) -> Void)?
    
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    private let energyThreshold: Float = 0.05
    private let maxFrameCapacity: AVAudioFrameCount = 4096
    private let lock = NSLock()
    private var noiseFloor: Float = 0.02
    private let noiseFloorSmoothing: Float = 0.05
    
    @Published var currentLocaleIdentifier: String = "es-ES"
    
    override init() {
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "es-ES"))
        super.init()
    }
    
    func updateLocale(_ identifier: String) {
        let newRecognizer = SFSpeechRecognizer(locale: Locale(identifier: identifier))
        guard newRecognizer?.isAvailable == true else { return }
        
        lock.lock()
        isListening = false
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        speechRecognizer = newRecognizer
        lock.unlock()
        
        DispatchQueue.main.async { [weak self] in
            self?.currentLocaleIdentifier = identifier
        }
    }
    
    deinit {
        stopListening()
    }
    
    func startListening() {
        lock.lock()
        let alreadyListening = isListening
        lock.unlock()
        guard !alreadyListening else { return }
        
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                guard status == .authorized else {
                    print("Permiso de voz denegado")
                    return
                }
                self?.configureRecognition()
            }
        }
    }
    
    func stopListening() {
        lock.lock()
        isListening = false
        let task = recognitionTask
        recognitionTask = nil
        recognitionRequest = nil
        lock.unlock()
        
        task?.cancel()
    }
    
    func consumeSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        let pcm = Self.pcmBuffer(from: sampleBuffer)
        
        lock.lock()
        let isActive = isListening
        let request = recognitionRequest
        lock.unlock()
        
        guard isActive, let pcm = pcm else { return }
        
        request?.append(pcm)
        processAudioBuffer(pcm)
    }
    
    private func configureRecognition() {
        guard let speechRecognizer = speechRecognizer,
              speechRecognizer.isAvailable else {
            print("SpeechRecognizer no disponible")
            return
        }
        
        lock.lock()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        let request = recognitionRequest
        lock.unlock()
        
        guard let request = request else { return }
        
        request.shouldReportPartialResults = true
        request.addsPunctuation = true
        request.taskHint = .dictation
        
        lock.lock()
        isListening = true
        let task = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            if let result = result {
                let spokenText = result.bestTranscription.formattedString
                DispatchQueue.main.async {
                    self?.handleSpeechResult(spokenText)
                }
            }
            
            if error != nil || (result?.isFinal ?? false) {
                self?.stopListening()
            }
        }
        recognitionTask = task
        lock.unlock()
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        
        let channelDataValue = channelData.pointee
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return }
        
        let squared = UnsafeMutablePointer<Float>.allocate(capacity: frameLength)
        defer { squared.deallocate() }
        
        var sum: Float = 0.0
        vDSP_vsq(channelDataValue, 1, squared, 1, vDSP_Length(frameLength))
        vDSP_sve(squared, 1, &sum, vDSP_Length(frameLength))
        
        let rms = sqrt(sum / Float(frameLength))
        
        // Calibracion adaptativa: mantiene un piso de ruido en movimiento
        // para que hablar bajito siga siendo detectado.
        if rms < noiseFloor {
            noiseFloor = noiseFloor * (1 - noiseFloorSmoothing) + rms * noiseFloorSmoothing
        } else {
            noiseFloor = noiseFloor * (1 - noiseFloorSmoothing * 0.5) + rms * noiseFloorSmoothing * 0.5
        }
        
        let gain: Float = 10.0
        let raw = min(rms * gain, 1.0)
        // Brillo relativo por encima del piso de ruido, con tope en 1.0
        let normalizedEnergy = min(max((rms - noiseFloor) / max(noiseFloor, 0.01) * 1.5, 0.0), 1.0)
        let combined = max(raw, normalizedEnergy)
        
        DispatchQueue.main.async { [weak self] in
            self?.audioEnergy = combined
            self?.onEnergyUpdate?(combined)
        }
    }
    
    private func handleSpeechResult(_ text: String) {
        let words = text.components(separatedBy: .whitespacesAndNewlines)
            .map { $0.lowercased() }
            .filter { !$0.isEmpty }
        
        guard let lastWord = words.last, audioEnergy > energyThreshold else { return }
        
        currentWord = lastWord
        onWordDetected?(lastWord, audioEnergy)
    }
    
    private static func pcmBuffer(from sampleBuffer: CMSampleBuffer) -> AVAudioPCMBuffer? {
        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer),
              let format = AVAudioFormat(cmAudioFormatDescription: formatDescription) else {
            return nil
        }
        
        let frameCount = AVAudioFrameCount(CMSampleBufferGetNumSamples(sampleBuffer))
        guard frameCount > 0 else { return nil }
        
        guard let pcm = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return nil
        }
        pcm.frameLength = frameCount
        
        var blockBuffer: CMBlockBuffer?
        let status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: nil,
            bufferListOut: pcm.mutableAudioBufferList,
            bufferListSize: MemoryLayout<AudioBufferList>.size,
            blockBufferAllocator: kCFAllocatorDefault,
            blockBufferMemoryAllocator: kCFAllocatorDefault,
            blockBufferOut: &blockBuffer
        )
        
        return status == noErr ? pcm : nil
    }
}