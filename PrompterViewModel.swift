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
    @Published var permissionDenied: DeniedPermission?
    @Published var statusMessage: String?
    @Published var resolutionLabel: String = "1080p30"
    @Published var lastVideoURL: URL?
    @Published var showScriptLibrary: Bool = false
    @Published var showVideoLibrary: Bool = false
    @Published var showSettings: Bool = false
    @Published var showPaywall: Bool = false
    @Published var isPremium: Bool = false
    
    let videoEngine = VideoEngine()
    let audioEngine = AudioEngine()
    let scrollEngine = ScrollEngine()
    let neuralEngine = NeuralFlowEngine()
    let dataManager = DataManager.shared
    let videoLibraryManager = VideoLibraryManager.shared
    
    weak var textView: UITextView?
    weak var previewLayer: AVCaptureVideoPreviewLayer?
    var currentScript: ScriptEntity?
    
    var isManualDragging = false
    private var cancellables = Set<AnyCancellable>()
    private var activeWordIndex: Int = -1
    private var suppressCentering = false
    
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
        
        // F1: highlight de la palabra activa + sincronizacion fina. onPositionChanged
        // ya se dispara en main (ver NeuralFlowEngine).
        neuralEngine.onPositionChanged = { [weak self] index in
            guard let self = self else { return }
            self.highlightWord(at: index)
            self.keepActiveWordVisible(at: index)
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
        
        videoEngine.setupCamera(previewLayer: preview) { [weak self] success, denied in
            guard let self = self else { return }
            
            if success {
                self.audioEngine.startListening()
            } else if let denied = denied {
                self.permissionDenied = denied
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
                self.setIdleTimer(enabled: true)
                
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
            self.setIdleTimer(enabled: false)
            
            guard let url = url else {
                self.errorMessage = "Fallo al finalizar la grabacion"
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.error)
                return
            }
            
            let finalize: (URL, URL?) -> Void = { [weak self] finalURL, tempURL in
                guard let self = self else { return }
                let resolution = self.resolutionLabel
                
                // Registrar el video de forma persistente en Documents/Videos y en CoreData.
                self.videoLibraryManager.importVideo(from: finalURL, resolutionName: resolution, duration: 0.0) { storedURL, _ in
                    guard let storedURL = storedURL else {
                        self.errorMessage = "No se pudo guardar el video."
                        let gen = UINotificationFeedbackGenerator()
                        gen.notificationOccurred(.error)
                        return
                    }
                    
                    // Limpiar temporales (origen del watermark y archivo provisional).
                    for urlToDelete in [tempURL, finalURL].compactMap({ $0 })
                        where urlToDelete.standardizedFileURL != storedURL.standardizedFileURL {
                        try? FileManager.default.removeItem(at: urlToDelete)
                    }
                    
                    // Copiar a Fotos (best-effort; no borramos el archivo local, la lista
                    // de videos depende de el).
                    VideoSaver.shared.saveToLibrary(videoURL: storedURL) { ok, message in
                        self.lastVideoURL = storedURL
                        if ok {
                            self.statusMessage = self.isPremium ? "Video guardado" : "Video guardado (marca de agua)"
                        } else {
                            self.statusMessage = "Video guardado en la app"
                        }
                        let gen = UINotificationFeedbackGenerator()
                        gen.notificationOccurred(.success)
                    }
                }
            }
            
            if isPremium {
                finalize(url, nil)
            } else {
                // Plan free: si el watermark falla, NO guardar el video limpio (seria
                // regalar el contenido premium). Se muestra un error y se conserva el
                // archivo original por si el usuario quiere reintentar.
                Watermarker.applyWatermark(to: url) { [weak self] watermarked in
                    guard let self = self else { return }
                    DispatchQueue.main.async {
                        guard let watermarked = watermarked else {
                            self.errorMessage = "No se pudo procesar la marca de agua. El video original se conservo; intenta de nuevo."
                            let gen = UINotificationFeedbackGenerator()
                            gen.notificationOccurred(.error)
                            return
                        }
                        self.finalize(watermarked, url)
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
            setIdleTimer(enabled: true)
        } else {
            scrollEngine.setSpeed(0)
            saveCurrentPosition()
            setIdleTimer(enabled: false)
        }
    }
    
    // Mantiene la pantalla encendida mientras se lee/graba (clave en un
    // teleprompter) y la libera al pausar/detener para no agotar la bateria.
    private func setIdleTimer(enabled: Bool) {
        UIApplication.shared.isIdleTimerDisabled = enabled
    }
    
    func didStartManualScroll() {
        isManualDragging = true
        scrollEngine.handleManualDragBegan()
    }
    
    func didEndManualScroll() {
        isManualDragging = false
        scrollEngine.handleManualDragEnded()
        
        // Evitar que la sincronizacion fina mueva el scroll que el usuario acaba de
        // posicionar deliberadamente. El onPositionChanged (dispatch a main) llega en el
        // proximo runloop, dentro de esta ventana.
        suppressCentering = true
        syncReadingPosition()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.suppressCentering = false
        }
        
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
    
    // Devuelve el NSRange UTF-16 de la palabra en `wordIndex`. Usa el offset calculado
    // por NeuralFlowEngine (misma regla de tokenizacion) para que el highlight quede
    // perfectamente sincronizado con el matching por voz.
    private func range(ofWordAtIndex wordIndex: Int) -> NSRange? {
        guard let offset = neuralEngine.characterOffset(forWordIndex: wordIndex) else { return nil }
        let nsText = scriptText as NSString
        guard offset < nsText.length else { return nil }
        
        let endOfWord = nsText.rangeOfCharacter(
            from: .whitespacesAndNewlines,
            options: [],
            range: NSRange(location: offset, length: nsText.length - offset)
        )
        let end = endOfWord.location == NSNotFound ? nsText.length : endOfWord.location
        let length = end - offset
        guard length > 0 else { return nil }
        return NSRange(location: offset, length: length)
    }
    
    // F1: resalta la palabra activa usando temporary attributes (sin re-renderizar
    // todo el texto). Se limpia el resaltado previo y se aplica el nuevo.
    private func highlightWord(at index: Int) {
        guard let textView = textView, index != activeWordIndex else { return }
        
        let layoutManager = textView.layoutManager
        let wasHighlighted = activeWordIndex >= 0
        
        // Limpiar el resaltado previo.
        if wasHighlighted, let old = range(ofWordAtIndex: activeWordIndex) {
            layoutManager.removeTemporaryAttribute(.backgroundColor, forCharacterRange: old)
        }
        
        // Aplicar el nuevo resaltado.
        if let current = range(ofWordAtIndex: index) {
            layoutManager.addTemporaryAttribute(.backgroundColor, value: UIColor.systemYellow.withAlphaComponent(0.45), forCharacterRange: current)
        } else if wasHighlighted {
            // Palabra nueva no localizada: al menos dejamos limpio el anterior.
            layoutManager.invalidateDisplay(forCharacterRange: NSRange(location: 0, length: (scriptText as NSString).length))
        }
        
        activeWordIndex = index
    }
    
    // F1: sincronizacion fina — mantiene la palabra activa cerca del centro vertical,
    // con scroll suave. Solo reposiciona cuando NO se esta reproduciendo (modo lectura /
    // pausa) y cuando el cambio de posicion NO vino de un scroll manual del usuario
    // (para no mover lo que el usuario dejo posicionado deliberadamente).
    private func keepActiveWordVisible(at index: Int) {
        guard let textView = textView, !isManualDragging, !isPlaying, !suppressCentering else { return }
        
        guard let range = range(ofWordAtIndex: index) else { return }
        let glyphIndex = textView.layoutManager.glyphIndexForCharacter(at: range.location)
        let rect = textView.layoutManager.boundingRect(
            forGlyphRange: NSRange(location: glyphIndex, length: range.length),
            in: textView.textContainer
        )
        
        let targetCenter = rect.midY
        let viewportCenter = textView.contentOffset.y + textView.bounds.height / 2
        let threshold: CGFloat = 40
        
        // Solo reposicionar si se alejo del centro para no causar saltos bruscos.
        if abs(targetCenter - viewportCenter) > threshold {
            let targetOffset = max(0, rect.midY - textView.bounds.height / 2)
            let maxOffset = max(0, textView.contentSize.height - textView.bounds.height)
            let clamped = min(targetOffset, maxOffset)
            UIView.animate(withDuration: 0.25, animations: {
                textView.setContentOffset(CGPoint(x: 0, y: clamped), animated: false)
            })
        }
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
        // Limpiar resaltado previo (temporary attributes) al cambiar de guion.
        if let textView = textView {
            textView.layoutManager.removeTemporaryAttribute(.backgroundColor, forCharacterRange: NSRange(location: 0, length: (scriptText as NSString).length))
        }
        activeWordIndex = -1
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
        
        // onPositionChanged se dispara de forma asincrona desde syncPosition; mantenemos
        // suppressCentering activo unos ms para que el auto-centrado no pele con el scroll
        // exacto que hacemos aqui al cargar el guion.
        suppressCentering = true
        neuralEngine.syncPosition(to: wordIndex)
        
        guard let range = range(ofWordAtIndex: wordIndex) else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                self?.suppressCentering = false
            }
            return
        }
        let glyphIndex = textView.layoutManager.glyphIndexForCharacter(at: range.location)
        let rect = textView.layoutManager.boundingRect(
            forGlyphRange: NSRange(location: glyphIndex, length: range.length),
            in: textView.textContainer
        )
        let targetY = max(0, rect.origin.y - textView.bounds.height / 2)
        textView.setContentOffset(CGPoint(x: 0, y: targetY), animated: false)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.suppressCentering = false
        }
    }

}
