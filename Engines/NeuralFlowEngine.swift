import Foundation

class NeuralFlowEngine {
    
    private let lock = NSLock()
    private(set) var scriptWords: [String] = []
    private(set) var currentIndex: Int = 0
    private var wordOffsets: [Int] = []
    private var lastWordTime: Date?
    private var pauseDuration: TimeInterval = 0.0
    private var lastDetectedWord: String?
    private var lastDetectedTimestamp: Date?
    
    var onSpeedAdjustment: ((CGFloat) -> Void)?
    var onPauseDetected: ((Bool) -> Void)?
    var onPositionChanged: ((Int) -> Void)?
    
    private let pauseThreshold: TimeInterval = 1.5
    private let searchWindowBack: Int = 10
    private let searchWindowForward: Int = 15
    private let dedupeInterval: TimeInterval = 0.6
    
    // Los metodos de este engine se invocan desde el hilo de audio (processDetectedWord)
    // y desde el hilo principal (syncPosition/loadScript/lecturas). Todas las rutas que
    // tocan estado privado se serializan con `lock` para evitar data races.
    func loadScript(_ text: String) {
        lock.lock()
        let rawTokens = text.components(separatedBy: .whitespacesAndNewlines)
        var offsets: [Int] = []
        var script: [String] = []
        var offset = 0
        for token in rawTokens {
            let trimmed = token.lowercased().trimmingCharacters(in: .punctuationCharacters)
            if !trimmed.isEmpty {
                script.append(trimmed)
                offsets.append(offset)
            }
            offset += token.utf16.count + 1
        }
        wordOffsets = offsets
        scriptWords = script
        currentIndex = 0
        lastWordTime = nil
        lastDetectedWord = nil
        lastDetectedTimestamp = nil
        pauseDuration = 0.0
        lock.unlock()
    }
    
    // Offset UTF-16 del inicio de la palabra en `wordIndex` dentro del texto original,
    // calculado con la MISMA regla de tokenizacion que `scriptWords` (para que el
    // highlight quede perfectamente sincronizado con el matching por voz).
    func characterOffset(forWordIndex wordIndex: Int) -> Int? {
        lock.lock()
        defer { lock.unlock() }
        guard wordIndex >= 0, wordIndex < wordOffsets.count else { return nil }
        return wordOffsets[wordIndex]
    }
    
    func processDetectedWord(_ word: String, energy: Float) {
        let cleanWord = word.lowercased().trimmingCharacters(in: .punctuationCharacters)
        guard !cleanWord.isEmpty else { return }
        
        lock.lock()
        if let lastWord = lastDetectedWord,
           let lastTime = lastDetectedTimestamp,
           lastWord == cleanWord,
           Date().timeIntervalSince(lastTime) < dedupeInterval {
            lock.unlock()
            return
        }
        lastDetectedWord = cleanWord
        lastDetectedTimestamp = Date()
        
        updateContextTime(for: cleanWord)
        
        let needsPause = predictPauseNeeded(for: cleanWord)
        let matchResult: (index: Int, adjustment: CGFloat)?
        if let matchIndex = findMatchIndex(for: cleanWord) {
            let distance = matchIndex - currentIndex
            let speedAdjustment = calculateSpeedAdjustment(distance: distance, energy: energy)
            currentIndex = matchIndex
            matchResult = (matchIndex, speedAdjustment)
        } else {
            matchResult = nil
        }
        lock.unlock()
        
        if let result = matchResult {
            DispatchQueue.main.async { [weak self] in
                self?.onSpeedAdjustment?(result.adjustment)
                self?.onPositionChanged?(result.index)
            }
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.onPauseDetected?(needsPause)
        }
    }
    
    func syncPosition(to index: Int) {
        lock.lock()
        guard !scriptWords.isEmpty else {
            lock.unlock()
            return
        }
        let clamped = min(max(index, 0), scriptWords.count - 1)
        let changed = clamped != currentIndex
        currentIndex = clamped
        lastDetectedWord = nil
        lastDetectedTimestamp = nil
        lock.unlock()
        
        if changed {
            DispatchQueue.main.async { [weak self] in
                self?.onPositionChanged?(clamped)
            }
        }
    }
    
    func reset() {
        lock.lock()
        currentIndex = 0
        lastWordTime = nil
        lastDetectedWord = nil
        lastDetectedTimestamp = nil
        pauseDuration = 0.0
        lock.unlock()
    }
    
    // Lectura thread-safe del indice actual (para guardar posicion desde main).
    func readingIndex() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return currentIndex
    }
    
    // Se asume con `lock` adquirido.
    private func updateContextTime(for word: String) {
        let now = Date()
        if let last = lastWordTime {
            pauseDuration = now.timeIntervalSince(last)
        }
        lastWordTime = now
    }
    
    // Se asume con `lock` adquirido.
    private func findMatchIndex(for word: String) -> Int? {
        guard !scriptWords.isEmpty else { return nil }
        
        let backStart = max(0, currentIndex - searchWindowBack)
        let forwardEnd = min(scriptWords.count, currentIndex + searchWindowForward)
        
        var bestIndex: Int?
        var bestDistance = Int.max
        
        for i in backStart..<forwardEnd {
            let distance = levenshtein(scriptWords[i], word)
            if distance <= maxDistance(for: word) && distance < bestDistance {
                bestDistance = distance
                bestIndex = i
            }
        }
        
        return bestIndex
    }
    
    private func maxDistance(for word: String) -> Int {
        switch word.count {
        case 0..<4: return 0
        case 4..<7: return 1
        default: return 2
        }
    }
    
    private func levenshtein(_ a: String, _ b: String) -> Int {
        let aChars = Array(a)
        let bChars = Array(b)
        let m = aChars.count
        let n = bChars.count
        
        if m == 0 { return n }
        if n == 0 { return m }
        
        var previous = Array(0...n)
        var current = [Int](repeating: 0, count: n + 1)
        
        for i in 1...m {
            current[0] = i
            let aChar = aChars[i - 1]
            for j in 1...n {
                let insertion = current[j - 1] + 1
                let deletion = previous[j] + 1
                let substitution = previous[j - 1] + (aChar == bChars[j - 1] ? 0 : 1)
                current[j] = min(insertion, deletion, substitution)
            }
            previous = current
        }
        
        return previous[n]
    }
    
    // Se asume con `lock` adquirido.
    private func calculateSpeedAdjustment(distance: Int, energy: Float) -> CGFloat {
        if pauseDuration > pauseThreshold {
            return 0.2
        }
        
        if energy < 0.05 {
            return 0.0
        }
        
        if distance > 3 {
            return CGFloat(min(2.0, 1.0 + (Float(distance) * 0.2)))
        } else if distance < 0 {
            return CGFloat(max(0.2, 1.0 + (Float(distance) * 0.3)))
        }
        
        return 1.0
    }
    
    // Se asume con `lock` adquirido.
    private func predictPauseNeeded(for word: String) -> Bool {
        if pauseDuration > pauseThreshold {
            return true
        }
        
        let punctuation = [".", ",", ";", ":", "!", "?"]
        return punctuation.contains { word.contains($0) }
    }
}