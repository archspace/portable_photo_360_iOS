//
//  AppMediator.swift
//  PortablePhotoStudio360
//
//  Created by ChangChao-Tang on 2017/7/9.
//  Copyright © 2017年 ChangChao-Tang. All rights reserved.
//

import UIKit
import CoreBluetooth

enum Route {
    case BluetoothList
}

extension Notification.Name {
    static let BLEStateChange = Notification.Name(rawValue: "BLEStateChange")
}

class AppMediator: NSObject {
    
    private let window:UIWindow
    
    let bleService:BluetoothCentralService
    
    init(withWindow window:UIWindow) {
        self.window = window
        bleService = BluetoothCentralService(withServices: [
            CBUUID(string:"E20A39F4-73F5-4BC4-A12F-17D1AD07A961")
        ]) {(state) in
            NotificationCenter.default.post(name: .BLEStateChange, object: nil, userInfo: ["state": stat])
        }
        super.init()
    }
    
    func start() {
        let photo = PhotoViewController()
        photo.mediator = self
        window.rootViewController = photo
        window.makeKeyAndVisible()
    }
    
    func toRoute(route:Route, fromController controller:UIViewController) {
        switch route {
        case .BluetoothList:
            let ble = BLEListViewController()
            ble.mediator = self
            let navigation = UINavigationController(rootViewController: ble)
            controller.present(navigation, animated: true, completion: nil)
            break
        }
    }
    
    func showAlert(message:String, onController controller:UIViewController) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
        controller.present(alert, animated: true, completion: nil)
    }
}
