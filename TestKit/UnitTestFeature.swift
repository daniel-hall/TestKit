//
//  UnitTestFeature.swift
//  TestKit
//
// Copyright (c) 2018 Daniel Hall
// Twitter: @_danielhall
// GitHub: https://github.com/daniel-hall
// Website: http://danielhall.io
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//


import Foundation


public struct TestKitUnitTestError: Error {
    public let localizedDescription: String
}

public protocol TestKitUnitTestOutput {
    func validate(against: TestKitUnitTestData) -> Bool
}

public struct TestKitUnitTestData {
    public let value: String
    public let docString: String?
    public let dataTable: [[String: String]]?
}

/// A built-in test feature that provides step handlers for writing and verifying unit (spec) tests
public class UnitTestFeature: TestKitFeature {
    public static var input: TestKitUnitTestData?
    public static var output: TestKitUnitTestOutput?
    public static var error: TestKitUnitTestOutput?
    
    public override class func registerStepHandlers() {
        given("the unit test input is <input>") {
            input = TestKitUnitTestData(value: $0.matchedValues["input"], docString: $0.docString, dataTable: $0.dataTable)
            output = nil
            error = nil
        }
        
        then("the unit test output is <output>") {
            if error != nil {
                throw TestKitUnitTestError(localizedDescription: "The unit test resulted in an error, but no error was expected")
            } else if let output = output {
                if !output.validate(against: TestKitUnitTestData(value: $0.matchedValues["output"], docString: $0.docString, dataTable: $0.dataTable)) {
                    throw TestKitUnitTestError(localizedDescription: "The unit test output didn't pass validation / match the expected output")
                }
            } else if output == nil, $0.matchedValues["output"] != "null" {
                throw TestKitUnitTestError(localizedDescription: "The unit test output was nil, but output was not expected to be null")
            }
        }
        
        then("an error is thrown") {
            if let error = error {
                if !error.validate(against: TestKitUnitTestData(value: $0.matchedValues["input"], docString: $0.docString, dataTable: $0.dataTable)) {
                    throw TestKitUnitTestError(localizedDescription: "The unit test produced an error that didn't pass validation / match the expected error")
                }
            } else {
                throw TestKitUnitTestError(localizedDescription: "The unit test was expected to throw and error, but it did not")
            }
        }
    }
}
