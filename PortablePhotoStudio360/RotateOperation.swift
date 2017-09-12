//
//  RotateOperation.swift
//  PortablePhotoStudio360
//
//  Created by ChangChao-Tang on 2017/9/12.
//  Copyright © 2017年 ChangChao-Tang. All rights reserved.
//

import UIKit
import PromiseKit
import CoreBluetooth
import AVFoundation
import Photos


enum RotationError:Error {
    case MotorCharacteristicValueError
    case MotorCharacteristicError
}

protocol RotateOperationDelegate:NSObjectProtocol {
    func operation(operation:RotateOperation, didStopWithError error:RotationError)
    func operation(operation:RotateOperation, didOccurredError error:Error)
    func operationMotorNotReady(operation:RotateOperation)
    func operationDidFinishOneStep(operation:RotateOperation)
    func operationDidFinished(operation:RotateOperation)
}

class RotateOperation: Operation {
    
    let pService:BluetoothPeripheralService
    let isClockwise:Bool
    let angle:UInt8
    var stepsRemain:UInt8
    var totalSteps:UInt8
    let timeout:UInt32
    let output:AVCapturePhotoOutput
    weak var delegate:RotateOperationDelegate?
    fileprivate var photoSampleBuffer:CMSampleBuffer?
    fileprivate var previewPhotoSampleBuffer:CMSampleBuffer?
    var photoName:String?
    
    init(pService:BluetoothPeripheralService,
         isClockwise:Bool, stepAngle:UInt8, totalSteps:UInt8, stepTimeout:UInt32, photoOutput:AVCapturePhotoOutput) {
        self.pService = pService
        self.isClockwise = isClockwise
        self.angle = stepAngle
        self.stepsRemain = totalSteps
        self.totalSteps = totalSteps
        self.timeout = stepTimeout
        self.output = photoOutput
        super.init()
        self.qualityOfService = .userInitiated
    }
    
    override func main() {
        guard let service = pService.peripheral.serviceWithUUID(uuid: pService.serviceUUID),
            let char = service.characteristic(withUUID: pService.motorCharUUID)  else {
            delegate?.operation(operation: self, didStopWithError: .MotorCharacteristicError)
            return
        }
        
        while stepsRemain > 0 {
            if isCancelled {
                break
            }
            DispatchQueue.main.async {
                self.pService.read(charateristic: char)
                    .then(execute: { (char) -> Promise<CBCharacteristic>? in
                        guard let value = char.value, let state = MotorRequest(withValue: value) else{
                            throw RotationError.MotorCharacteristicValueError
                        }
                        if state.isReady! {
                            let req = MotorRequest(isClockwise: self.isClockwise, angle: self.angle)
                            return self.pService.write(data: req.data(), charateristic: char)
                        }else {
                            self.delegate?.operationMotorNotReady(operation: self)
                            return nil
                        }
                    })
                    .then(execute: { (char) -> Void in
                        if char != nil {
                            sleep(3)
                            self.snapPhoto()
                            self.stepsRemain -= 1
                            self.delegate?.operationDidFinishOneStep(operation: self)
                        }
                    })
                    .catch(execute: { (err) in
                        self.delegate?.operation(operation: self, didOccurredError: err)
                    })
            }
            if isCancelled {
                break
            }
            sleep(timeout)
        }
        delegate?.operationDidFinished(operation: self)
    }
    
    func snapPhoto()  {
        let setting = AVCapturePhotoSettings(format: [AVVideoCodecKey : AVVideoCodecJPEG])
        setting.isAutoStillImageStabilizationEnabled = true
        setting.flashMode = .auto
        setting.isHighResolutionPhotoEnabled = true
        setting.previewPhotoFormat = [
            kCVPixelBufferPixelFormatTypeKey as String : NSNumber(value: kCVPixelFormatType_32BGRA),
            kCVPixelBufferWidthKey as String : NSNumber(value: 150),
            kCVPixelBufferHeightKey as String : NSNumber(value: 150)
        ]
        output.capturePhoto(with: setting, delegate: self)
    }
    
    func saveSampleBufferToPhotoLibrary(_ sampleBuffer:CMSampleBuffer, previewSampleBuffer:CMSampleBuffer?) {
        guard let data = AVCapturePhotoOutput.jpegPhotoDataRepresentation(forJPEGSampleBuffer: sampleBuffer, previewPhotoSampleBuffer: previewSampleBuffer) else {
            return
        }
        PHPhotoLibrary.shared().performChanges({ 
            let req = PHAssetCreationRequest.forAsset()
            let option = PHAssetResourceCreationOptions()
            if self.photoName == nil {self.photoName = UUID().uuidString}
            option.originalFilename = self.photoName!
            req.addResource(with: .photo, data: data, options: option)
        }) { (success, err) in
            print(self.photoName!)
        }
    }
}

extension RotateOperation:AVCapturePhotoCaptureDelegate {
    
    func capture(_ captureOutput: AVCapturePhotoOutput,
                 didFinishProcessingPhotoSampleBuffer photoSampleBuffer: CMSampleBuffer?,
                 previewPhotoSampleBuffer: CMSampleBuffer?,
                 resolvedSettings: AVCaptureResolvedPhotoSettings, bracketSettings: AVCaptureBracketedStillImageSettings?, error: Error?) {
        
        guard error == nil, let photoSampleBuffer = photoSampleBuffer else {
            print("Error capturing photo: \(String(describing: error))")
            return
        }
        self.photoSampleBuffer = photoSampleBuffer
        self.previewPhotoSampleBuffer = previewPhotoSampleBuffer
    }
                 
    
    func capture(_ captureOutput: AVCapturePhotoOutput, didFinishCaptureForResolvedSettings resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        guard error == nil else {
            print("Error in capture process: \(String(describing: error))")
            return
        }
        if let sampleBuffer = photoSampleBuffer {
            saveSampleBufferToPhotoLibrary(sampleBuffer, previewSampleBuffer: previewPhotoSampleBuffer)
        }
    }
}

