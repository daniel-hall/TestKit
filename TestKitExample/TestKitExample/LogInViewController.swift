//
//  LogInViewController.swift
//  TestKitExample
//
//  Created by Daniel Hall on 5/21/17.
//  Copyright © 2017 Daniel Hall. All rights reserved.
//

import UIKit

class LogInViewController: UIViewController, UITextFieldDelegate {
    
    @IBOutlet private var usernameField: UITextField! { didSet { usernameField?.becomeFirstResponder() } }
    @IBOutlet private var passwordField: UITextField!
    @IBOutlet private var loginButton: UIButton!
    
    var username:String = ""
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        username = usernameField.text ?? ""
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
         loginButton.isEnabled = usernameField.text?.isEmpty == false && passwordField.text?.isEmpty == false && !(textField.text?.characters.count == 1 && string.isEmpty)
        return true
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        switch textField {
        case usernameField:
            passwordField.becomeFirstResponder()
        case passwordField:
            if usernameField.text?.isEmpty == false && passwordField.text?.isEmpty == false {
                dismiss(animated: true)
                performSegue(withIdentifier: "Welcome", sender: self)
            }
        default:
            break
        }
        return true
    }
    
}
