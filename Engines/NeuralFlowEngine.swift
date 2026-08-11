import Foundation

class NeuralFlowEngine {
    
    private(set) var scriptWords: [String] = []
    private(set) var currentIndex: Int = 0
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
    
    func loadScript(_ text: String) {
        scriptWords = text.components(separatedBy: .whitespacesAndNewlines)
            .map { $0.lowercased().trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty }
        currentIndex = 0
        lastWordTime = nil
        lastDetectedWord = nil
        lastDetectedTimestamp = nil
        pauseDuration = 0.0
    }
    
    func processDetectedWord(_ word: String, energy: Float) {
        let cleanWord = word.lowercased().trimmingCharacters(in: .punctuationCharacters)
        guard !cleanWord.isEmpty else { return }
        
        if let lastWord = lastDetectedWord,
           let lastTime = lastDetectedTimestamp,
           lastWord == cleanWord,
           Date().timeIntervalSince(lastTime) < dedupeInterval {
            return
        }
        lastDetectedWord = cleanWord
        lastDetectedTimestamp = Date()
        
        updateContextTime(for: cleanWord)
        
        if let matchIndex = findMatchIndex(for: cleanWord) {
            updatePosition(to: matchIndex)
            
            let distance = matchIndex - currentIndex
            let speedAdjustment = calculateSpeedAdjustment(distance: distance, energy: energy)
            
            DispatchQueue.main.async { [weak self] in
                self?.onSpeedAdjustment?(speedAdjustment)
            }
        }
        
        let needsPause = predictPauseNeeded(for: cleanWord)
        DispatchQueue.main.async { [weak self] in
            self?.onPauseDetected?(needsPause)
        }
    }
    
    func syncPosition(to index: Int) {
        guard !scriptWords.isEmpty else { return }
        let clamped = min(max(index, 0), scriptWords.count - 1)
        guard clamped != currentIndex else { return }
        currentIndex = clamped
        lastDetectedWord = nil
        lastDetectedTimestamp = nil
        onPositionChanged?(clamped)
    }
    
    func reset() {
        currentIndex = 0
        lastWordTime = nil
        lastDetectedWord = nil
        lastDetectedTimestamp = nil
        pauseDuration = 0.0
    }
    
    private func updateContextTime(for word: String) {
        let now = Date()
        if let last = lastWordTime {
            pauseDuration = now.timeIntervalSince(last)
        }
        lastWordTime = now
    }
    
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
    
    private func updatePosition(to index: Int) {
        currentIndex = index
        onPositionChanged?(index)
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
    
    private func predictPauseNeeded(for word: String) -> Bool {
        if pauseDuration > pauseThreshold {
            return true
        }
        
        let punctuation = [".", ",", ";", ":", "!", "?"]
        return punctuation.contains { word.contains($0) }
    }
}