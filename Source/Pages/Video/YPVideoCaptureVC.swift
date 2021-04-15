//
//  YPVideoVC.swift
//  YPImgePicker
//
//  Created by Sacha Durand Saint Omer on 27/10/16.
//  Copyright © 2016 Yummypets. All rights reserved.
//

import UIKit
import DPVideoMerger_Swift
import AMPopTip
import AVFoundation

public class YPVideoCaptureVC: UIViewController, YPPermissionCheckable {
    
    public var didCaptureVideo: ((URL) -> Void)?
    public var didShowCancelAlert: ((Bool) -> Void)?
    
    private let videoHelper = YPVideoCaptureHelper()
//    private let v = YPCameraView(overlayView: nil)
    private let v = KooVideoView()
    private var viewState = ViewState()
    var videoUrlPath = ""
    var recordTime = 0.0
    var saveButtonPressed = false
    var previewButtonPressed = false
    var videoCaptured = false
    let popTip = PopTip()
    let toolTipDuration = 3.0
    var showIndicatorAdded = false
    public var screenWidth: CGFloat {
        return UIScreen.main.bounds.width
    }
    // MARK: - Init
    
    public required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    public required init() {
        super.init(nibName: nil, bundle: nil)
        title = YPConfig.wordings.videoTitle
        self.popTip.textColor = UIColor(red: 252/255, green: 210/255, blue: 82/255, alpha: 1)
        self.popTip.bubbleColor = #colorLiteral(red: 0.2604471743, green: 0.2539715469, blue: 0.2975891531, alpha: 1)
        self.popTip.shouldDismissOnTap = true
        videoHelper.didCaptureVideo = { [weak self] videoURL in
//            self?.didCaptureVideo?(videoURL)
            guard let weakSelf = self else { return  }
            print(videoURL.path)
            var createPath = FileManager.default.createKooCreateVideoPath()
            do{
                try FileManager.default.moveItem(at: videoURL, to: URL(fileURLWithPath: createPath))
            }catch{
                createPath = videoURL.path
            }
            print(createPath)
            if weakSelf.videoUrlPath == ""{
                weakSelf.videoCaptured = true
                weakSelf.videoUrlPath = createPath
                let secoundsGreaterThan3Secs = weakSelf.recordTime < YPConfig.video.minimumTimeLimit
                weakSelf.v.previewView.isHidden = secoundsGreaterThan3Secs
                if weakSelf.recordTime == YPConfig.video.recordingTimeLimit {
                    DispatchQueue.main.async {
                        weakSelf.previewButtonTapped()
                        weakSelf.updateState {
                            $0.isRecording = false
                            $0.isPaused = true
                        }
                    }
                }
                if weakSelf.saveButtonPressed {
                    weakSelf.didCaptureVideo?(URL(fileURLWithPath: weakSelf.videoUrlPath))
                }
                if weakSelf.previewButtonPressed{
                    weakSelf.openEditController()
                }
            }else{
                let oldURL = URL(fileURLWithPath: weakSelf.videoUrlPath)
                let newURL = URL(fileURLWithPath: createPath)
                DPVideoMerger().mergeVideos(withFileURLs: [oldURL,newURL]) { [weak self] (url, error) in
                    guard let weakSelf = self else { return  }
                    if error == nil{
                        if let mergedURL = url{
                            weakSelf.videoCaptured = true
                            weakSelf.videoUrlPath = mergedURL.path
                            let secoundsGreaterThan3Secs = weakSelf.recordTime < YPConfig.video.minimumTimeLimit
                            weakSelf.v.previewView.isHidden = secoundsGreaterThan3Secs
                            if weakSelf.recordTime == YPConfig.video.recordingTimeLimit {
                                DispatchQueue.main.async {
                                    weakSelf.previewButtonTapped()
                                    weakSelf.updateState {
                                        $0.isRecording = false
                                        $0.isPaused = true
                                    }
                                }
                            }
                            if weakSelf.saveButtonPressed {
                                weakSelf.didCaptureVideo?(URL(fileURLWithPath: weakSelf.videoUrlPath))
                            }
                            if weakSelf.previewButtonPressed{
                                weakSelf.openEditController()
                            }
                        }
                        
                    }
                }
            }
//            self?.videoUrlPath = videoURL.path
//            self?.resetVisualState()
        }
        videoHelper.videoRecordingProgress = { [weak self] progress, timeElapsed in
            if let showIndicator = self?.showIndicatorAdded, showIndicator {
                self?.showIndicatorAdded = false
                NotificationCenter.default.post(name: NSNotification.Name("hideIndicator"), object: nil)
                self?.v.shotButton.isUserInteractionEnabled = true
            }
            self?.recordTime = (self?.recordTime ?? 0.0) + 1.0
            print("recording time :: \(self!.recordTime)")
            print("recording progress :: \(progress)")
            self?.updateState {
                $0.progress = progress
                $0.timeElapsed = timeElapsed
            }
        }
    }
    
