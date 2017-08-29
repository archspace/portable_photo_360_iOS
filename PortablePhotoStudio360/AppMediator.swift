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
    case Camera
}

extension Notification.Name {
    static let BLEStateChange = Notification.Name(rawValue: "BLEStateChange")
}

class AppMediator: NSObject {
    
    private let window:UIWindow
    
    let bleCentralService:BluetoothCentralService
    let rootNavigation:UINavigationController
    
    init(withWindow window:UIWindow) {
        self.window = window
        bleCentralService = BluetoothCentralService{(state) in
            NotificationCenter.default.post(name: .BLEStateChange, object: nil, userInfo: ["state": stat])
        }
        let ble = BLEListViewController()
        rootNavigation = UINavigationController(rootViewController: ble)
        super.init()
        ble.mediator = self
    }
    
    func start() {
        window.rootViewController = rootNavigation
        window.makeKeyAndVisible()
    }
    
    func toRoute(route:Route, fromController controller:UIViewController?, userInfo: [AnyHashable: Any]?) {
        switch route {
        case .BluetoothList:
            rootNavigation.popToRootViewController(animated: true)
            break
        case .Camera:
            guard let peripheral = userInfo?["peripheral"] as? CBPeripheral else {
                return
            }
            let photo = PhotoViewController()
            photo.mediator = self
            photo.pService = BluetoothPeripheralService(p: peripheral)
            rootNavigation.pushViewController(photo, animated: true)
            break
        }
    }
    
    func showAlert(message:String, onController controller:UIViewController) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
        controller.present(alert, animated: true, completion: nil)
    }
}
