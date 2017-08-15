//
//  bluetoothService.swift
//  PortablePhotoStudio360
//
//  Created by ChangChao-Tang on 2017/7/9.
//  Copyright © 2017年 ChangChao-Tang. All rights reserved.
//

import UIKit
import CoreBluetooth
import PromiseKit


typealias CentralStateUpdateHandler = (CBManagerState)->Void
typealias AvailablePeripheralData = (peripheral:CBPeripheral, advertisementData: [String : Any], rssi:NSNumber)
typealias DiscoverPeripheralsDataHandler = ([UUID:AvailablePeripheralData])->Void
typealias ConnectPeripheralHandler = (CBPeripheral)->Void

extension CBService {
    func containCharacteristic(uuid:CBUUID) -> Bool {
        let t = characteristics?.filter({ (char) -> Bool in
            return char.uuid == uuid
        }).count
        guard let target = t else {
            return false
        }
        return target > 0
    }
}

extension Notification.Name {
    static let CharacteristicValueUpdate = Notification.Name(rawValue: "CharacteristicValueUpdate")
}


class BluetoothCentralService: NSObject {
    
    fileprivate var centralManager:CBCentralManager?
    
    var centralStatus: CBManagerState? {get {return centralManager!.state}}
    
    var connectedPeripherals:[CBPeripheral] {
        get {
            return centralManager!.retrieveConnectedPeripherals(withServices: [serviceUUID])
        }
    }
    
    var availablePeripherals = [UUID:AvailablePeripheralData]()
    
    let stateUpdateHandler:CentralStateUpdateHandler
    var discoverPeripheralsHandler:DiscoverPeripheralsDataHandler?
    var connectHandler:ConnectPeripheralHandler?
    
    let serviceUUID = CBUUID(string: "E20A39F4-73F5-4BC4-A12F-17D1AD07A961")
    var service:CBService?
    let generalCharUUID = CBUUID(string: "01234567-89AB-CDEF-0123-456789ABCDE0")
    let ledCharUUID = CBUUID(string: "01234567-89AB-CDEF-0123-456789ABCDE1")
    let motorCharUUID = CBUUID(string: "01234567-89AB-CDEF-0123-456789ABCDE2")
    var pendingWrite = [CBUUID: Array<Promise<Void>.PendingTuple>]()
    
    init(onStateUpdate updateHandler: @escaping CentralStateUpdateHandler) {
        stateUpdateHandler = updateHandler
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: DispatchQueue.main)
    }
    
    func startScan(discoverHandler: @escaping DiscoverPeripheralsDataHandler) {
        availablePeripherals = [UUID:AvailablePeripheralData]()
        discoverPeripheralsHandler = discoverHandler
        centralManager?.scanForPeripherals(withServices: nil, options: nil)
    }
    
    func connect(peripheral:CBPeripheral, handler:@escaping ConnectPeripheralHandler) {
        centralManager?.connect(peripheral, options: nil)
        connectHandler = handler
    }
    
    
    func writeData(data:Data, peripheral:CBPeripheral, charId:CBUUID)->Promise<Void>? {
        guard let s = service, s.containCharacteristic(uuid: charId) else {
            return nil
        }
        let tuple = Promise<Void>.pending()
        if var stack = pendingWrite[charId] {
            stack.append(tuple)
        }else{
            pendingWrite[charId] = [tuple]
        }
        return tuple.promise
    }
    
}

extension BluetoothCentralService: CBCentralManagerDelegate {
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        stateUpdateHandler(central.state)
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let data:AvailablePeripheralData = (peripheral: peripheral, advertisementData: advertisementData, rssi: RSSI)
        availablePeripherals[peripheral.identifier] = data
        discoverPeripheralsHandler?(availablePeripherals)
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        peripheral.discoverServices([serviceUUID])
    }
}

extension BluetoothCentralService: CBPeripheralDelegate {
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        let targetS = peripheral.services?.filter({ (service) -> Bool in
            return service.uuid == serviceUUID
        }).first
        guard let service = targetS else {
            centralManager?.cancelPeripheralConnection(peripheral)
            connectHandler = nil
            return
        }
        peripheral.discoverCharacteristics([generalCharUUID, ledCharUUID, motorCharUUID], for: service)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        let filtered = service.characteristics?.filter({ (char) -> Bool in
            return [generalCharUUID, ledCharUUID, motorCharUUID].contains(char.uuid)
        })
        guard let chars = filtered, chars.count >= 3 else {
            return
        }
        self.service = service
        chars.forEach { (char) in
            peripheral.setNotifyValue(true, for: char)
        }
        connectHandler?(peripheral)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let tuple = pendingWrite[characteristic.uuid]?.remove(at: 0) else {
            return
        }
        if let err = error {
            tuple.reject(err)
        }else{
            tuple.fulfill()
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        NotificationCenter.default.post(name: .CharacteristicValueUpdate, object: nil, userInfo: ["char": characteristic])
    }
    
}





