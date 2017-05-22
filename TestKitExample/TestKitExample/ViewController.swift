//
//  ViewController.swift
//  TestKitExample
//
//  Created by Daniel Hall on 5/21/17.
//  Copyright © 2017 Daniel Hall. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    var didAppearClosure:(()->())?
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let welcome = segue.destination as? WelcomeViewController, let login = sender as? LogInViewController {
            welcome.welcomeMessage = "Welcome \(login.username)!"
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        didAppearClosure?()
        didAppearClosure = nil
    }
    
    @IBAction func goToWelcome(segue: UIStoryboardSegue) {
        guard let source = segue.source as? LogInViewController else {
            return
        }
        didAppearClosure = {
            [weak self, weak source] in
            self?.performSegue(withIdentifier: "Welcome", sender: source)
            isLoggedIn = true
        }
    }
    
    @IBAction func logOut(segue: UIStoryboardSegue) {
        isLoggedIn = false
    }

}

