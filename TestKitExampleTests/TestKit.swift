//
//  TestKit.swift
//  TestKitExample
//
//  Created by Daniel Hall on 11/6/16.
//  Copyright © 2016 Daniel Hall. All rights reserved.
//

import Foundation
import XCTest


protocol TestableOutput {
    associatedtype ExpectedOutputType
    func validate(expected output: ExpectedOutputType) -> Bool
}

final class TestKitDictionary {
    fileprivate let dictionary: [String:Any]
    fileprivate let file:String
    fileprivate let testcase:String
    fileprivate var usedKeys = [String]()
    fileprivate var unusedKeys:[String] {
        return Array(Set(dictionary.keys).subtracting(Set(usedKeys)))
    }
    
    fileprivate init(dictionary:[String: Any], file:String, testcase:String) {
        self.dictionary = dictionary
        self.file = file
        self.testcase = testcase
    }
    
    subscript(key: String) -> Any? {
        usedKeys.append(key)
        return dictionary[key]
    }
    
    fileprivate func verifyAllKeysUsed() -> Bool {
        return Set(usedKeys).isSuperset(of: Array(dictionary.keys))
    }
}


enum TestKit {
    
    private struct Case {
        let name:String
        let description:String?
        let inputs:[Any]?
        let expectedOutput:Any?
        let expectedOutputType:String?
        let expectedErrorType:String?
        
        init(from dictionary:[String:Any], filename:String) {
            guard let name = dictionary["name"] as? String else {
                XCTFail("Missing or wrong type of value for test case name (key: \"name\") in file \(filename)")
                fatalError()
            }
            guard dictionary.keys.contains("inputs") else {
                XCTFail("Missing value for test case input (key: \"inputs\") for test case \"\(name)\" in file \(filename)")
                fatalError()
            }
            guard dictionary.keys.contains("expected-output") else {
                XCTFail("Missing value for test case expected output (key: \"expected-output\") for test case \"\(name)\" in file \(filename)")
                fatalError()
            }
            
            self.name = name
            self.description = dictionary["description"] as? String
            if dictionary["inputs"] is NSNull {
                self.inputs = [NSNull()]
            } else if let input = dictionary["inputs"] as? [Any] {
                self.inputs = input
            } else if let input = dictionary["inputs"] {
                self.inputs = [input]
            } else {
                self.inputs = []
            }
            self.expectedOutput = dictionary["expected-output"] is NSNull ? nil : dictionary["expected-output"]
            self.expectedOutputType = dictionary["expected-output-type"] as? String
            self.expectedErrorType = dictionary["expected-error-type"] as? String
        }
    }
    
    
    static func runTestCases<Input, Output:TestableOutput>(file:String, testClosure:(Input) -> Output) {
        
        guard let url = Bundle(for:TestKitDictionary.self).url(forResource: file, withExtension: "testkit") else {
            XCTFail("No TestKit test file was found with the name \(file).testkit")
            return
        }
        
        guard let data = try? Data(contentsOf:url) else {
            XCTFail("The TestKit file named \(file).testkit could not be read")
            return
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data, options: []) else {
            XCTFail("The TestKit file named \(file).testkit contains invalid JSON")
            return
        }
        
        guard let dictionary = json as? [String:Any] else {
            XCTFail("The TestKit JSON file named \(file).testkit does not have a dictionary as the root element.")
            return
        }
        
        guard let array = dictionary["test-cases"] as? [[String:Any]] else {
            XCTFail("The TestKit JSON file named \(file).testkit does not have an array of cases for the key \"test-cases\"")
            return
        }
        
        let cases = array.map{ Case(from: $0, filename: file) }
        var failedCases = [Case]()
        cases.forEach{
            testCase in
            var casePassed = true
            testCase.inputs?.enumerated().forEach {
                inputTuple in
                
                func fail(_ message:String) {
                    XCTFail(message)
                    failedCases.append(testCase)
                    casePassed = false
                    print("Test Case: \"\(testCase.name)\", input \(inputTuple.offset + 1)/\(testCase.inputs?.count ?? 0) failed")
                }
                
                var uncheckedInput:Any? = inputTuple.element is NSNull ? nil : inputTuple.element
                
                if let inputType = Input.self as? ExpressibleByNilLiteral.Type, uncheckedInput == nil {
                    uncheckedInput = inputType.init(nilLiteral: ())
                }
                
                guard let input = uncheckedInput as? Input else {
                    fail("The input: \(uncheckedInput) for test case: \"\(testCase.name)\" in file: \"\(file)\" did not have the expected type: \(Input.self)")
                    return
                }
                
                let output = testClosure(input)
                
                var uncheckedOutput:Any? = testCase.expectedOutput is NSNull ? nil : testCase.expectedOutput
                uncheckedOutput = uncheckedOutput is [String:Any] ? TestKitDictionary(dictionary: uncheckedOutput as! [String:Any], file: file, testcase: testCase.name) : uncheckedOutput
                
                guard let expectedOutput = uncheckedOutput as? Output.ExpectedOutputType else {
                    fail("The expectedOutput: \(uncheckedOutput) for test case: \(testCase.name) in file: \(file) did not have the expected type: \(Output.ExpectedOutputType.self)")
                    return
                }
                if !output.validate(expected: expectedOutput) {
                    fail("The output for the test case named: \"\(testCase.name)\" in file named:\"\(file)\" did not pass validation against the expected output. To debug, place a breakpoint in your validate(expected:) function implementation for the TestableOutput created in this test.")
                    return
                }
                if let expectedOutput = expectedOutput as? TestKitDictionary {
                    if !expectedOutput.verifyAllKeysUsed() {
                        fail("Some expected output from test case named: \"\(testCase.name)\" in file named:\"\(file)\" was not verified. Please ensure that your TestableOutput implementation of the validate(exepected:) function includes using the following untested keys from the TestKitDictionary expected ouput as part of the validation code:\(expectedOutput.unusedKeys)")
                        return
                    }
                }
                
                print("Test Case: \"\(testCase.name)\", input \(inputTuple.offset + 1)/\(testCase.inputs?.count ?? 0) verified")
            }
            print("Test Case: \"\(testCase.name)\" \(casePassed ? "passed" : "failed")")
        }
        print("\(cases.count - failedCases.count)/\(cases.count) test cases passed for the file: \(file)")
    }
    
