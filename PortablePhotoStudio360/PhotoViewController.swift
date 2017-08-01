//
//  PhotoViewController.swift
//  PortablePhotoStudio360
//
//  Created by ChangChao-Tang on 2017/8/1.
//  Copyright © 2017年 ChangChao-Tang. All rights reserved.
//

import UIKit
import PinLayout
import AVFoundation
import CoreBluetooth

class PhotoViewController: UIViewController {
    
    var mediator: AppMediator?
    var peripheral: CBPeripheral?
    let session = AVCaptureSession()
    let deviceSession = AVCaptureDeviceDiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: AVMediaTypeVideo, position: .back)
    var videoView:PreviewView?
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        session.beginConfiguration()
        if session.canSetSessionPreset(AVCaptureSessionPresetHigh) {
            session.sessionPreset = AVCaptureSessionPresetHigh
        }else if session.canSetSessionPreset(AVCaptureSessionPresetMedium){
            session.sessionPreset = AVCaptureSessionPresetMedium
        }else{
            session.sessionPreset = AVCaptureSessionPresetLow
        }
        if let device = deviceSession?.devices.first {
            let input = try! AVCaptureDeviceInput(device: device)
            session.addInput(input)
        }
        session.commitConfiguration()
        setupUI()
        NotificationCenter.default.addObserver(self, selector: #selector(onStateChange(notify:)), name: .BLEStateChange, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        session.startRunning()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        session.stopRunning()
    }
    
    func setupUI() {
        view.backgroundColor = UIColor.black
        videoView = PreviewView(frame: view.bounds, session: session)
        view.addSubview(videoView!)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        videoView?.pin.top(44).left(0).right(0).bottom(122)
    }
    
    func onStateChange(notify:Notification) {
        
    }

    
}
