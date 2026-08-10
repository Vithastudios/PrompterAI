import AVFoundation
import Speech
import Accelerate
import Combine

class AudioEngine: NSObject, ObservableObject {
    
    @Published var isListening: Bool = false
    @Published var currentWord: String = ""
    @Published var audioEnergy: Float = 0.0
    
    var onWordDetected: ((String, Float) -> Void)?
    var onEnergyUpdate: ((Float) -> Void)?
    
    private let audioEngine = AVAudioEngine()
    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    private let bufferSize: AVAudioFrameCount = 1024
    private let energyThreshold: Float = 0.05
    
    override init() {
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "es-ES"))
        super.init()
    }
    
    deinit {
        stopListening()
    }
    
    func startListening() {
        guard !isListening else { return }
        
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            guard status == .authorized else {
                print("Permiso de voz denegado")
                return
            }
            DispatchQueue.main.async {
                self?.setupAudioSession()
                self?.startRecognition()
            }
        }
    }
    
    func stopListening() {
        isListening = false
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
    }
    
    private func setupAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: [.duckOthers])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Error AudioSession: \(error.localizedDescription)")
        }
    }
    
    private func startRecognition() {
        guard let speechRecognizer = speechRecognizer,
              speechRecognizer.isAvailable else {
            print("SpeechRecognizer no disponible")
            return
        }
        
        recognitionTask?.cancel()
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }
        
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.addsPunctuation = false
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
            self?.processAudioBuffer(buffer)
        }
        
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
            isListening = true
            
            recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
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
        } catch {
            print("Error iniciando reconocimiento: \(error.localizedDescription)")
            stopListening()
        }
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        
        let channelDataValue = channelData.pointee
        let samples = UnsafeBufferPointer(start: channelDataValue, count: Int(buffer.frameLength))
        
        var sum: Float = 0.0
        vDSP_vsq(samples.baseAddress!, 1, samples.baseAddress!, 1, vDSP_Length(samples.count))
        vDSP_sve(samples.baseAddress!, 1, &sum, vDSP_Length(samples.count))
        
        let rms = sqrt(sum / Float(samples.count))
        let normalizedEnergy = min(rms * 10.0, 1.0)
        
        DispatchQueue.main.async { [weak self] in
            self?.audioEnergy = normalizedEnergy
            self?.onEnergyUpdate?(normalizedEnergy)
        }
    }
    
    private func handleSpeechResult(_ text: String) {
        let words = text.components(separatedBy: .whitespacesAndNewlines)
            .map { $0.lowercased().trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty }
        
        guard let lastWord = words.last, audioEnergy > energyThreshold else { return }
        
        currentWord = lastWord
        onWordDetected?(lastWord, audioEnergy)
    }
}