    static func runTestCases<Input, Output:TestableOutput>(file:String, testClosure:(Input) -> Output?) {
        
        guard let url = Bundle(for:TestKitDictionary.self).url(forResource: file, withExtension: "testkit") else {
            XCTFail("No TestKit test file was found with the name \(file).testkit")
            return
        }
        
        guard let data = try? Data(contentsOf:url) else {
            XCTFail("The TestKit file named \(file).testkit could not be read")
            return
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data, options: []) else {
            XCTFail("The TestKit file named \(file).testkit contains invalid JSON")
            return
        }
        
        guard let dictionary = json as? [String:Any] else {
            XCTFail("The TestKit JSON file named \(file).testkit does not have a dictionary as the root element.")
            return
        }
        
        guard let array = dictionary["test-cases"] as? [[String:Any]] else {
            XCTFail("The TestKit JSON file named \(file).testkit does not have an array of cases for the key \"test-cases\"")
            return
        }
        
        let cases = array.map{ Case(from: $0, filename: file) }
        var failedCases = [Case]()
        cases.forEach{
            testCase in
            var casePassed = true
            testCase.inputs?.enumerated().forEach {
                inputTuple in
                
                func fail(_ message:String) {
                    XCTFail(message)
                    failedCases.append(testCase)
                    casePassed = false
                    print("Test Case: \"\(testCase.name)\", input \(inputTuple.offset + 1)/\(testCase.inputs?.count ?? 0) failed")
                }
                
                var uncheckedInput:Any? = inputTuple.element is NSNull ? nil : inputTuple.element
                
                if let inputType = Input.self as? ExpressibleByNilLiteral.Type, uncheckedInput == nil {
                    uncheckedInput = inputType.init(nilLiteral: ())
                }
                
                guard let input = uncheckedInput as? Input else {
                    fail("The input: \(uncheckedInput) for test case: \"\(testCase.name)\" in file: \"\(file)\" did not have the expected type: \(Input.self)")
                    return
                }
                
                let output = testClosure(input)
                
                var uncheckedOutput:Any? = testCase.expectedOutput is NSNull ? nil : testCase.expectedOutput
                uncheckedOutput = uncheckedOutput is [String:Any] ? TestKitDictionary(dictionary: uncheckedOutput as! [String:Any], file: file, testcase: testCase.name) : uncheckedOutput
                
                if let output = output {
                    
                    guard let expectedOutput = uncheckedOutput as? Output.ExpectedOutputType else {
                        fail("The expectedOutput: \(uncheckedOutput) for test case: \(testCase.name) in file: \(file) did not have the expected type: \(Output.ExpectedOutputType.self)")
                        return
                    }
                    
                    if (expectedOutput as Any?) != nil || (output as Any?) != nil {
                        let validated = output.validate(expected: expectedOutput)
                        if !validated {
                            fail("The output for the test case named: \"\(testCase.name)\" in file named:\"\(file)\" did not pass validation against the expected output. To debug, place a breakpoint in your validate(expected:) function implementation for the TestableOutput created in this test.")
                            return
                        }
                        if let expectedOutput = expectedOutput as? TestKitDictionary {
                            if !expectedOutput.verifyAllKeysUsed() {
                                fail("Some expected output from test case named: \"\(testCase.name)\" in file named:\"\(file)\" was not verified. Please ensure that your TestableOutput implementation of the validate(exepected:) function includes using the following untested keys from the TestKitDictionary expected ouput as part of the validation code:\(expectedOutput.unusedKeys)")
                                return
                            }                        }
                    }
                } else if uncheckedOutput != nil {
                    fail("The output for the test case named: \"\(testCase.name)\" in file named:\"\(file)\" did not pass validation, because the returned value was nil, but the expected output specified in the test case JSON was non-nil")
                    return
                }
                print("Test Case: \"\(testCase.name)\", input \(inputTuple.offset + 1)/\(testCase.inputs?.count ?? 0) verified")
            }
            print("Test Case: \"\(testCase.name)\" \(casePassed ? "passed" : "failed")")
        }
        print("\(cases.count - failedCases.count)/\(cases.count) test cases passed for the file: \(file)")
    }
    
}
