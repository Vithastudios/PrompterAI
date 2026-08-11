import UIKit
import AVFoundation

class ViewController: UIViewController {
    
    let viewModel: PrompterViewModel
    let previewLayer = AVCaptureVideoPreviewLayer()
    let textView = UITextView()
    let gradientMask = CAGradientLayer()
    
    let recordButton = UIButton(type: .custom)
    let playButton = UIButton(type: .custom)
    let libraryButton = UIButton(type: .custom)
    let settingsButton = UIButton(type: .custom)
    let progressView = UIView()
    let progressFill = UIView()
    
    init(viewModel: PrompterViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) no soportado")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        connectViewModel()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = view.bounds
        gradientMask.frame = textView.bounds
    }
    
    private func setupUI() {
        view.backgroundColor = .black
        
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.insertSublayer(previewLayer, at: 0)
        
        textView.frame = view.bounds
        textView.backgroundColor = .clear
        textView.textColor = .white
        textView.textAlignment = .center
        textView.font = UIFont.systemFont(ofSize: 32, weight: .semibold)
        textView.contentInset = UIEdgeInsets(
            top: view.bounds.height / 2,
            left: 40,
            bottom: view.bounds.height / 2,
            right: 40
        )
        textView.showsVerticalScrollIndicator = false
        textView.isEditable = false
        textView.delegate = self
        
        gradientMask.colors = [
            UIColor.clear.cgColor,
            UIColor.black.cgColor,
            UIColor.black.cgColor,
            UIColor.clear.cgColor
        ]
        gradientMask.locations = [0.0, 0.1, 0.9, 1.0]
        textView.layer.mask = gradientMask
        
        view.addSubview(textView)
        
        recordButton.frame = CGRect(x: 0, y: 0, width: 70, height: 70)
        recordButton.center = CGPoint(x: view.bounds.width / 2, y: view.bounds.height - 100)
        recordButton.backgroundColor = UIColor.red.withAlphaComponent(0.8)
        recordButton.layer.cornerRadius = 35
        recordButton.addTarget(self, action: #selector(toggleRecord), for: .touchUpInside)
        view.addSubview(recordButton)
        
        playButton.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
        playButton.center = CGPoint(x: 60, y: view.bounds.height - 100)
        playButton.setTitle("Play", for: .normal)
        playButton.setTitleColor(.white, for: .normal)
        playButton.titleLabel?.font = UIFont.systemFont(ofSize: 24)
        playButton.addTarget(self, action: #selector(togglePlay), for: .touchUpInside)
        view.addSubview(playButton)
        
        libraryButton.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
        libraryButton.center = CGPoint(x: 60, y: view.bounds.height - 180)
        libraryButton.setTitle("+", for: .normal)
        libraryButton.setTitleColor(.white, for: .normal)
        libraryButton.titleLabel?.font = UIFont.systemFont(ofSize: 32)
        libraryButton.addTarget(self, action: #selector(openLibrary), for: .touchUpInside)
        view.addSubview(libraryButton)
        
        settingsButton.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
        settingsButton.center = CGPoint(x: 130, y: view.bounds.height - 180)
        settingsButton.setTitle("A", for: .normal)
        settingsButton.setTitleColor(.white, for: .normal)
        settingsButton.titleLabel?.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        settingsButton.addTarget(self, action: #selector(openSettings), for: .touchUpInside)
        view.addSubview(settingsButton)
        
        progressView.frame = CGRect(x: 0, y: view.bounds.height - 20, width: view.bounds.width, height: 2)
        progressView.backgroundColor = UIColor.white.withAlphaComponent(0.3)
        
        progressFill.frame = CGRect(x: 0, y: 0, width: 0, height: 2)
        progressFill.backgroundColor = .white
        
        progressView.addSubview(progressFill)
        view.addSubview(progressView)
    }
    
    private func connectViewModel() {
        viewModel.attachUI(textView: textView, previewLayer: previewLayer)
    }
    
    @objc private func toggleRecord() {
        viewModel.toggleRecording()
        
        UIView.animate(withDuration: 0.2) {
            self.recordButton.transform = self.viewModel.isRecording ?
                CGAffineTransform(scaleX: 0.9, y: 0.9) : .identity
        }
    }
    
    @objc private func togglePlay() {
        viewModel.togglePlayPause()
        playButton.setTitle(viewModel.isPlaying ? "Pause" : "Play", for: .normal)
    }
    
    @objc private func openLibrary() {
        viewModel.showScriptLibrary = true
    }
    
    @objc private func openSettings() {
        viewModel.showSettings = true
    }
}

extension ViewController: UITextViewDelegate {
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        viewModel.didStartManualScroll()
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            viewModel.didEndManualScroll()
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        viewModel.didEndManualScroll()
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let maxOffset = max(0, scrollView.contentSize.height - scrollView.frame.height)
        let progress = maxOffset > 0 ? scrollView.contentOffset.y / maxOffset : 0
        progressFill.frame.size.width = view.bounds.width * CGFloat(progress)
    }
}
