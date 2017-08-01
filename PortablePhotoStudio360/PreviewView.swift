//
//  PreviewView.swift
//  PortablePhotoStudio360
//
//  Created by ChangChao-Tang on 2017/8/1.
//  Copyright © 2017年 ChangChao-Tang. All rights reserved.
//

import UIKit
import PinLayout
import AVFoundation

class PreviewView: UIView {
    
    let session:AVCaptureSession
    let previewLayer:AVCaptureVideoPreviewLayer
    
    init(frame: CGRect, session:AVCaptureSession) {
        self.session = session
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        super.init(frame: frame)
        layer.addSublayer(previewLayer)
        previewLayer.frame = layer.bounds
        previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = layer.bounds
    }
    
}
