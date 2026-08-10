import UIKit
import QuartzCore

class ScrollEngine {
    
    private var displayLink: CADisplayLink?
    private weak var scrollView: UIScrollView?
    
    private var currentSpeed: CGFloat = 0.0
    private var targetSpeed: CGFloat = 0.0
    private var isManualDragging: Bool = false
    
    private let smoothingFactor: CGFloat = 0.15
    private var lastTimestamp: CFTimeInterval = 0
    
    func attach(to scrollView: UIScrollView) {
        self.scrollView = scrollView
        
        displayLink = CADisplayLink(target: self, selector: #selector(updateLoop(_:)))
        displayLink?.preferredFramesPerSecond = 120
        displayLink?.add(to: .main, forMode: .common)
    }
    
    func detach() {
        displayLink?.invalidate()
        displayLink = nil
        scrollView = nil
    }
    
    func setSpeed(_ speed: CGFloat) {
        targetSpeed = speed
    }
    
    func handleManualDragBegan() {
        isManualDragging = true
        targetSpeed = 0
    }
    
    func handleManualDragEnded() {
        isManualDragging = false
        currentSpeed = 0
    }
    
    @objc private func updateLoop(_ link: CADisplayLink) {
        guard let sv = scrollView, !isManualDragging else { return }
        
        let timestamp = link.timestamp
        let deltaTime = lastTimestamp == 0 ? 1.0 / 60.0 : timestamp - lastTimestamp
        lastTimestamp = timestamp
        
        currentSpeed = currentSpeed + (targetSpeed - currentSpeed) * smoothingFactor
        
        if abs(currentSpeed) < 0.01 {
            currentSpeed = 0
            return
        }
        
        let normalizedSpeed = currentSpeed * CGFloat(deltaTime * 60.0)
        let newOffset = sv.contentOffset.y + normalizedSpeed
        
        let maxOffset = max(0, sv.contentSize.height - sv.bounds.height)
        
        if newOffset >= 0 && newOffset <= maxOffset {
            sv.contentOffset = CGPoint(x: 0, y: newOffset)
        } else if newOffset < 0 {
            sv.contentOffset = .zero
            currentSpeed = 0
            targetSpeed = 0
        } else if newOffset > maxOffset {
            sv.contentOffset = CGPoint(x: 0, y: maxOffset)
            currentSpeed = 0
            targetSpeed = 0
        }
    }
}
