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


extension Notification.Name {
    static let CharacteristicValueUpdate = Notification.Name(rawValue: "CharacteristicValueUpdate")
    static let BluetoothDisconnect = Notification.Name(rawValue: "BluetoothDisconnect")
}

enum BLEError:Error {
    case PrevPromiseNotResolved
}


class BluetoothCentralService: NSObject {
    
    var centralStatus: CBManagerState? {get {return centralManager!.state}}
    fileprivate var centralManager:CBCentralManager?
    fileprivate var availablePeripherals = [UUID:AvailablePeripheralData]()
    fileprivate let stateUpdateHandler:CentralStateUpdateHandler
    fileprivate var discoverPeripheralsHandler:DiscoverPeripheralsDataHandler?
    
    struct CentralConnectionResolver {
        let fulfill:(CBPeripheral)->Void
        let reject:(Error)->Void
        
        init(f:@escaping (CBPeripheral)->Void, r:@escaping (Error)->Void){
            fulfill = f
            reject = r
        }
    }
    
    fileprivate var connectionResolvers = [CBPeripheral: CentralConnectionResolver]()
    
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
    
    func stopScan() {
        centralManager?.stopScan()
    }
    
    func connect(peripheral:CBPeripheral)->Promise<CBPeripheral> {
        guard connectionResolvers[peripheral] == nil else {
            return Promise<CBPeripheral>.init(error: BLEError.PrevPromiseNotResolved)
        }
        centralManager?.connect(peripheral, options: nil)
        let pending = Promise<CBPeripheral>.pending()
        connectionResolvers[peripheral] = CentralConnectionResolver(f: pending.fulfill, r: pending.reject)
        return pending.promise
    }
    
    func disconnect(peripheral:CBPeripheral) {
        centralManager?.cancelPeripheralConnection(peripheral)
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
        guard let resolver = connectionResolvers.removeValue(forKey: peripheral) else {
            return
        }
        resolver.fulfill(peripheral)
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        var info:[AnyHashable: Any] = ["peripheral": peripheral]
        if let err = error {
            info["error"] = err
        }
        NotificationCenter.default.post(name: .BluetoothDisconnect, object: nil, userInfo: info)
    }
    
}


class BluetoothPeripheralService:NSObject {
    
    fileprivate let serviceUUID =       CBUUID(string: "E20A39F4-73F5-4BC4-A12F-17D1AD07A961")
    fileprivate let generalCharUUID =   CBUUID(string: "01234567-89AB-CDEF-0123-456789ABCDE0")
    fileprivate let ledCharUUID =       CBUUID(string: "01234567-89AB-CDEF-0123-456789ABCDE1")
    fileprivate let motorCharUUID =     CBUUID(string: "01234567-89AB-CDEF-0123-456789ABCDE2")
    fileprivate var service:CBService?
    fileprivate var pendingWrite = [CBUUID: Array<Promise<Void>.PendingTuple>]()
    fileprivate let peripheral:CBPeripheral
    fileprivate var discoverServiceResolver:(fulfill:(CBPeripheral)->Void, reject:(Error)->Void)?
    fileprivate var discoverCharacteristicsResolver:(fulfill:(CBPeripheral)->Void, reject:(Error)->Void)?
    
    struct PeripheralWriteResolver {
        let fulfill:(CBCharacteristic)->Void
        let reject:(Error)->Void
        
        init(fulfill:@escaping (CBCharacteristic)->Void, reject:@escaping (Error)->Void) {
            self.fulfill = fulfill
            self.reject = reject
        }
    }
    
    fileprivate var writeDataResolvers = [CBUUID: [PeripheralWriteResolver]]()
    
    init(p:CBPeripheral){
        peripheral = p
        super.init()
        peripheral.delegate = self
    }
    
    func discoverService()->Promise<CBPeripheral> {
        guard discoverServiceResolver == nil else {
            return Promise<CBPeripheral>.init(error: BLEError.PrevPromiseNotResolved)
        }
        peripheral.discoverServices([serviceUUID])
        let pending = Promise<CBPeripheral>.pending()
        discoverServiceResolver = (fulfill: pending.fulfill, reject: pending.reject)
        return pending.promise
    }
    
    func discoverCharacteristics(service:CBService)->Promise<CBPeripheral> {
        guard discoverCharacteristicsResolver == nil else {
            return Promise<CBPeripheral>.init(error: BLEError.PrevPromiseNotResolved)
        }
        peripheral.discoverCharacteristics([generalCharUUID, ledCharUUID, motorCharUUID], for: service)
        let pending = Promise<CBPeripheral>.pending()
        discoverCharacteristicsResolver = (fulfill: pending.fulfill, reject: pending.reject)
        return pending.promise
    }
    
    func write(data:Data, charateristic:CBCharacteristic)->Promise<CBCharacteristic> {
        peripheral.writeValue(data, for: charateristic, type: CBCharacteristicWriteType.withResponse)
        let pending = Promise<CBCharacteristic>.pending()
        let resolver = PeripheralWriteResolver(fulfill: pending.fulfill, reject: pending.reject)
        if var stack = writeDataResolvers[charateristic.uuid] {
            stack.append(resolver)
        }else{
            writeDataResolvers[charateristic.uuid] = [resolver]
        }
        return pending.promise
    }
    
    func setNotifyFor(charateristic:CBCharacteristic) {
        peripheral.setNotifyValue(true, for: charateristic)
    }
    
}

extension BluetoothPeripheralService: CBPeripheralDelegate {
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let resolver = discoverServiceResolver else {
            return
        }
        if let err = error {
            resolver.reject(err)
        }else{
            resolver.fulfill(peripheral)
        }
        discoverServiceResolver = nil
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let resolver = discoverCharacteristicsResolver else {
            return
        }
        if let err = error {
            resolver.reject(err)
        }else{
            resolver.fulfill(peripheral)
        }
        discoverCharacteristicsResolver = nil
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let resolver = writeDataResolvers[characteristic.uuid]?.remove(at: 0) else {
            return
        }
        if let err = error {
            resolver.reject(err)
        }else{
            resolver.fulfill(characteristic)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        NotificationCenter.default.post(name: .CharacteristicValueUpdate, object: nil, userInfo: ["char": characteristic, "peripheral": peripheral])
    }
    
}




