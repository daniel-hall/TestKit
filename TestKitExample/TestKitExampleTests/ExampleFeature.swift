//
//  ExampleFeature.swift
//  TestKitExample
//
//  Created by Daniel Hall on 5/21/17.
//  Copyright © 2017 Daniel Hall. All rights reserved.
//

import UIKit
import TestKit
@testable import TestKitExample

extension NSError {
    convenience init(description:String) {
        self.init(domain: "TestKit", code: 0, userInfo: [NSLocalizedDescriptionKey: description])
    }
}

extension UIViewController {
    var topmostViewController: UIViewController {
        if let navigationController = self.navigationController {
            return navigationController.topmostViewController
        } else if let presentedViewController = self.presentedViewController {
            return presentedViewController.topmostViewController
        } else if let selfNavigationController = self as? UINavigationController {
            return selfNavigationController.topViewController ?? selfNavigationController
        } else {
            return self
        }
    }
}

var colorTable: [String: UIColor] = [
    "green": UIColor(displayP3Red: 0, green: 1, blue: 0, alpha: 1),
    "light gray": UIColor(displayP3Red: 170/255, green: 170/255, blue: 170/255, alpha: 1)
]

var screenTable: [String: UIViewController.Type] = [
    "Welcome": WelcomeViewController.self
]

class ExampleFeature: TestKitFeature {
    override static func registerStepHandlers() {
        
        then("the <buttonIdentifier> button is disabled") {
            guard let button = views(ofType: UIButton.self, accessibilityIdentifier: $0.matchedValues["buttonIdentifier"]).first else {
                throw NSError(description: "Couldn't find button in current view hierarchy with the accessibility identifier '\($0.matchedValues["buttonIdentifier"])'")
            }
            guard button.isEnabled == false else {
                throw NSError(description: "Button with accessibility identifier '\($0.matchedValues["buttonIdentifier"])' was not disabled")
            }
        }
        
        then("the <buttonIdentifier> button is enabled") {
            guard let button = views(ofType: UIButton.self, accessibilityIdentifier: $0.matchedValues["buttonIdentifier"]).first else {
                throw NSError(description: "Couldn't find button in current view hierarchy with the accessibility identifier '\($0.matchedValues["buttonIdentifier"])'")
            }
            guard button.isEnabled else {
                throw NSError(description: "Button with accessibility identifier '\($0.matchedValues["buttonIdentifier"])' was not disabled")
            }
        }
        
        then("the <buttonIdentifier> button color is <buttonColor>") {
            guard let button = views(ofType: UIButton.self, accessibilityIdentifier: $0.matchedValues["buttonIdentifier"]).first else {
                throw NSError(description: "Couldn't find button in current view hierarchy with the accessibility identifier '\($0.matchedValues["buttonIdentifier"])'")
            }
            guard button.currentTitleColor == colorTable[$0.matchedValues["buttonColor"]] else {
                throw NSError(description: "Button with accessibility identifier '\($0.matchedValues["buttonIdentifier"])' did not have the titleColor \($0.matchedValues["buttonColor"])")
            }
        }
        
        then("isLoggedIn is <trueOrFalse>") {
            switch $0.matchedValues["trueOrFalse"] {
            case "true":
                guard isLoggedIn == true else { throw NSError(description: "isLogged in was false, not true") }
            case "false":
                guard isLoggedIn == false else { throw NSError(description: "isLogged in was true, not false") }
            default:
                throw NSError(description: "Can only validate if isLoggedIn is 'true' or 'false', not '\($0.matchedValues["trueOrFalse"])'")
            }
        }
        
        then("I am on the <screenName> screen") {
            guard let topViewController = UIApplication.shared.delegate?.window??.rootViewController?.topmostViewController ?? nil else {
                throw NSError(description: "Couldn't get root view controller")
            }
            guard let classToCheck = screenTable[$0.matchedValues["screenName"]] else {
                throw NSError(description: "No registered class for screenName '\($0.matchedValues["screenName"])'")
            }
            guard topViewController.isKind(of: classToCheck) else {
                throw NSError(description: "The current view controller is not of type \(classToCheck)")
            }
        }
    }
}
