//
//  AppMediator.swift
//  PortablePhotoStudio360
//
//  Created by ChangChao-Tang on 2017/7/9.
//  Copyright © 2017年 ChangChao-Tang. All rights reserved.
//

import UIKit

enum Route {
    case BluetoothList
}

class AppMediator: NSObject {
    
    private let window:UIWindow
    
    init(withWindow window:UIWindow) {
        self.window = window
        super.init()
    }
    
    func start() {
        let test = TestViewController()
        test.mediator = self
        window.rootViewController = test
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
