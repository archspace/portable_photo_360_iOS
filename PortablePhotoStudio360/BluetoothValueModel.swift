//
//  BluetoothValueModel.swift
//  PortablePhotoStudio360
//
//  Created by ChangChao-Tang on 2017/8/29.
//  Copyright © 2017年 ChangChao-Tang. All rights reserved.
//

import Foundation

protocol BluetoothValueProtocol {
    init?(withValue value:Data)
    func data() -> Data
}

extension Data {
    func valueInRange<T>(range:Range<Data.Index>, constructor:(_ buffer:[UInt8])->T)->T {
        var buffer = [UInt8].init(repeating: 0, count: range.count)
        self.copyBytes(to: &buffer, from: range)
        return constructor(buffer)
    }
}

enum BLEStatus {
    case Ready, LEDInitFailed, MotorInitFailed
}

struct GeneralRequest:BluetoothValueProtocol {
    let value:Data
    let status:BLEStatus
    
    init?(withValue value: Data) {
        guard value.count > 0 else{
            return nil
        }
        let statusCode = value.valueInRange(range: Range(0...0)) { (buffer) -> UInt8 in
            return buffer[0]
        }
        self.value = value
        switch statusCode {
        case 0x00:
            status = .Ready
            break
        case 0xE1:
            status = .LEDInitFailed
            break
        case 0xE2:
            status = .MotorInitFailed
            break
        default:
            return nil
        }
    }

    func data() -> Data {
        return value
    }
    
}

struct LEDRequest:BluetoothValueProtocol {
    
    let value:Data
    let LED1:Float
    let LED2:Float
    let LED3:Float
    
    init?(withValue value: Data) {
        guard value.count >= 6 else{
            return nil
        }
        self.value = value
        var v = [Float]()
        for i in 0...2 {
            let start = i * 2
            let end = i * 2 + 1
            let v_int = value.valueInRange(range: Range(start...end), constructor: { (buffer) -> UInt16 in
                return UInt16(buffer[0]|0x0000) + UInt16(buffer[1]|0x0000) << 8
            })
            v.append(Float(v_int) / Float(0x3FF))
        }
        LED1 = v[0]
        LED2 = v[1]
        LED3 = v[2]
    }
    
    //the value of lightness must in the range of 0~1
    init?(LED1:Float, LED2:Float, LED3:Float) {
        guard LED1 <= 1, LED1 >= 0, LED2 <= 1, LED2 >= 0, LED3 <= 1, LED3 >= 0 else {
            return nil
        }
        self.LED1 = LED1
        self.LED2 = LED2
        self.LED3 = LED3
        let buffer = [LED1, LED2, LED3].map { (value) -> UInt16 in
            return UInt16(value * 0x3FF)
        }.map { (value) -> [UInt8] in
            let tail = UInt8(value & 0xff)
            let head = UInt8(value >> 8 & 0xff)
            return [tail, head]
        }.flatMap { (values) -> [UInt8] in
            return values
        }
        value = Data(bytes: buffer)
    }
    
    func data() -> Data {
        return value
    }
    
}

struct MotorRequest:BluetoothValueProtocol {
    
    let value:Data
    let isReady:Bool?
    let isClockwise:Bool
    let angle:UInt8
    
    init?(withValue value: Data) {
        guard value.count >= 3 else{
            return nil
        }
        self.value = value
        isReady = value.valueInRange(range: Range(0...0), constructor: { (buffer) -> Bool in
            let status = buffer[0]
            return status == 0x00
        })
        isClockwise = value.valueInRange(range: Range(1...1), constructor: { (buffer) -> Bool in
            let rot = buffer[0]
            return rot == 0x00
        })
        angle = value.valueInRange(range: Range(2...2), constructor: { (buffer) -> UInt8 in
            return buffer[0]
        })
    }
    
    init(isClockwise:Bool, angle:UInt8) {
        isReady = nil
        self.isClockwise = isClockwise
        self.angle = angle
        value = Data(bytes: [0x00, isClockwise ? 0x00 : 0x01, angle])
    }

    func data() -> Data {
        return value
    }
    
}


