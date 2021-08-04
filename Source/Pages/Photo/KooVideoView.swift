//
//  KooVideoView.swift
//  KooVoice
//
//  Created by Yugesh Mucherla on 28/08/20.
//  Copyright © 2020 Bombinate Technologies Pv tLtd. All rights reserved.
//

import UIKit

class KooVideoView: UIView {

    let focusView = UIView(frame: CGRect(x: 0, y: 0, width: 90, height: 90))
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var bottomView : UIView!
    @IBOutlet weak var flipButton : UIButton!
    @IBOutlet weak var shotButton : UIButton!
    @IBOutlet weak var shotRecordView : UIView!
    @IBOutlet weak var shotPlayView : UIView!
    @IBOutlet weak var shotPauseView : UIImageView!
    @IBOutlet weak var shotLbl : UILabel!
    @IBOutlet weak var retryStackView: UIStackView!
    @IBOutlet weak var retryButton : UIButton!
    @IBOutlet weak var retryView : UIView!
    @IBOutlet weak var retryLbl : UILabel!
    @IBOutlet weak var retryImageView : UIImageView!
    @IBOutlet weak var previewButton : UIButton!
    @IBOutlet weak var previewStackView: UIStackView!
    @IBOutlet weak var previewView : UIView!
    @IBOutlet weak var previewLbl : UILabel!
    @IBOutlet weak var previewImageView : UIImageView!
    @IBOutlet weak var flashButton : UIButton!
    @IBOutlet weak var timeElapsedLabel : UILabel!
    @IBOutlet weak var previewViewContainer : UIView!
    @IBOutlet weak var saveView : UIView!
    @IBOutlet weak var saveButton : UIButton!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commitInit()
    }
    
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commitInit()
    }
    
    func commitInit() {
        
        let bunble = Bundle(for: type(of: self))
        bunble.loadNibNamed("KooVideoView", owner: self, options: nil)
        addSubview(self.containerView)
        self.containerView.isOpaque = false
        if self.traitCollection.userInterfaceStyle == .dark {
            // User Interface is Dark
            self.containerView.backgroundColor = UIColor.black
        } else {
            // User Interface is Light
            self.containerView.backgroundColor = UIColor.white
        }
        self.containerView.frame = self.bounds
        self.containerView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        self.shotLbl.text = "proceed".localized
        self.saveButton.setTitle("save".localized, for: .normal)
        self.previewLbl.text = "preview".localized
        self.retryLbl.text = "restart".localized
        self.previewImageView.image = UIImage(named: "video_preview")?.withRenderingMode(.alwaysTemplate)
        self.retryImageView.image = UIImage(named: "backspace")?.withRenderingMode(.alwaysTemplate)
        
    }

}
