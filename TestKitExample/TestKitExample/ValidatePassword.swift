//
//  ValidatePassword.swift
//  TestKitExample
//
//  Created by Daniel Hall on 5/22/17.
//  Copyright © 2017 Daniel Hall. All rights reserved.
//

import Foundation

func validatePassword(_ password:String) -> Bool {
    // At least 8 characters
    guard password.characters.count >= 8 else {
        return false
    }
    // Mix of upper and lower case letters
    guard password.lowercased() != password && password.uppercased() != password else {
        return false
    }
    // At least 1 number
    guard password.range(of:"\\d+", options: [.regularExpression, .caseInsensitive]) != nil else {
        return false
    }
    return true
}
