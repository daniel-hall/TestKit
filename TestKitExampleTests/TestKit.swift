//
//  TestKit.swift
//  TestKitExample
//
//  Created by Daniel Hall on 11/6/16.
//  Copyright © 2016 Daniel Hall. All rights reserved.
//

import Foundation

typealias TestInput = [String:Any]

struct TestKitError: Error {
    let type:String
    let description:String
    let error:Error?
    let info:[String:Any]
    
    init(type:String = "", description:String = "", error:Error? = nil, info:[String:Any] = [String:Any]()) {
        self.type = type
        self.description = description
        self.error = error
        self.info = info
    }
    
    static func TestFileNotFound(filename:String)-> TestKitError {
        return TestKitError(type:"TestFileNotFound", description:"No TestKit test file was found with the name \(filename)")
    }
    
    static func TestFileCouldNotBeRead(filename:String, error:Error? = nil) -> TestKitError {
        return TestKitError(type:"TestFileCouldNotBeRead", description:"The TestKit file named \"\(filename)\" could not be read", error:error)
    }
    
    static func TestFileContainsInvalidJSON(filename:String, error:Error? = nil) -> TestKitError {
        return TestKitError(type:"TestFileContainsInvalidJSON", description:"The TestKit file named \"\(filename)\" contains invalid JSON", error:error)
    }
}

/// Base class or superclass that encapsulates the dictionary in a TestKit file describing what the expected output for a given input should look like.  Can be subclassed with convenience properties for accessing keys, etc. Also tracks which keys were accessed and throws error if every key specified in expected output isn't accessed for validation.
class TestKitExpectedOutput {
    private let outputDictionary:[String:Any]
    required init(expectedOutput:[String:Any]) {
        outputDictionary = expectedOutput
    }
    
    func value<T>(for key:String) -> T? {
        if let value = outputDictionary[key] as? T {
            // mark key as used
            return value
        }
        return nil
    }
    
    fileprivate func verifyAllKeysUsed() throws {
        // check to make sure all keys were accessed
    }
}

protocol TestableOuput {
    associatedtype ExpectedOutputType:TestKitExpectedOutput
    func validate(expected output: ExpectedOutputType) throws -> Bool
}


enum TestKit {
    
    private struct Case {
        let name:String
        let description:String?
        let inputs:[Any]
        let expectedOutput:
        
    }
    
    static func runTests<Output:TestableOuput>(file:String, testClosure:(TestInput) throws -> Output) throws {
        // load file
        let components = file.components(separatedBy: ".")
        
        guard let url = Bundle.main.url(forResource: components.first, withExtension: components.last) else {
            throw TestKitError(type:"TestFileNotFound", description:"No TestKit test file was found with the name \(file)")
        }

        do {
            let data = try Data(contentsOf:url)
            do {
                let json = try JSONSerialization.jsonObject(with: data, options: [])
                guard let array = json as? [[String:Any]] else {
                    throw TestKitError(type:"TestKitRootElementNotAnArray", description:"The root element of the TestKit JSON file \"\(file)\" is not an array. TestKit json should contain an array of cases.")

                }
            }
            catch {
                throw TestKitError(type:"TestFileContainsInvalidJSON", description:"The TestKit file named \"\(file)\" contains invalid JSON", error:error)
            }
        }
        catch {
            throw TestKitError(type:"TestFileCouldNotBeRead", description:"The TestKit file named \"\(file)\" could not be read", error:error)
        }


        // parse cases
        scenarios.forEach{
            $0.inputs.forEach {
                let output = try initializatationClosure($0.input) // Make sure we get a valid ouput for input
                let expectedOutput = T.ExpectedOutputType.init(scenario.output)
                let validated = try output.validate(against: expectedOutput) // Validate it against expected output
                if !validated { throw NSError(domain:"", code:0, userInfo:[NSLocalizedDescriptionKey:"output did not pass validation"]) }
                try expectedOutput.verifyAllKeysUsed()
            }
        }
    }
}
