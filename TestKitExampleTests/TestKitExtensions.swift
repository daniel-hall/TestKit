//
//  TestKitExtensions.swift
//  TestKitExample
//
//  Created by Daniel Hall on 11/28/16.
//  Copyright © 2016 Daniel Hall. All rights reserved.
//

import Foundation
@testable import TestKitExample

extension Bool : TestableOutput {
    typealias ExpectedOutputType = Bool
    func validate(expected output: Bool) -> Bool {
        return self == output
    }
}

extension String : TestableOutput {
    typealias ExpectedOutputType = String
    func validate(expected output: String) -> Bool {
        return self == output
    }
}

extension Int: TestableOutput {
    typealias ExpectedOutputType = Int
    func validate(expected output: Int) -> Bool {
        return self == output
    }
}

extension Person : TestableOutput {
    typealias ExpectedOutputType = TestKitDictionary
    func validate(expected output: TestKitDictionary) -> Bool {
        var success = true
        // If a "full-name" key is specified in the expected-output dictionary, make sure it matches my own fullName value, otherwise validation fails. If no "full-name" key is expected, it won't be verified.
        if let expected = output["full-name"] {
            success = (expected as? String) == fullName ? success : false
        }
        if let expected = output["first-name"] {
            success = (expected as? String) == firstName ? success : false
        }
        if let expected = output["last-name"] {
            success = (expected as? String) == lastName ? success : false
        }
        if let expected = output["age"] {
            success = (expected as? Int) == age ? success : false
        }
        return success
    }
}

extension ParsingError: TestableError {
    func validate(expected output: TestKitDictionary) -> Bool {
        guard let type = output["type"] as? String, let typeEnum = ParsingError.ParsingErrorType.init(rawValue: type) else {
            return false
        }
        return self.type == typeEnum
    }
}
