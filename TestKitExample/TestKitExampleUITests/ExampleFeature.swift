//
//  ExampleFeature.swift
//  TestKitExample
//
//  Created by Daniel Hall on 5/21/17.
//  Copyright © 2017 Daniel Hall. All rights reserved.
//

import TestKit
import XCTest

extension NSError {
    convenience init(description:String) {
        self.init(domain: "TestKit", code: 0, userInfo: [NSLocalizedDescriptionKey: description])
    }
}

class ExampleFeature: TestKitFeature {
    
    static func tapButton(_ title:String) throws {
        let app = XCUIApplication()
        let button = app.buttons[title]
        if button.exists {
            button.tap()
        } else {
            throw NSError(description:"Couldn't find button with title \(title)")
        }
    }
    
    static func enterUsername(_ username:String){
        let app = XCUIApplication()
        let usernameTextField = app.textFields["username"]
        usernameTextField.tap()
        usernameTextField.typeText(username)
        app.keyboards.buttons["Next:"].tap()
    }
    
    static func enterPassword(_ password:String){
        let app = XCUIApplication()
        let passwordSecureTextField = app.secureTextFields["password"]
        passwordSecureTextField.tap()
        passwordSecureTextField.typeText(password)
    }
    
    override static func registerStepHandlers() {
        TestKit.given("I launch the app") {
            _ in
            XCUIApplication().launchWithTestKitEnabled()
        }
        
        TestKit.when("I tap the <buttonTitle> button$") {
            try tapButton($0.matchedValues["buttonTitle"])
        }
        
        TestKit.when("I enter the username <username>") {
            enterUsername($0.matchedValues["username"])
        }
        
        TestKit.when("I enter the password <password>") {
            enterPassword($0.matchedValues["password"])
        }
        
        TestKit.when("I log in as user <username> with password <password>") {
            enterUsername($0.matchedValues["username"])
            enterPassword($0.matchedValues["password"])
            try tapButton("Log In")
        }
    }
}
