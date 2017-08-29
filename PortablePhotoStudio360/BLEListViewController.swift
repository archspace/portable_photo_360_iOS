//
//  BLEListViewController.swift
//  PortablePhotoStudio360
//
//  Created by ChangChao-Tang on 2017/8/1.
//  Copyright © 2017年 ChangChao-Tang. All rights reserved.
//

import UIKit
import CoreBluetooth

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
        guard let p = peripherals[id]?.peripheral else {
            return
        }
        
    }
}
