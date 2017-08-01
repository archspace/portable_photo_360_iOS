//
//  BluListViewController.swift
//  PortablePhotoStudio360
//
//  Created by OSX9 on 2017/7/25.
//  Copyright © 2017年 ChangChao-Tang. All rights reserved.
//

import UIKit
import PinLayout

class BluListViewController: UIViewController ,UITableViewDelegate, UITableViewDataSource{
    weak var mediator:AppMediator?
    var info = [
        ["1","2","3","4","5","6"]
    ]
    let screenSize = UIScreen.main.bounds

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        self.navigationController?.navigationBar.topItem?.title = "搜尋藍芽裝置"
        let myTableView = UITableView(frame: CGRect(
            x: 0, y: 20,
            width: screenSize.width,
            height: screenSize.height - 20),
                                      style:.grouped)
        myTableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        
        myTableView.delegate = self
        myTableView.dataSource = self
        
        myTableView.separatorStyle = .singleLine
        
        myTableView.separatorInset = UIEdgeInsetsMake(0, 20, 0, 20)
        
        myTableView.allowsSelection = true
        
        myTableView.allowsMultipleSelection = false
        
        self.view.addSubview(myTableView)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    private func setupUI (){
        view.backgroundColor = UIColor.blue
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "選擇", style: .plain, target: self, action: #selector(selectDissmissView))
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return info[section].count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as UITableViewCell
        
        if let myLabel = cell.textLabel {
            myLabel.text = "\(info[indexPath.section][indexPath.row])"
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let cell = tableView.cellForRow(at: indexPath)
        
        for otherCell in tableView .visibleCells as [UITableViewCell] {
            if (cell == otherCell) {
                cell?.accessoryType = UITableViewCellAccessoryType.checkmark
            }else{
                otherCell.accessoryType = UITableViewCellAccessoryType.none
            }
        }
     
//        let name = info[indexPath.section][indexPath.row]

    }

    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "清單"
    }
   
    func selectDissmissView(){
        self .dismiss(animated:true, completion: nil)
    }

}
