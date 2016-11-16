//
//  TestKitExampleTests.swift
//  TestKitExampleTests
//
//  Created by Daniel Hall on 11/6/16.
//  Copyright © 2016 Daniel Hall. All rights reserved.
//

import XCTest
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

extension Person : TestableOutput {
    typealias ExpectedOutputType = TestKitDictionary
    func validate(expected output: TestKitDictionary) -> Bool {
        guard let full = output["fullName"] as? String, let age = output["age"] as? Int, let first = output["firstName"] as? String else {
            return false
        }
        return fullName == full && self.age == age && firstName == first
    }
}


class TestKitExampleTests: XCTestCase {
    
    func testIsValidInt() {
        TestKit.runTestCases(file: "test"){
            (input:Any?) -> Bool in
            return isValidInt(int: input)
        }
    }
    
    func testMatch() {
        TestKit.runTestCases(file: "MatchTest") {
            (input:Int) -> String? in
            return matchingValue(for: input)
        }
    }
    
    func testPerson() {
        TestKit.runTestCases(file: "ValidPersonTests") {
            (input:[String:Any]) -> Person in
            return Person(first: input["first"] as! String, last: input["last"] as! String, age:input["age"] as? Int ?? 18)
        }
    }
    
}
