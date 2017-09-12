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
    let timeout:UInt32
    weak var delegate:RotateOperationDelegate?
    
    init(pService:BluetoothPeripheralService, isClockwise:Bool, stepAngle:UInt8, totalSteps:UInt8, stepTimeout:UInt32) {
        self.pService = pService
        self.isClockwise = isClockwise
        self.angle = stepAngle
        self.stepsRemain = totalSteps
        self.timeout = stepTimeout
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
}
