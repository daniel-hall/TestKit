//
//  TestKitExampleTests.swift
//  TestKitExampleTests
//
//  Created by Daniel Hall on 11/6/16.
//  Copyright © 2016 Daniel Hall. All rights reserved.
//

import XCTest
@testable import TestKitExample


class TestKitExampleTests: XCTestCase {
    
    func testIsValidPassword() {
        let spec = TestKitSpec.init(file: "ValidPasswordTests") { XCTFail($0.message) }
        spec.run(){
            (input:String) -> Bool in
            return isValidPassword(string: input)
        }
    }
    
    func testParseInt() {
        let spec = TestKitSpec.init(file: "ParseIntTests") { XCTFail($0.message) }
        spec.run(){
            (input:[String: Any]) throws -> Int in
            return try parseInt(from: input, key: "test-key")
        }
    }
    
    func testStringForInt() {
        let spec = TestKitSpec.init(file: "StringForIntTests") { XCTFail($0.message) }
        spec.run(){
            (input:Int) -> String? in
            return stringValue(for: input)
        }
    }
    
    func testPerson() {
        let spec = TestKitSpec.init(file: "PersonTests") { XCTFail($0.message) }
        spec.run(){
            (input:[String:Any]) -> Person in
            return Person(first: input["first"] as! String, last: input["last"] as! String, age:input["age"] as? Int ?? 18)
        }
    }
    
}
