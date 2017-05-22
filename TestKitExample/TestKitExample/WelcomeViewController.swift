//
//  WelcomeViewController.swift
//  TestKitExample
//
//  Created by Daniel Hall on 5/21/17.
//  Copyright © 2017 Daniel Hall. All rights reserved.
//

import UIKit

class WelcomeViewController: UIViewController {
    
    @IBOutlet private var welcomeLabel: UILabel!
    var welcomeMessage: String = "Welcome!"
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        welcomeLabel.text = welcomeMessage
        navigationItem.hidesBackButton = true
    }
}
