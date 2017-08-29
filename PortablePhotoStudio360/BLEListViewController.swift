//
//  BLEListViewController.swift
//  PortablePhotoStudio360
//
//  Created by ChangChao-Tang on 2017/8/1.
//  Copyright © 2017年 ChangChao-Tang. All rights reserved.
//

import UIKit
import CoreBluetooth
import PromiseKit

class BLEListViewController: UIViewController {
    
    var mediator: AppMediator?
    let tableView = UITableView()
    var peripherals = [UUID: AvailablePeripheralData]()
    let CellReuseId = "CellReuseId"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        scanIfCould()
        NotificationCenter.default.addObserver(self, selector: #selector(scanIfCould), name: .BLEStateChange, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func setupUI() {
        view.backgroundColor = UIColor.white
        view.addSubview(tableView)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 60
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let status = UIApplication.shared.statusBarFrame
        tableView.pin.top(status.height).left().right().bottom()
    }
    
    func scanIfCould() {
        guard mediator?.bleCentralService.centralStatus == .poweredOn else {
            return
        }
        mediator?.bleCentralService.startScan(discoverHandler: { [unowned self](peripherals) in
            self.peripherals = peripherals
            self.tableView.reloadData()
        })
    }
}

extension BLEListViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return peripherals.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell = tableView.dequeueReusableCell(withIdentifier: CellReuseId)
        if cell == nil {
           cell = UITableViewCell(style: .subtitle, reuseIdentifier: CellReuseId)
        }
        let id = Array(peripherals.keys)[indexPath.row]
        if let data = peripherals[id] {
            cell!.textLabel?.text = data.peripheral.name
            cell!.detailTextLabel?.text = data.peripheral.identifier.uuidString
        }
        return cell!
    }
}

extension BLEListViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let id = Array(peripherals.keys)[indexPath.row]
        guard let p = peripherals[id]?.peripheral, let service = mediator?.bleCentralService else {
            return
        }
        var pService:BluetoothPeripheralService?
        service.connect(peripheral: p)
            .then { (p) -> Promise<CBPeripheral> in
                pService = BluetoothPeripheralService(p: p)
                return pService!.discoverService()
            }
            .then(execute: { (p) -> Promise<CBPeripheral> in
                guard let pS = pService,
                    let service = p.serviceWithUUID(uuid: pS.serviceUUID) else{
                    throw BLEError.NoAvailableService
                }
                return pS.discoverCharacteristics(service: service)
            })
            .then(execute: { (p) -> Void in
                guard let pS = pService,
                    let service = p.serviceWithUUID(uuid: pS.serviceUUID),
                    service.containCharacteristics(uuids: [pS.generalCharUUID, pS.ledCharUUID, pS.motorCharUUID]) else {
                    throw BLEError.NoAvailableCharateristics
                }
                guard let mediator = self.mediator else{
                    return
                }
                mediator.toRoute(route: .Camera, fromController: self, userInfo: ["peripheral": p])
            })
            .catch { (err) in
                if let pS = pService, let cService = self.mediator?.bleCentralService {
                    cService.disconnect(peripheral: pS.peripheral)
                }
                var msg = ""
                switch err {
                case BLEError.NoAvailableService:
                    msg = NSLocalizedString("Error.NoAvailableService", comment: "")
                    break
                case BLEError.NoAvailableCharateristics:
                    msg = NSLocalizedString("Error.NoAvailableCharateristics", comment: "")
                    break
                default:
                    msg = NSLocalizedString("Error.ErrorWhileConnect", comment: "")
                    break
                }
                if let mediator = self.mediator {
                    mediator.showAlert(message: msg, onController: self)
                }
                print(err)
            }
    }
}
