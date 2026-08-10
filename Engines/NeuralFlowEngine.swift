import Foundation

class NeuralFlowEngine {
    
    private var scriptWords: [String] = []
    private var currentIndex: Int = 0
    private var contextWindow: [String] = []
    private var lastWordTime: Date?
    private var pauseDuration: TimeInterval = 0.0
    
    var onSpeedAdjustment: ((CGFloat) -> Void)?
    var onPauseDetected: ((Bool) -> Void)?
    
    private let pauseThreshold: TimeInterval = 1.5
    
    func loadScript(_ text: String) {
        scriptWords = text.components(separatedBy: .whitespacesAndNewlines)
            .map { $0.lowercased().trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty }
        currentIndex = 0
        contextWindow.removeAll()
    }
    
    func processDetectedWord(_ word: String, energy: Float) {
        updateContext(with: word)
        
        if let matchIndex = findMatchIndex(for: word) {
            let distance = matchIndex - currentIndex
            let speedAdjustment = calculateSpeedAdjustment(distance: distance, energy: energy)
            
            DispatchQueue.main.async { [weak self] in
                self?.onSpeedAdjustment?(speedAdjustment)
            }
            
            if energy > 0.3 {
                currentIndex = matchIndex
            }
        }
        
        let needsPause = predictPauseNeeded(for: word)
        onPauseDetected?(needsPause)
    }
    
    func reset() {
        currentIndex = 0
        contextWindow.removeAll()
        lastWordTime = nil
        pauseDuration = 0.0
    }
    
    private func updateContext(with word: String) {
        contextWindow.append(word.lowercased())
        if contextWindow.count > 5 {
            contextWindow.removeFirst()
        }
        
        let now = Date()
        if let last = lastWordTime {
            pauseDuration = now.timeIntervalSince(last)
        }
        lastWordTime = now
    }
    
    private func findMatchIndex(for word: String) -> Int? {
        let target = word.lowercased().trimmingCharacters(in: .punctuationCharacters)
        let searchRange = currentIndex..<min(currentIndex + 10, scriptWords.count)
        
        for i in searchRange {
            if scriptWords[i] == target {
                return i
            }
        }
        return nil
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
        let punctuation = [".", ",", ";", ":", "!", "?"]
        return punctuation.contains { word.contains($0) }
    }
}
