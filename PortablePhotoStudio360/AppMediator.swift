//
//  AppMediator.swift
//  PortablePhotoStudio360
//
//  Created by ChangChao-Tang on 2017/7/9.
//  Copyright © 2017年 ChangChao-Tang. All rights reserved.
//

import UIKit

class AppMediator: NSObject {
    
    private let window:UIWindow
    
    init(withWindow window:UIWindow) {
        self.window = window
    }
    
    func start() {
        window.rootViewController = TestViewController()
        window.makeKeyAndVisible()
    }
}
