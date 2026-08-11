import AVFoundation
import Speech
import Accelerate

class AudioEngine: NSObject, ObservableObject {
    
    @Published var isListening: Bool = false
    @Published var currentWord: String = ""
    @Published var audioEnergy: Float = 0.0
    
    var onWordDetected: ((String, Float) -> Void)?
    var onEnergyUpdate: ((Float) -> Void)?
    
    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    private let energyThreshold: Float = 0.05
    private let maxFrameCapacity: AVAudioFrameCount = 4096
    
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
        isListening = false
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
    }
    
    func consumeSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard isListening,
              let pcm = Self.pcmBuffer(from: sampleBuffer) else { return }
        
        recognitionRequest?.append(pcm)
        processAudioBuffer(pcm)
    }
    
    private func configureRecognition() {
        guard let speechRecognizer = speechRecognizer,
              speechRecognizer.isAvailable else {
            print("SpeechRecognizer no disponible")
            return
        }
        
        recognitionTask?.cancel()
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }
        
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.addsPunctuation = true
        recognitionRequest.taskHint = .dictation
        
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
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        
        let channelDataValue = channelData.pointee
        let samples = UnsafeBufferPointer(start: channelDataValue, count: Int(buffer.frameLength))
        guard samples.isEmpty == false else { return }
        
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