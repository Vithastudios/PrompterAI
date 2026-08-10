import AVFoundation
import UIKit

class VideoEngine: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    var captureSession: AVCaptureSession?
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var videoOutput: AVCaptureVideoDataOutput?
    
    var isRecording: Bool = false
    private var startTime: CMTime = .invalid
    
    private let sessionQueue = DispatchQueue(label: "com.vithastudios.videoSessionQueue")
    private let videoQueue = DispatchQueue(label: "com.vithastudios.videoQueue")
    
    func setupCamera(previewLayer: AVCaptureVideoPreviewLayer, completion: @escaping (Bool) -> Void) {
        sessionQueue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion(false) }
                return
            }
            
            let session = AVCaptureSession()
            session.beginConfiguration()
            session.sessionPreset = .hd4K3840x2160
            
            guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
                  let input = try? AVCaptureDeviceInput(device: camera),
                  session.canAddInput(input) else {
                DispatchQueue.main.async { completion(false) }
                return
            }
            session.addInput(input)
            
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
            
            session.commitConfiguration()
            self.captureSession = session
            self.videoOutput = videoOutput
            
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
            
            if let output = self.videoOutput,
               let connection = output.connection(with: .video),
               connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
            
            do {
                let writer = try AVAssetWriter(outputURL: outputUrl, fileType: .mov)
                
                let videoSettings: [String: Any] = [
                    AVVideoCodecKey: AVVideoCodecType.h264,
                    AVVideoWidthKey: 3840,
                    AVVideoHeightKey: 2160,
                    AVVideoCompressionPropertiesKey: [
                        AVVideoAverageBitRateKey: 50_000_000,
                        AVVideoExpectedFrameRateKey: 60
                    ]
                ]
                
                let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
                videoInput.expectsMediaDataInRealTime = true
                
                if writer.canAdd(videoInput) {
                    writer.add(videoInput)
                    self.videoInput = videoInput
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
    
    func stopRecording(completion: @escaping () -> Void) {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.isRecording = false
            self.videoInput?.markAsFinished()
            
            self.assetWriter?.finishWriting {
                self.assetWriter = nil
                self.videoInput = nil
                self.startTime = .invalid
                DispatchQueue.main.async { completion() }
            }
        }
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard isRecording,
              let videoInput = videoInput,
              videoInput.isReadyForMoreMediaData else { return }
        
        if !startTime.isValid {
            startTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            assetWriter?.startSession(atSourceTime: startTime)
        }
        
        videoInput.append(sampleBuffer)
    }
}
