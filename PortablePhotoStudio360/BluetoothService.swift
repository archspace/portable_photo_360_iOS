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

extension CBPeripheral {
    
    func serviceWithUUID(uuid:CBUUID) -> CBService? {
        let result = services?.filter({ (service) -> Bool in
            return service.uuid == uuid
        }).first
        return result
    }
}

extension CBService {
    
    func containCharacteristics(uuids:[CBUUID]) -> Bool {
        var target = uuids
        for i in 0...(characteristics?.count ?? 0) {
            if target.count == 0 {break}
            let c = characteristics![i]
            if let idx = target.index(of: c.uuid) {target.remove(at: idx)}
        }
        return target.count == 0
    }
    
    func characteristic(withUUID uuid:CBUUID) -> CBCharacteristic? {
        let result = characteristics?.filter({ (c) -> Bool in
            return c.uuid == uuid
        }).first
        return result
    }
}

enum BLEError:Error {
    case PrevPromiseNotResolved, NoAvailableService, NoAvailableCharateristics
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
    
    let peripheral:CBPeripheral
    let serviceUUID =       CBUUID(string: "E20A39F4-73F5-4BC4-A12F-17D1AD07A961")
    let generalCharUUID =   CBUUID(string: "01234567-89AB-CDEF-0123-456789ABCDE0")
    let ledCharUUID =       CBUUID(string: "01234567-89AB-CDEF-0123-456789ABCDE1")
    let motorCharUUID =     CBUUID(string: "01234567-89AB-CDEF-0123-456789ABCDE2")
    fileprivate var service:CBService?
    fileprivate var pendingWrite = [CBUUID: Array<Promise<Void>.PendingTuple>]()
    fileprivate var discoverServiceResolver:(fulfill:(CBPeripheral)->Void, reject:(Error)->Void)?
    fileprivate var discoverCharacteristicsResolver:(fulfill:(CBPeripheral)->Void, reject:(Error)->Void)?
    
    struct PeripheralReadWriteResolver {
        let fulfill:(CBCharacteristic)->Void
        let reject:(Error)->Void
        
        init(fulfill:@escaping (CBCharacteristic)->Void, reject:@escaping (Error)->Void) {
            self.fulfill = fulfill
            self.reject = reject
        }
    }
    
    fileprivate var writeDataResolvers = [CBUUID: [PeripheralReadWriteResolver]]()
    fileprivate var readDataResolvers = [CBUUID: [PeripheralReadWriteResolver]]()
    
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
        let resolver = PeripheralReadWriteResolver(fulfill: pending.fulfill, reject: pending.reject)
        if var stack = writeDataResolvers[charateristic.uuid] {
            stack.append(resolver)
        }else{
            writeDataResolvers[charateristic.uuid] = [resolver]
        }
        return pending.promise
    }
    
    func read(charateristic:CBCharacteristic)->Promise<CBCharacteristic> {
        peripheral.readValue(for: charateristic)
        let pending = Promise<CBCharacteristic>.pending()
        let resolver = PeripheralReadWriteResolver(fulfill: pending.fulfill, reject: pending.reject)
        if var stack = readDataResolvers[charateristic.uuid] {
            stack.append(resolver)
        }else {
            readDataResolvers[charateristic.uuid] = [resolver]
        }
        return pending.promise
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
        guard var stack = writeDataResolvers[characteristic.uuid], stack.count > 0 else {
            return
        }
        let resolver = stack.remove(at: 0)
        if let err = error {
            resolver.reject(err)
        }else{
            resolver.fulfill(characteristic)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard var stack = readDataResolvers[characteristic.uuid], stack.count > 0 else {
            return
        }
        let resolver = stack.remove(at: 0)
        if let err = error {
            resolver.reject(err)
        }else {
            resolver.fulfill(characteristic)
        }
    }
    
}




