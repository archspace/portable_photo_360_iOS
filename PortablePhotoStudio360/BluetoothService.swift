//
//  bluetoothService.swift
//  PortablePhotoStudio360
//
//  Created by ChangChao-Tang on 2017/7/9.
//  Copyright © 2017年 ChangChao-Tang. All rights reserved.
//

import UIKit
import CoreBluetooth


typealias CentralStateUpdateHandler = (CBManagerState)->Void
typealias AvailablePeripheralData = (peripheral:CBPeripheral, advertisementData: [String : Any], rssi:NSNumber)
typealias DiscoverPeripheralsDataHandler = ([AvailablePeripheralData])->Void

class BluetoothCentralService: NSObject {
    
    private var centralManager:CBCentralManager?
    
    var centralStatus: CBManagerState? {get {return centralManager!.state}}
    
    var connectedPeripherals:[CBPeripheral] {get {return centralManager!.retrieveConnectedPeripherals(withServices: serviceUUIDs)}}
    
    var availablePeripherals = [AvailablePeripheralData]()
    
    let stateUpdateHandler:CentralStateUpdateHandler
    var discoverPeripheralsHandler:DiscoverPeripheralsDataHandler?
    
    let serviceUUIDs:[CBUUID]
    
    init(withServices UUIDs: [CBUUID], onStateUpdate updateHandler: @escaping CentralStateUpdateHandler) {
        serviceUUIDs = UUIDs
        stateUpdateHandler = updateHandler
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: DispatchQueue.main)
    }
    
    func startScan(discoverHandler: @escaping DiscoverPeripheralsDataHandler) {
        availablePeripherals = [AvailablePeripheralData]()
        discoverPeripheralsHandler = discoverHandler
        centralManager?.scanForPeripherals(withServices: serviceUUIDs, options: nil)
    }
    
}

extension BluetoothCentralService: CBCentralManagerDelegate {
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        stateUpdateHandler(central.state)
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let data:AvailablePeripheralData = (peripheral: peripheral, advertisementData: advertisementData, rssi: RSSI)
        availablePeripherals.append(data)
        discoverPeripheralsHandler?(availablePeripherals)
    }
}