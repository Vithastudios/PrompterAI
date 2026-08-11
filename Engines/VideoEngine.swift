import AVFoundation
import UIKit

class VideoEngine: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    
    var captureSession: AVCaptureSession?
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var videoOutput: AVCaptureVideoDataOutput?
    private var audioOutput: AVCaptureAudioDataOutput?
    
    var onAudioSampleBuffer: ((CMSampleBuffer) -> Void)?
    var isRecording: Bool = false
    var isPremium: Bool = true
    private(set) var lastOutputURL: URL?
    private var startTime: CMTime = .invalid
    
    private let sessionQueue = DispatchQueue(label: "com.vithastudios.videoSessionQueue")
    private let videoQueue = DispatchQueue(label: "com.vithastudios.videoQueue")
    private let audioQueue = DispatchQueue(label: "com.vithastudios.audioQueue")
    private let writerLock = NSLock()
    
    func setupCamera(previewLayer: AVCaptureVideoPreviewLayer, completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .video) { videoGranted in
            guard videoGranted else {
                DispatchQueue.main.async { completion(false) }
                return
            }
            AVCaptureDevice.requestAccess(for: .audio) { audioGranted in
                guard audioGranted else {
                    DispatchQueue.main.async { completion(false) }
                    return
                }
                self.configureSession(previewLayer: previewLayer, completion: completion)
            }
        }
    }
    
    private func currentPreset() -> VideoPreset {
        VideoPresetResolver.resolve(isPremium: isPremium)
    }
    
    private func capturePreset() -> AVCaptureSession.Preset {
        let preset = currentPreset()
        let longestSide = max(preset.width, preset.height)
        if longestSide >= 3840 {
            return .hd4K3840x2160
        } else if longestSide >= 1920 {
            return .hd1920x1080
        } else {
            return .hd1280x720
        }
    }
    
    private func configureSession(previewLayer: AVCaptureVideoPreviewLayer, completion: @escaping (Bool) -> Void) {
        sessionQueue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion(false) }
                return
            }
            
            let session = AVCaptureSession()
            session.beginConfiguration()
            session.sessionPreset = self.capturePreset()
            
            let audioSession = AVAudioSession.sharedInstance()
            do {
                try audioSession.setCategory(.playAndRecord, mode: .videoRecording, options: [.defaultToSpeaker, .allowBluetoothHFP])
                try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            } catch {
                DispatchQueue.main.async { completion(false) }
                return
            }
            
            guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
                  let videoDeviceInput = try? AVCaptureDeviceInput(device: camera),
                  session.canAddInput(videoDeviceInput) else {
                DispatchQueue.main.async { completion(false) }
                return
            }
            session.addInput(videoDeviceInput)
            
            DispatchQueue.main.async {
                previewLayer.session = session
                previewLayer.videoGravity = .resizeAspectFill
            }
            
            let videoOutput = AVCaptureVideoDataOutput()
            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.setSampleBufferDelegate(self, queue: self.videoQueue)
            
            if session.canAddOutput(videoOutput) {
                session.addOutput(videoOutput)
            }
            
            if let connection = videoOutput.connection(with: .video) {
                if connection.isVideoRotationAngleSupported(90) {
                    connection.videoRotationAngle = 90
                }
                if connection.isVideoMirroringSupported {
                    connection.isVideoMirrored = true
                }
            }
            
            if let mic = AVCaptureDevice.default(.builtInMicrophone, for: .audio, position: .unspecified),
               let audioDeviceInput = try? AVCaptureDeviceInput(device: mic),
               session.canAddInput(audioDeviceInput) {
                session.addInput(audioDeviceInput)
            }
            
            let audioOutput = AVCaptureAudioDataOutput()
            audioOutput.setSampleBufferDelegate(self, queue: self.audioQueue)
            
            if session.canAddOutput(audioOutput) {
                session.addOutput(audioOutput)
            }
            
            session.commitConfiguration()
            self.captureSession = session
            self.videoOutput = videoOutput
            self.audioOutput = audioOutput
            
            session.startRunning()
            DispatchQueue.main.async { completion(true) }
        }
    }
    
    func startRecording(outputUrl: URL, completion: @escaping (Bool) -> Void) {
        sessionQueue.async { [weak self] in
            guard let self = self,
                  let session = self.captureSession,
                  session.isRunning else {
                DispatchQueue.main.async { completion(false) }
                return
            }
            
            self.lastOutputURL = outputUrl
            
            let targetPreset = self.capturePreset()
            if session.sessionPreset != targetPreset {
                session.stopRunning()
                session.beginConfiguration()
                session.sessionPreset = targetPreset
                session.commitConfiguration()
                session.startRunning()
            }
            
            if let output = self.videoOutput,
               let connection = output.connection(with: .video),
               connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
            
            do {
                let writer = try AVAssetWriter(outputURL: outputUrl, fileType: .mov)
                
                let preset = currentPreset()
                
                let videoSettings: [String: Any] = [
                    AVVideoCodecKey: preset.codec,
                    AVVideoWidthKey: preset.width,
                    AVVideoHeightKey: preset.height,
                    AVVideoCompressionPropertiesKey: [
                        AVVideoAverageBitRateKey: preset.bitRate,
                        AVVideoExpectedSourceFrameRateKey: preset.frameRate
                    ]
                ]
                
                let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
                videoInput.expectsMediaDataInRealTime = true
                
                let audioSettings: [String: Any] = [
                    AVFormatIDKey: kAudioFormatMPEG4AAC,
                    AVSampleRateKey: 44_100,
                    AVNumberOfChannelsKey: 2,
                    AVEncoderBitRateKey: 128_000
                ]
                
                let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
                audioInput.expectsMediaDataInRealTime = true
                
                if writer.canAdd(videoInput) {
                    writer.add(videoInput)
                    self.videoInput = videoInput
                }
                if writer.canAdd(audioInput) {
                    writer.add(audioInput)
                    self.audioInput = audioInput
                }
                
                self.assetWriter = writer
                self.isRecording = true
                self.startTime = .invalid
                
                writer.startWriting()
                DispatchQueue.main.async { completion(true) }
                
            } catch {
                print("Error iniciando grabacion: \(error.localizedDescription)")
                DispatchQueue.main.async { completion(false) }
            }
        }
    }
    
    func stopRecording(completion: @escaping (URL?) -> Void) {
        sessionQueue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            writerLock.lock()
            self.isRecording = false
            self.videoInput?.markAsFinished()
            self.audioInput?.markAsFinished()
            let writer = self.assetWriter
            let url = self.lastOutputURL
            writerLock.unlock()
            
            writer?.finishWriting {
                let finished = writer?.status == .completed
                writerLock.lock()
                self.assetWriter = nil
                self.videoInput = nil
                self.audioInput = nil
                self.startTime = .invalid
                writerLock.unlock()
                DispatchQueue.main.async { completion(finished ? url : nil) }
            }
        }
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if output === self.audioOutput {
            // El reconocimiento de voz siempre recibe el audio (funciona aun sin grabar).
            self.onAudioSampleBuffer?(sampleBuffer)
            
            writerLock.lock()
            let shouldAppend = isRecording && audioInput?.isReadyForMoreMediaData == true
            let target = audioInput
            writerLock.unlock()
            
            guard shouldAppend, let target = target else { return }
            
            beginSessionIfNeeded(with: sampleBuffer)
            target.append(sampleBuffer)
            return
        }
        
        writerLock.lock()
        let shouldAppend = isRecording && videoInput?.isReadyForMoreMediaData == true
        let target = videoInput
        writerLock.unlock()
        
        guard shouldAppend, let target = target else { return }
        
        beginSessionIfNeeded(with: sampleBuffer)
        target.append(sampleBuffer)
    }
    
    private func beginSessionIfNeeded(with sampleBuffer: CMSampleBuffer) {
        guard !startTime.isValid, let assetWriter = assetWriter else { return }
        startTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        assetWriter.startSession(atSourceTime: startTime)
    }
}