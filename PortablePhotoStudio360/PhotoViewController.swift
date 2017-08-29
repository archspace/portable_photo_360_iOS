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
import PromiseKit

class PhotoViewController: UIViewController {
    
    var mediator: AppMediator?
    var pService: BluetoothPeripheralService?
    let session = AVCaptureSession()
    let deviceSession = AVCaptureDeviceDiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: AVMediaTypeVideo, position: .back)
    var videoView:PreviewView?
    let testButton = UIButton()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        captureSessionConfig()
        setupUI()
        NotificationCenter.default.addObserver(self, selector: #selector(onDeviceDisconnect), name: .BluetoothDisconnect, object: nil)
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
    
    func captureSessionConfig() {
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
    }
    
    func setupUI() {
        view.backgroundColor = UIColor.black
        videoView = PreviewView(frame: view.bounds, session: session)
        view.addSubview(videoView!)
        testButton.setTitle("test", for: .normal)
        view.addSubview(testButton)
        testButton.addTarget(self, action: #selector(onTest), for: .touchUpInside)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        videoView?.pin.top(44).left(0).right(0).bottom(122)
        testButton.pin.bottom().right().width(40).height(40)
    }
    
    func onDeviceDisconnect() {
        mediator?.toRoute(route: .BluetoothList, fromController: self, userInfo: nil)
    }
    
    func fetchCharateristicValue<T:BluetoothValueProtocol>(uuid:CBUUID, type:T.Type) -> T? {
        guard let pS = pService, let service = pS.peripheral.serviceWithUUID(uuid: pS.serviceUUID) else {
            return nil
        }
        guard let char = service.characteristics?.filter({ (c) -> Bool in return c.uuid == uuid}).first,
            let value = char.value else {
            return nil
        }
        let r = type.init(withValue: value)
        return r
    }
    
    func onTest() {
        guard let pS = pService, let service = pS.peripheral.serviceWithUUID(uuid: pS.serviceUUID),
            let char = service.characteristic(withUUID: pS.motorCharUUID) else {
            return
        }
        
        let motorR = MotorRequest(isClockwise: false, angle: 20)
        pS.write(data: motorR.data(), charateristic: char).then { (c) -> Promise<CBCharacteristic> in
            return pS.read(charateristic: char)
        }.then(execute: { (c) -> Void in
            guard let value = c.value else {return}
            let req = MotorRequest(withValue: value)
            print(req)
        }).catch { (err) in
            print(err)
        }
    }
    
}
