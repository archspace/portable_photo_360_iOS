//
//  SliderViewController.swift
//  PortablePhotoStudio360
//
//  Created by OSX9 on 2017/9/4.
//  Copyright © 2017年 ChangChao-Tang. All rights reserved.
//

import UIKit
import CoreBluetooth
import PinLayout

protocol SliderViewControllerDelegate : NSObjectProtocol{
    func sliderDidUpdated(led1: Float, led2: Float, led3: Float)
}

class SliderViewController: UIViewController {
    var slider1 = UISlider()
    var slider2 = UISlider()
    var slider3 = UISlider()
    var timer:Timer?

    weak var delegate:SliderViewControllerDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(slider1)
        view.addSubview(slider2)
        view.addSubview(slider3)
        slider1.addTarget(self, action: #selector(onSliderChanged(slider:)), for: UIControlEvents.valueChanged)
        slider2.addTarget(self, action: #selector(onSliderChanged(slider:)), for: UIControlEvents.valueChanged)
        slider3.addTarget(self, action: #selector(onSliderChanged(slider:)), for: UIControlEvents.valueChanged)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        slider1.pin.bottom(30).left(10%).width(80%)
        slider2.pin.bottom(60).left(10%).width(80%)
        slider3.pin.bottom(90).left(10%).width(80%)

    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
    }
    
    func onSliderChanged(slider:UISlider){
        timer?.invalidate()
        timer = nil
        timer = Timer.scheduledTimer(timeInterval: 0.2, target: self, selector: #selector(onSliderFire), userInfo: nil, repeats: false)
    }
    
    func onSliderFire() {
        delegate?.sliderDidUpdated(led1: slider1.value, led2: slider2.value, led3: slider3.value)
    }
    

}