    // MARK: - View LifeCycle
    
    override public func loadView() { view = v }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        v.timeElapsedLabel.isHidden = false // Show the time elapsed label since we're in the video screen.
        setupButtons()
        linkButtons()
        
        // Focus
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(focusTapped(_:)))
        v.previewViewContainer.addGestureRecognizer(tapRecognizer)
        
        // Zoom
        let pinchRecongizer = UIPinchGestureRecognizer(target: self, action: #selector(self.pinch(_:)))
        v.previewViewContainer.addGestureRecognizer(pinchRecongizer)
//        NotificationCenter.default.addObserver(self, selector: #selector(recordVideo), name: .kooVideoResume, object: nil)
//        NotificationCenter.default.addObserver(self, selector: #selector(pauseVideo), name: .kooVideoCancel, object: nil)
    }
//    @objc func recordVideo(){
//
//    }
//    @objc func pauseVideo(){
//
//    }
    func start() {
        v.shotButton.isEnabled = false
        self.videoCaptured = false
        self.saveButtonPressed = false
        checkPermissionToAccessVideo { (granted) in
            if granted{
                self.videoHelper.start(previewView: self.v.previewViewContainer,
                                        withVideoRecordingLimit: YPConfig.video.recordingTimeLimit,
                                        completion: {
                                            DispatchQueue.main.async {
                                                self.v.shotButton.isEnabled = true
                                                self.refreshState()
                                            }
                })
            }else{
                let alertController = UIAlertController(title: "Koo does not have access to your Camera/Microphone.To enable access, tap Settings and turn on Camera and Microphone.", message: "", preferredStyle: .alert)
                       let action = UIAlertAction(title: "Cancel", style: .cancel) { (action) in
                        
                        self.dismiss(animated: true) {
                            self.didCaptureVideo?(URL(fileURLWithPath: ""))
                        }
                       }
                       let settingsAction = UIAlertAction(title: "Settings", style: .default) { (action) in
                           if let redirectURL = URL(string:UIApplication.openSettingsURLString ){
                               if UIApplication.shared.canOpenURL(redirectURL) {
                                   UIApplication.shared.open(redirectURL)
                               }else{
                                   self.dismiss(animated: true, completion: nil)
                               }
                           }else{
                               self.dismiss(animated: true, completion: nil)
                           }
                           
                       }
                       alertController.addAction(action)
                       alertController.addAction(settingsAction)
                       self.present(alertController, animated: true, completion: nil)
            }
        }
//        doAfterPermissionCheck { [weak self] in
//            guard let strongSelf = self else {
//                return
//            }
//
//        }
    }
    
    func refreshState() {
        // Init view state with video helper's state
        if UserDefaults.standard.value(forKey: "recording_button_coachmark") == nil {
            popTip.show(text: "recording_button_coachmark".localized, direction: .up, maxWidth: screenWidth, in: v.bottomView, from: v.shotButton.frame,duration: toolTipDuration)
            UserDefaults.standard.set("Yes", forKey: "recording_button_coachmark")
            UserDefaults.standard.synchronize()
        }
        updateState {
            $0.isRecording = self.videoHelper.isRecording
            $0.flashMode = self.flashModeFrom(videoHelper: self.videoHelper)
        }
    }
    
    // MARK: - Setup
    
    private func setupButtons() {
        v.flashButton.setImage(YPConfig.icons.flashOffIcon, for: .normal)
        v.flipButton.setImage(YPConfig.icons.loopIcon, for: .normal)
//        v.shotButton.setImage(YPConfig.icons.captureVideoImage, for: .normal)
    }
    
    private func linkButtons() {
        v.flashButton.addTarget(self, action: #selector(flashButtonTapped), for: .touchUpInside)
        v.shotButton.addTarget(self, action: #selector(shotButtonTapped), for: .touchUpInside)
        v.retryButton.addTarget(self, action: #selector(retryButtonTapped), for: .touchUpInside)
        v.previewButton.addTarget(self, action: #selector(previewButtonTapped), for: .touchUpInside)
        v.flipButton.addTarget(self, action: #selector(flipButtonTapped), for: .touchUpInside)
        v.saveButton.addTarget(self, action: #selector(saveButtonTapped), for: .touchUpInside)
        
    }
    
    // MARK: - Save Video
    
    @objc
    func saveButtonTapped() {
        saveButtonPressed = true
        if videoHelper.isRecording {
            self.shotButtonTapped()
            if self.videoCaptured{
                self.didCaptureVideo?(URL(fileURLWithPath: self.videoUrlPath))
            }else{
                //self.showIndicator(withTitle: "", and: "")
                NotificationCenter.default.post(name: NSNotification.Name("showIndicator"), object: nil)
            }
        }else{
            if self.videoCaptured{
                self.didCaptureVideo?(URL(fileURLWithPath: self.videoUrlPath))
            }else{
               // self.showIndicator(withTitle: "", and: "")
                NotificationCenter.default.post(name: NSNotification.Name("showIndicator"), object: nil)
            }
        }
        
    }
    // MARK: - Retry Video
    
    @objc
    func retryButtonTapped() {
         if videoHelper.isRecording {
                   self.shotButtonTapped()
               }
        let alert = UIAlertController(title: "Koo", message: "confirm_leave_recording_screen".localized, preferredStyle: .alert)
        let noAction = UIAlertAction(title: "resume_recording".localized, style: .default) { (action) in
            alert.dismiss(animated: true, completion: nil)
                self.shotButtonTapped()
        }
        let yesAction = UIAlertAction(title: "yes".localized, style: .default) { (action) in
            alert.dismiss(animated: true, completion: nil)
            self.resetVisualState()
            
        }
        alert.addAction(yesAction)
        alert.addAction(noAction)
        self.present(alert, animated: true, completion: nil)
    }
    // MARK: - Preview Video
    
    @objc
    func previewButtonTapped() {
        self.previewButtonPressed = true
        if videoHelper.isRecording {
                   self.shotButtonTapped()
               }
        if self.videoCaptured{
            self.openEditController()
        }else{
           // self.showIndicator(withTitle: "", and: "")
           NotificationCenter.default.post(name: NSNotification.Name("showIndicator"), object: nil)
        }
    }
    //MARK: - Open Preview
    func openEditController(){
        guard UIVideoEditorController.canEditVideo(atPath: self.videoUrlPath) else {
            print("Can't edit video at \(self.videoUrlPath)")
            return
        }
        
        //                let originalAsset = AVAsset(url:  URL(fileURLWithPath: self.videoUrlPath))
        print("Presenting video editor...")
        let vc = UIVideoEditorController()
        vc.videoPath = self.videoUrlPath
        let asset = AVAsset(url: URL(fileURLWithPath: self.videoUrlPath))
        let secoundsInInt = asset.duration.seconds
        var duration = 60.0
        if secoundsInInt > duration {
            duration = asset.duration.seconds
        }
        vc.videoMaximumDuration = duration
        vc.videoQuality = UIImagePickerController.QualityType.typeMedium
        vc.delegate = self
        vc.modalPresentationStyle = .overFullScreen
        NotificationCenter.default.post(name: NSNotification.Name("hideIndicator"), object: nil)
        self.present(vc, animated: true, completion: nil)
       // self.hideIndicator()
    }
    // MARK: - Flip Camera
    
    @objc
    func flipButtonTapped() {
        doAfterPermissionCheck { [weak self] in
            self?.flip()
        }
    }
    
    private func flip() {
        videoHelper.flipCamera {
            self.updateState {
                $0.flashMode = self.flashModeFrom(videoHelper: self.videoHelper)
            }
        }
    }
    
    // MARK: - Toggle Flash
    
    @objc
    func flashButtonTapped() {
        videoHelper.toggleTorch()
        updateState {
            $0.flashMode = self.flashModeFrom(videoHelper: self.videoHelper)
        }
    }
    
    // MARK: - Toggle Recording
    
    @objc
    func shotButtonTapped() {
        if self.recordTime == YPConfig.video.recordingTimeLimit {
            self.previewButtonTapped()
        }else{
            doAfterPermissionCheck { [weak self] in
                self?.toggleRecording()
            }
        }
    }
    
    private func toggleRecording() {
        videoHelper.isRecording ? stopRecording() : startRecording()
    }
    
    private func startRecording() {
        if recordTime == 0.0 {
            showIndicatorAdded = true
            v.shotButton.isUserInteractionEnabled = false
            NotificationCenter.default.post(name: NSNotification.Name("showIndicator"), object: nil)
        }
        self.videoCaptured = false
        self.saveButtonPressed = false
        videoHelper.videoRecordingTimeLimit = YPConfig.video.trimmerMaxDuration - recordTime
        videoHelper.startRecording()
        updateState {
            $0.isRecording = true
            $0.isPaused = false
        }
    }
    
    private func stopRecording() {
        videoHelper.stopRecording()
        updateState {
            $0.isRecording = false
            $0.isPaused = true
        }
    }

    public func stopCamera() {
        videoHelper.stopCamera()
    }
    
    // MARK: - Focus
    
    @objc
    func focusTapped(_ recognizer: UITapGestureRecognizer) {
        doAfterPermissionCheck { [weak self] in
            self?.focus(recognizer: recognizer)
        }
    }
    
    private func focus(recognizer: UITapGestureRecognizer) {
        let point = recognizer.location(in: v.previewViewContainer)
        let viewsize = v.previewViewContainer.bounds.size
        let newPoint = CGPoint(x: point.x/viewsize.width, y: point.y/viewsize.height)
        videoHelper.focus(onPoint: newPoint)
        v.focusView.center = point
        YPHelper.configureFocusView(v.focusView)
        v.addSubview(v.focusView)
        YPHelper.animateFocusView(v.focusView)
    }
    
    // MARK: - Zoom
    
    @objc
    func pinch(_ recognizer: UIPinchGestureRecognizer) {
        doAfterPermissionCheck { [weak self] in
            self?.zoom(recognizer: recognizer)
        }
    }
    
    func zoom(recognizer: UIPinchGestureRecognizer) {
        videoHelper.zoom(began: recognizer.state == .began, scale: recognizer.scale)
    }
    
    // MARK: - UI State
    
    enum FlashMode {
        case noFlash
        case off
        case on
        case auto
    }
    
    struct ViewState {
        var isRecording = false
        var isPaused = false
        var flashMode = FlashMode.noFlash
        var progress: Float = 0
        var timeElapsed: TimeInterval = 0
    }
    
    private func updateState(block:(inout ViewState) -> Void) {
        block(&viewState)
        updateUIWith(state: viewState)
    }
    
    private func updateUIWith(state: ViewState) {
        func flashImage(for torchMode: FlashMode) -> UIImage {
            switch torchMode {
            case .noFlash: return UIImage()
            case .on: return YPConfig.icons.flashOnIcon
            case .off: return YPConfig.icons.flashOffIcon
            case .auto: return YPConfig.icons.flashAutoIcon
            }
        }
        let secoundsGreaterThan3Secs = recordTime < YPConfig.video.minimumTimeLimit
        if state.isPaused{
            if UserDefaults.standard.value(forKey: "recording_paused_coachmark") == nil {
                popTip.show(text: "recording_paused_coachmark".localized, direction: .up, maxWidth: screenWidth, in: v.bottomView, from: v.shotButton.frame,duration: toolTipDuration)
                UserDefaults.standard.set("Yes", forKey: "recording_paused_coachmark")
                UserDefaults.standard.synchronize()
            }
            v.previewView.isHidden = secoundsGreaterThan3Secs
            if secoundsGreaterThan3Secs {
                v.saveView.isHidden = true
                v.retryView.isHidden = true
            }else{
                v.saveView.isHidden = false
                v.retryView.isHidden = false
            }
        }else{
            v.saveView.isHidden = secoundsGreaterThan3Secs
            v.retryView.isHidden = secoundsGreaterThan3Secs
//            v.previewView.isHidden = secoundsGreaterThan3Secs
            if !secoundsGreaterThan3Secs {
                if UserDefaults.standard.value(forKey: "recording_cancel_coachmark") == nil {
                    popTip.show(text: "recording_cancel_coachmark".localized, direction: .up, maxWidth: screenWidth, in: v.bottomView, from: v.retryStackView.frame,duration: toolTipDuration)
                    UserDefaults.standard.set("Yes", forKey: "recording_cancel_coachmark")
                    UserDefaults.standard.synchronize()
                }
            }
        }
        v.flashButton.setImage(flashImage(for: state.flashMode), for: .normal)
        if state.isRecording {
            v.flashButton.isHidden = true
        }else{
            v.flashButton.isHidden = state.flashMode == .noFlash
        }
//        v.flashButton.isEnabled = !state.isRecording
        
//        v.shotButton.setImage(state.isRecording ? YPConfig.icons.captureVideoOnImage : YPConfig.icons.captureVideoImage,
//                              for: .normal)
        if recordTime == 0.0{
            v.shotRecordView.isHidden = false
            v.shotPlayView.isHidden = true
            v.shotLbl.isHidden = true
        }else{
            v.shotRecordView.isHidden = true
            v.shotPlayView.isHidden = false
            if state.isRecording {
                v.shotPauseView.isHidden = false
                v.shotLbl.isHidden = true
            }else{
                v.shotPauseView.isHidden = true
                v.shotLbl.isHidden = false
            }
        }
        
        v.flipButton.isHidden = state.isRecording
//        v.shotLbl.isHidden = !state.isRecording
//        v.progressBar.progress = state.progress
        let finalTime = YPConfig.video.trimmerMaxDuration - recordTime
        v.timeElapsedLabel.text = YPHelper.formattedStrigFrom(finalTime)
        v.timeElapsedLabel.isHidden = finalTime == YPConfig.video.trimmerMaxDuration
        
        // Animate progress bar changes.
//        UIView.animate(withDuration: 1, animations: v.progressBar.layoutIfNeeded)
    }
    
    private func resetVisualState() {
        recordTime = 0.0
        self.videoUrlPath = ""
        v.previewView.isHidden = true
        updateState {
            $0.isRecording = self.videoHelper.isRecording
            $0.isPaused = false
            $0.flashMode = self.flashModeFrom(videoHelper: self.videoHelper)
            $0.progress = 0
            $0.timeElapsed = 0
        }
    }
    
    private func flashModeFrom(videoHelper: YPVideoCaptureHelper) -> FlashMode {
        if videoHelper.hasTorch() {
            switch videoHelper.currentTorchMode() {
            case .off: return .off
            case .on: return .on
            case .auto: return .auto
            @unknown default:
                fatalError()
            }
        } else {
            return .noFlash
        }
    }
}
extension YPVideoCaptureVC: UIVideoEditorControllerDelegate, UINavigationControllerDelegate {
    public func videoEditorController(_ editor: UIVideoEditorController, didSaveEditedVideoToPath editedVideoPath: String) {
        print("Result saved to path: \(editedVideoPath)")
        DispatchQueue.global().asyncAfter(deadline: .now() + 1, execute: {
            DispatchQueue.main.async {
                self.deleteAsset(at: editor.videoPath)
            }
        })
        editor.dismiss(animated: true) {
            let asset = AVAsset(url: URL(fileURLWithPath: editedVideoPath))
            let secoundsInInt = Int(asset.duration.seconds)
            self.recordTime = Double(secoundsInInt)
            let finalTime = YPConfig.video.trimmerMaxDuration - Double(secoundsInInt)
            self.v.timeElapsedLabel.text = YPHelper.formattedStrigFrom(finalTime)
            self.v.timeElapsedLabel.isHidden = finalTime == YPConfig.video.trimmerMaxDuration
            self.videoUrlPath = editedVideoPath
//            if self.videoUrlPath == ""{
//                self.videoUrlPath = editedVideoPath
//            }else{
//                let oldURL = URL(fileURLWithPath: self.videoUrlPath)
//                let newURL = URL(fileURLWithPath: editedVideoPath)
//                DPVideoMerger().mergeVideos(withFileURLs: [oldURL,newURL]) { (url, error) in
//                    if error == nil{
//                        if let mergedURL = url{
//                            self.videoUrlPath = mergedURL.path
//                        }
//
//                    }
//                }
//            }
            
        }
//        let asset = AVAsset(url: URL(fileURLWithPath: editedVideoPath))
        
//        dismiss(animated:true, completion: {
//        })
    }
    
    public func videoEditorControllerDidCancel(_ editor: UIVideoEditorController) {
        dismiss(animated:true)
        DispatchQueue.global().asyncAfter(deadline: .now() + 1, execute: {
            DispatchQueue.main.async {
               // VideosCollectionViewController.deleteAsset(at: editor.videoPath)
            }
        })
    }
    
    public func videoEditorController(_ editor: UIVideoEditorController, didFailWithError error: Error) {
        print("an error occurred: \(error.localizedDescription)")
        dismiss(animated:true)
        DispatchQueue.global().asyncAfter(deadline: .now() + 1, execute: {
            DispatchQueue.main.async {
                self.deleteAsset(at: editor.videoPath)
            }
        })
    }
    
    func deleteAsset(at path: String) {
          do {
              try FileManager.default.removeItem(at: URL(fileURLWithPath: path))
              print("Deleted asset file at: \(path)")
          } catch {
              print("Failed to delete assete file at: \(path).")
              print("\(error)")
          }
      }
}

extension FileManager {
  func createKooCreateVideoPath() -> String {
      return URL(fileURLWithPath: ((FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last)?.path)!).appendingPathComponent("\(UUID().uuidString).mp4").path
  }
}
