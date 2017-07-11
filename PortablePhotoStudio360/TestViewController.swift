//
//  ViewController.swift
//  PortablePhotoStudio360
//
//  Created by ChangChao-Tang on 2017/7/9.
//  Copyright © 2017年 ChangChao-Tang. All rights reserved.
//

import UIKit
import PinLayout
import CoreBluetooth

class TestViewController: UIViewController {
    
    weak var mediator:AppMediator?
    let PeripheralListCellReuseId = "PeripheralListCellReuseId"
    let PeriphearlListRowHeight:CGFloat = 44.0
    let PeriphearlListMaxVisibleRows = 3
    var periphearlListHeight:CGFloat {
        get{
            let maxHeight = CGFloat(PeriphearlListMaxVisibleRows) * PeriphearlListRowHeight
            let height = CGFloat(peripherals.count) * PeriphearlListRowHeight
            return height < maxHeight ? height : maxHeight
        }
    }
    var peripherals = [AvailablePeripheralData]()
    let scanButton = UIButton()
    let peripheralList = UITableView()
    var bluetoothService:BluetoothCentralService?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        bluetoothService = BluetoothCentralService(withServices: []) {[unowned self](state) in
            switch state {
            case .poweredOff:
                self.mediator?.showAlert(message: "Bluetooth power off", onController: self)
                break
            case .poweredOn:
                self.scanButton.isEnabled = true
                self.scanButton.alpha = 1
                break
            case .unsupported:
                self.mediator?.showAlert(message: "Unspported device", onController: self)
                break
            case .unauthorized:
                self.mediator?.showAlert(message: "Need auth", onController: self)
                break
            default:
                //unknown restting ignore..
                break
            }
        }
    }
    
    private func setupUI (){
        view.backgroundColor = UIColor.white
        view.addSubview(scanButton)
        view.addSubview(peripheralList)
        scanButton.setTitle("Scan", for: .normal)
        scanButton.setTitleColor(UIColor.blue, for: .normal)
        scanButton.isEnabled = false
        scanButton.alpha = 0.25
        scanButton.addTarget(self, action: #selector(onScan), for: .touchUpInside)
        peripheralList.register(UITableViewCell.self, forCellReuseIdentifier: PeripheralListCellReuseId)
        peripheralList.dataSource = self
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let status = UIApplication.shared.statusBarFrame
        scanButton.pin.top(status.height + 10).right(10).width(45).height(30)
        peripheralList.pin.left(10).right(10).bottom(10).below(of: scanButton).marginTop(10)
    }
    
    func onScan() {
        bluetoothService?.startScan(discoverHandler: { (data) in
            self.peripherals = data
            self.peripheralList.reloadData()
        })
    }
}

extension TestViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return peripherals.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: PeripheralListCellReuseId, for: indexPath)
        let inform = peripherals[indexPath.row]
        cell.textLabel?.text = inform.peripheral.identifier.uuidString
        return cell
    }
}

