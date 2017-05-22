//
//  ExampleUnitTestFeature.swift
//  TestKitExample
//
//  Created by Daniel Hall on 5/22/17.
//  Copyright © 2017 Daniel Hall. All rights reserved.
//

import Foundation
import TestKit
@testable import TestKitExample

extension Bool: TestKitUnitTestOutput {
    public func validate(against: TestKitUnitTestData) -> Bool {
        switch against.value.lowercased() {
        case "true":
            return self == true
        case "false":
            return self == false
        default:
            return false
        }
    }
}

class ExampleUnitTestFeature: TestKitFeature {
    override static func registerStepHandlers() {
        TestKit.when("I call the function validatePassword") {
            _ in
            UnitTestFeature.output = validatePassword(UnitTestFeature.input!.value)
        }
    }
}
