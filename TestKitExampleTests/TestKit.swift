//
//  TestKit.swift
//  TestKitExample
//
//  Created by Daniel Hall on 11/6/16.
//  Copyright © 2016 Daniel Hall. All rights reserved.
//

import Foundation
import XCTest


/// Protocol that must be adopted by any type being returned from a test closure / function under test. The protocol allows the value to be validated against the expected output defined in the TestKit spec
protocol TestableOutput {
    associatedtype ExpectedOutputType
    func validate(expected output: ExpectedOutputType) -> Bool
}

/// Protocol that must be adopted by any Error being returned thrown a test closure / function under test if the TestKit spec has an expected output describing how to validate the error
protocol TestableError {
    func validate(expected output: TestKitDictionary) -> Bool
}

/// Wrapper around a normal Swift [String: Any] dictionary that additionally tracks when its keys are accessed and can validate that all the keys of the wrapped dictionary were accessed. Any time the expected output in a TestKit spec is a dictionary, is gets converted to a TestKitDictionary for validation
final class TestKitDictionary {
    fileprivate let dictionary: [String:Any]
    fileprivate var usedKeys = [String]()
    fileprivate var unusedKeys:[String] {
        return Array(Set(dictionary.keys).subtracting(Set(usedKeys)))
    }
    
    fileprivate init(dictionary:[String: Any]) {
        self.dictionary = dictionary
    }
    
    subscript(key: String) -> Any? {
        usedKeys.append(key)
        return dictionary[key]
    }
    
    fileprivate func verifyAllKeysUsed() -> Bool {
        return Set(usedKeys).isSuperset(of: Array(dictionary.keys))
    }
}

/// Parses and runs the test data from a TestKit json file
struct TestKitSpec {
    let testDescription:String?
    let testCases:[TestKitCase]
    let sourceFile:String
    
    private var fileError:Bool = false
    private let failureHandler:(TestKitFailure)->()
    
    fileprivate var casesExist:Bool {
        return testCases.count > 0
    }
    
    init(file:String, failureHandler:@escaping (TestKitFailure)->()) {
        var cases = [TestKitCase]()
        var description:String? = nil
        let components = file.components(separatedBy: ".")
        let file = components.count > 1 ? components.dropLast().joined(separator: ".") : components.joined()
        if let url = Bundle(for:TestKitDictionary.self).url(forResource: file, withExtension: "testkit") {
            let file = file + ".testkit"
            if let data = try? Data(contentsOf:url) {
                if let json = try? JSONSerialization.jsonObject(with: data, options: []) {
                    if let dictionary = json as? [String:Any] {
                        description = dictionary["test-description"] as? String
                        if let array = dictionary["test-cases"] as? [[String:Any]] {
                            let parsedCases = array.flatMap{ TestKitCase(from: $0, file:(file), fail:{ TestKitSpec.fail(with: $0, failureHandler: failureHandler) }) }
                            cases = parsedCases.count == array.count ? parsedCases : cases
                        } else {
                            TestKitSpec.fail(with: TestKitFailure(message:"The TestKit JSON file named \"\(file)\" does not have an array of cases for the key \"test-cases\"", file:file), failureHandler: failureHandler)
                            fileError = true
                        }
                    }else {
                        TestKitSpec.fail(with: TestKitFailure(message:"The TestKit JSON file named \"\(file)\" does not have a dictionary as the root element.", file:file), failureHandler: failureHandler)
                        fileError = true
                    }
                } else {
                    TestKitSpec.fail(with: TestKitFailure(message:"The TestKit file named \"\(file)\" contains invalid JSON", file:file), failureHandler: failureHandler)
                    fileError = true
                }
            } else {
                TestKitSpec.fail(with: TestKitFailure(message:"The TestKit file named \"\(file)\" could not be read", file:file), failureHandler: failureHandler)
                fileError = true
            }
        }else {
            TestKitSpec.fail(with: TestKitFailure(message:"No TestKit test file was found with the name \"\(file).testkit\"", file:file+".testkit"), failureHandler: failureHandler)
            fileError = true
        }
        
        testCases = cases
        testDescription = description
        sourceFile = file + ".testkit"
        self.failureHandler = failureHandler
    }
    
    // MARK: Private Static Functions
    
    static private func fail(with failure:TestKitFailure, failureHandler:@escaping (TestKitFailure)->()) {
        let closure = {
            let observer = TestObserver()
            observer.register()
            print("\n")
            failureHandler(failure)
            if !observer.failureReported {
                XCTFail(failure.message)
            }
            observer.unregister()
        }
        
        if !Thread.current.isMainThread {
            DispatchQueue.main.sync(execute: closure)
        } else {
            closure()
        }
    }
    
    // MARK: Public Functions
    
    func run<Input, Output:TestableOutput>(testClosure:@escaping (Input)->Output) {
        if fileError { return }
        if casesExist {
            print("\nTESTKIT: Running tests from file: \"\(sourceFile)\"")
            var failedCases = 0
            testCases.forEach{
                testCase in
                print("\n\tTESTKIT: Starting test case named:\"\(testCase.name)\"")
                let result = testCase.inputs.enumerated().reduce(TestState<Input, Output>(testSpec:self, testCase:testCase, testClosure:testClosure)){
                    (reduceInput:(initialState:TestState<Input, Output>, input:(Int, Any))) -> TestState<Input, Output>  in
                    return castInput(input: reduceInput.input).flatMap(failIfExpectErrorFromNonThrowingClosure).flatMap(outputForInput).flatMap(validatedOutput).flatMap(nonNilOutputIsSuccess).flatMap(printCaseSuccess).flatMap(printCaseFailed).runState(reduceInput.initialState).state
                }
                print("\tTESTKIT: The test case named:\"\(result.testCase.name)\" has \(result.casePassed ? "PASSED" : "FAILED") \n")
                failedCases = result.casePassed ? failedCases : failedCases + 1
            }
            print("\nTESTKIT: \(testCases.count - failedCases)/\(testCases.count) test cases PASSED for the file: \"\(sourceFile)\" \n")
        } else {
            fail(with: TestKitFailure(message:"No valid test cases found in the file \"\(sourceFile)\". Unable to run. \n", file:sourceFile))
        }
    }
    
    func run<Input, Output:TestableOutput>(testClosure:@escaping (Input) throws -> Output) {
        if fileError { return }
        if casesExist {
            print("\nTESTKIT: Running tests from file: \"\(sourceFile)\"")
            var failedCases = 0
            testCases.forEach{
                testCase in
                print("\n\tTESTKIT: Starting test case named:\"\(testCase.name)\"")
                let result = testCase.inputs.enumerated().reduce(TestState<Input, Output>(testSpec:self, testCase:testCase, testClosure:testClosure)){
                    (reduceInput:(initialState:TestState<Input, Output>, input:(Int, Any))) -> TestState<Input, Output>  in
                    return castInput(input: reduceInput.input).flatMap(outputForInput).flatMap(validatedOutput).flatMap(nonNilOutputIsSuccess).flatMap(printCaseSuccess).flatMap(checkForExpectedErrorIfNotSuccess).flatMap(castInput).flatMap(expectErrorOrFail).flatMap(validateError).flatMap(printCaseSuccess).flatMap(printCaseFailed).runState(reduceInput.initialState).state
                }
                print("\tTESTKIT: The test case named:\"\(result.testCase.name)\" has \(result.casePassed ? "PASSED" : "FAILED") \n")
                failedCases = result.casePassed ? failedCases : failedCases + 1
            }
            print("\nTESTKIT: \(testCases.count - failedCases)/\(testCases.count) test cases PASSED for the file: \"\(sourceFile)\" \n")
        } else {
            fail(with: TestKitFailure(message:"No valid test cases found in the file \"\(sourceFile)\". Unable to run. \n", file:sourceFile))
        }
    }
    
    func run<Input, Output:TestableOutput>(testClosure:@escaping (Input)->Output?) {
        if fileError { return }
        if casesExist {
            print("\nTESTKIT: Running tests from file: \"\(sourceFile)\"")
            var failedCases = 0
            testCases.forEach{
                testCase in
                print("\n\tTESTKIT: Starting test case named:\"\(testCase.name)\"")
                
                let result = testCase.inputs.enumerated().reduce(TestState<Input, Output>(testSpec:self, testCase:testCase, testClosure:testClosure)){
                    (reduceInput:(initialState:TestState<Input, Output>, input:(Int, Any))) -> TestState<Input, Output>  in
                    return castInput(input: reduceInput.input).flatMap(failIfExpectErrorFromNonThrowingClosure).flatMap(outputForInput).flatMap(validatedOutput).flatMap(nilOptionalOutputMightBeSuccess).flatMap(printCaseSuccess).flatMap(printCaseFailed).runState(reduceInput.initialState).state
                }
                print("\tTESTKIT: The test case named:\"\(result.testCase.name)\" has \(result.casePassed ? "PASSED" : "FAILED") \n")
                failedCases = result.casePassed ? failedCases : failedCases + 1
            }
            print("\nTESTKIT: \(testCases.count - failedCases)/\(testCases.count) test cases passed for the file: \"\(sourceFile)\" \n")
        } else {
            fail(with: TestKitFailure(message:"No valid test cases found in the file \"\(sourceFile)\". Unable to run.", file:sourceFile))
        }
    }
    
    func run<Input, Output:TestableOutput>(testClosure:@escaping (Input) throws ->Output?) {
        if fileError { return }
        if casesExist {
            print("\nTESTKIT: Running tests from file: \"\(sourceFile)\"")
            var failedCases = 0
            testCases.forEach{
                testCase in
                print("\n\tTESTKIT: Starting test case named:\"\(testCase.name)\"")
                let result = testCase.inputs.enumerated().reduce(TestState<Input, Output>(testSpec:self, testCase:testCase, testClosure:testClosure)){
                    (reduceInput:(initialState:TestState<Input, Output>, input:(Int, Any))) -> TestState<Input, Output>  in
                    return castInput(input: reduceInput.input).flatMap(outputForInput).flatMap(validatedOutput).flatMap(nilOptionalOutputMightBeSuccess).flatMap(printCaseSuccess).flatMap(checkForExpectedErrorIfNotSuccess).flatMap(castInput).flatMap(expectErrorOrFail).flatMap(validateError).flatMap(printCaseSuccess).flatMap(printCaseFailed).runState(reduceInput.initialState).state
                }
                print("\tTESTKIT: The test case named:\"\(result.testCase.name)\" has \(result.casePassed ? "PASSED" : "FAILED") \n")
                failedCases = result.casePassed ? failedCases : failedCases + 1
            }
            print("\nTESTKIT: \(testCases.count - failedCases)/\(testCases.count) test cases passed for the file: \"\(sourceFile)\" \n")
        } else {
            fail(with: TestKitFailure(message:"No valid test cases found in the file \"\(sourceFile)\". Unable to run.", file:sourceFile))
        }
    }
    
    // MARK: Fileprivate Functions
    
    fileprivate func fail(with failure:TestKitFailure) {
        TestKitSpec.fail(with: failure, failureHandler: failureHandler)
    }
    
    
    // MARK: State Monad Functions
    
    private func castInput<Input, Output>(input:(Int, Any)?) -> (State<TestState<Input, Output>, Input?>) {
        return State {
            var state = $0
            guard let input = input else {
                return (state, nil)
            }
            state.currentInput = input.1
            state.currentInputIndex = input.0
            var uncastedInput:Any? = state.currentInput is NSNull ? nil : state.currentInput
            
            if let inputType = Input.self as? ExpressibleByNilLiteral.Type, uncastedInput == nil {
                uncastedInput = inputType.init(nilLiteral: ())
            }
            
            if let input = uncastedInput as? Input {
                return (state, input)
            } else {
                state.failWith(message:"The input: \(uncastedInput) for test case: \"\(state.testCase.name)\" in file: \"\(state.testSpec.sourceFile)\" did not have the expected type: \(Input.self)")
                return (state, nil)
            }
        }
    }
    
    private func failIfExpectErrorFromNonThrowingClosure<Input, Output>(input:Input?) -> (State<TestState<Input, Output>, Input?>) {
        return State {
            var state = $0
            if state.testCase.expectError {
                state.failWith(message: "The test case \"\(state.testCase.name)\" in file: \"\(state.testSpec.sourceFile)\" was specified as expecting an error for the provided input, but the test closure provided is not a throwing closure and so cannot produce any errors to validate")
                return (state, nil)
            }
            
            return (state, input)
        }
    }
    
    private func expectErrorOrFail<Input, Output>(input:Input?) -> (State<TestState<Input, Output>, Error?>) {
        return State {
            var state = $0
            guard let input = input else {
                return (state, nil)
            }
            
            if let closure = state.testClosureThrowing ?? state.testClosureThrowingOptional {
                do {
                    let output = try closure(input)
                    if state.testCase.expectError {
                        state.failWith(message:"The test case \"\(state.testCase.name)\" in file: \"\(state.testSpec.sourceFile)\" was specified as expecting an error for the provided input, but no error was thrown.", output:output)
                        return (state, nil)
                    } else {
                        state.failWith(message:"You found a bug in TestKit. The test case reached a step that handles error scenarios, but there was already successful output. Please report this issue with the failing test.  Sorry for the inconvenience")
                        return (state, nil)
                    }
                } catch {
                    return (state, error)
                }
            }
            
            state.failWith(message:"You found a bug in TestKit. The internal TestState was invalid because it did not contain the correct test closure.  Sorry for the inconvenience")
            return (state, nil)
        }
    }
    
    private func validateError<Input, Output>(error:Error?) -> (State<TestState<Input, Output>, Bool>) {
        return State{
            var state = $0
            guard let error = error else {
                return (state, false)
            }
            guard state.testCase.expectError == true else {
                state.failWith(message:"Input \(state.currentInputIndex + 1) of the test case \"\(state.testCase.name)\" in file: \"\(state.testSpec.sourceFile)\" resulted in an error being thrown, but the key \"expect-error\" in the TestKit spec was not set to true, so no error was expected.", error:error)
                return (state, false)
            }
            if let expectedOutput = state.testCase.expectedOutput {
                guard let expectedOutput = expectedOutput as? TestKitDictionary else {
                    state.failWith(message:"The test case \"\(state.testCase.name)\" in file: \"\(state.testSpec.sourceFile)\" had invalid expected output. When \"expect-error\" is true, the only valid \"expected-output\" value is a dictionary that the actual thrown error can be validated against. Please ensure that you intended this test case to throw an error, and if so, either omit the \"expected-output\" key to successfully match any error, or set the key to a dictionary value that can be validated against an error that implements the TestableError protocol", error:error)
                    return (state, false)
                }
                
                if let testableError = error as? TestableError {
                    if !testableError.validate(expected: expectedOutput) {
                        state.failWith(message:"The test case \"\(state.testCase.name)\" in file: \"\(state.testSpec.sourceFile)\" produced an expected error that did not pass validation against the expected ouput specified.  To debug, place a breakpoint in the implementation of the validate(expected:) protocol method created for the thrown error.", error:error)
                        return (state, false)
                    }
                    
                    if !expectedOutput.verifyAllKeysUsed() {
                        state.failWith(message: "Some expected output from test case named: \"\(state.testCase.name)\" in file named:\"\(state.testSpec.sourceFile)\" was not verified. Please ensure that your TestableError implementation of the validate(exepected:) function includes using the following untested keys from the TestKitDictionary expected ouput as part of the validation code:\(expectedOutput.unusedKeys)", error:error)
                        return (state, false)
                    }
                    
                    return (state, true)
                    
                } else {
                    state.failWith(message:"The test case \"\(state.testCase.name)\" in file: \"\(state.testSpec.sourceFile)\" resulted in an expected error that could not be validated by TestKit. Please ensure that the error thrown by the test closure you provided when calling TestKitSpec.run() conforms to the TestableError protocol, or, to match against any thrown error, remove the \"expected-output\" key from this case.", error:error)
                    return (state, false)
                }
            } else {
                return (state, true)
            }
        }
    }
    
    private func outputForInput<Input, Output:TestableOutput>(input:Input?) -> (State<TestState<Input, Output>, Output?>) {
        return State {
            var state = $0
            guard let input = input else {
                return  (state, nil)
            }
            
            if let closure = state.testClosure ?? state.testClosureOptional {
                if state.testCase.expectError {
                    state.failWith(message:"The test case \"\(state.testCase.name)\" in file: \"\(state.testSpec.sourceFile)\" indicated that an error is expected, but the test closure provided is non-throwing, so no error is possible")
                    return (state, nil)
                }
                return (state, closure(input))
            } else if let closure = state.testClosureThrowing ?? state.testClosureThrowingOptional {
                return (state, (try? closure(input)) ?? nil)
            }
            
            state.failWith(message:"You found a bug in TestKit. The internal TestState was invalid because it did not contain the correct test closure.  Sorry for the inconvenience")
            return (state, nil)
        }
    }
    
    private func validatedOutput<Input, Output:TestableOutput>(output:Output?) -> (State<TestState<Input, Output>, Output?>) {
        return State {
            var state = $0
            
            if state.testCase.expectError {
                return (state, nil)
            }
            
            guard let output = output else {
                return (state, nil)
            }
            
            guard let expected = state.expectedOutput else {
                state.failWith(message: "The expectedOutput: \(state.testCase.expectedOutput) for test case: \(state.testCase.name) in file: \(state.testSpec.sourceFile) did not have the expected type: \(Output.ExpectedOutputType.self)", output:output)
                return (state, nil)
            }
            
            if !output.validate(expected: expected) {
                state.failWith(message:"The output for the test case named: \"\(state.testCase.name)\" in file named:\"\(state.testSpec.sourceFile)\" did not pass validation against the expected output. To debug, place a breakpoint in your validate(expected:) function implementation for the TestableOutput created in this test.", output:output)
                return (state, nil)
            }
            if let expectedOutput = expected as? TestKitDictionary {
                if !expectedOutput.verifyAllKeysUsed() {
                    state.failWith(message: "Some expected output from test case named: \"\(state.testCase.name)\" in file named:\"\(state.testSpec.sourceFile)\" was not verified. Please ensure that your TestableOutput implementation of the validate(exepected:) function includes using the following untested keys from the TestKitDictionary expected ouput as part of the validation code:\(expectedOutput.unusedKeys)", output:output)
                    return (state, nil)
                }
            }
            return (state, output)
        }
    }
    
    private func nilOptionalOutputMightBeSuccess<Input, Output:TestableOutput>(output:Output?) -> (State<TestState<Input, Output>, Bool>) {
        return State {
            var state = $0
            
            if state.testCase.expectError == true {
                return (state, false)
            }
            
            let expectedNil = state.testCase.expectedOutput == nil
            var success = true
            
            if output == nil && !expectedNil {
                success = false
                state.failWith(message:"The output for the test case named: \"\(state.testCase.name)\" in file named:\"\(state.testSpec.sourceFile)\" did not pass validation because the returned value was nil, but the expected output specified in the test case JSON was non-nil", output:output)
            }
            
            if output != nil && expectedNil {
                success = false
                state.failWith(message:"The output for the test case named: \"\(state.testCase.name)\" in file named:\"\(state.testSpec.sourceFile)\" did not pass validation because the returned value was not nil, but the expected output specified in the test case JSON was nil", output:output)
            }
            
            return (state, success)
        }
    }
    
    private func nonNilOutputIsSuccess<Input, Output:TestableOutput>(output:Output?) -> (State<TestState<Input, Output>, Bool>) {
        return State {
            let success = output != nil ? true : false
            return ($0, success)
        }
    }
    
    private func printCaseSuccess<Input, Output:TestableOutput>(success:Bool) -> (State<TestState<Input, Output>, Bool>) {
        return State {
            let state = $0
            if success {
                print("\t\t input \(state.currentInputIndex + 1)/\(state.testCase.inputs.count) verified")
            }
            return (state, success)
        }
    }
    
    private func printCaseFailed<Input, Output:TestableOutput>(success:Bool) -> (State<TestState<Input, Output>, Bool>) {
        return State {
            let state = $0
            if !success {
                print("\t\t input \(state.currentInputIndex + 1)/\(state.testCase.inputs.count) failed")
            }
            return (state, success)
        }
    }
    
    private func checkForExpectedErrorIfNotSuccess<Input, Output:TestableOutput>(success:Bool) -> (State<TestState<Input, Output>, (Int, Any)?>) {
        return State {
        let state = $0
        if success == true {
            return (state, nil)
        }
        return (state, (state.currentInputIndex, state.currentInput))
        }
    }
    
}

/// Used to receive notifications when XCTFailures occur
private class TestObserver: NSObject, XCTestObservation {
    var failureReported = false
    
    func register() {
        XCTestObservationCenter.shared().addTestObserver(self)
    }
    
    func testCase(_ testCase: XCTestCase, didFailWithDescription description: String, inFile filePath: String?, atLine lineNumber: UInt) {
        failureReported = true
    }
    
    func unregister() {
        XCTestObservationCenter.shared().removeTestObserver(self)
    }
}

/// Parses and holds the data for a single case specified in a TestKit JSON spec
struct TestKitCase {
    let name:String
    let description:String?
    let inputs:[Any]
    let expectError:Bool
    let expectedOutput:Any?
    
    fileprivate init?(from dictionary:[String: Any], file:String, fail:(TestKitFailure)->()) {
        // name
        if let name = dictionary["name"] as? String {
            self.name = name
        } else {
            fail(TestKitFailure(message: "Missing or wrong type of value for test case name (key: \"name\") in file \(file)", file: file))
            return nil
        }
        
        // description
        self.description = dictionary["description"] as? String
        
        // inputs
        if !dictionary.keys.contains("inputs") {
            fail(TestKitFailure(message: "Missing value for test case input (key: \"inputs\") for test case \"\(name)\" in file \(file)", file: file))
            return nil
        } else if dictionary["inputs"] is NSNull {
            self.inputs = [NSNull()]
        } else if let input = dictionary["inputs"] as? [Any] {
            self.inputs = input
        } else if let input = dictionary["inputs"] {
            self.inputs = [input]
        } else {
            return nil
        }
        
        // expectError
        var shouldExpectError = false
        if let expectError = dictionary["expect-error"] as? Bool {
            shouldExpectError = expectError
        }
        self.expectError = shouldExpectError
        
        // expectedOutput
        if !dictionary.keys.contains("expected-output") && shouldExpectError == false {
            fail(TestKitFailure(message: "Missing value for test case expected output (key: \"expected-output\") for test case \"\(name)\" in file \(file)", file: file))
            return nil
        } else {
            let expectedOutput = dictionary["expected-output"] is NSNull ? nil : dictionary["expected-output"]
            self.expectedOutput = expectedOutput is [String:Any] ? TestKitDictionary(dictionary: expectedOutput as! [String:Any]) : expectedOutput
        }
    }
}

/// Captures and retruns information about a test failure when it occurs
struct TestKitFailure {
    let message:String
    let file:String
    let testKitCase:TestKitCase?
    let testKitInput:Any?
    let testOutput:Any?
    let testError:Error?
    
    init(message:String, file:String, testCase:TestKitCase? = nil, input:Any? = nil, output:Any? = nil, error:Error? = nil) {
        self.message = "TESTKIT ERROR: " + message
        self.file = file
        testKitCase = testCase
        testKitInput = input
        testOutput = output
        testError = error
    }
}

/// Basic State Monad implementation, used to recombine and reuse the same stateful functional steps inside different versions of TestKitSpec.run()
private struct State<StateType, ReturnType> {
    let runState:(StateType)->(state: StateType, result: ReturnType)
    func flatMap<NextReturnType>(_ transform:@escaping (ReturnType)->State<StateType, NextReturnType>) -> State<StateType, NextReturnType> {
        return State<StateType, NextReturnType>{
            let result = self.runState($0)
            let nextState = transform(result.1)
            return nextState.runState(result.0)
        }
    }
}

/// Data structure that that State Monad functions inside TestKitSpec use to read, write, and pass state along the chain
private struct TestState<Input, Output:TestableOutput> {
    let testClosure:((Input)->Output)?
    let testClosureOptional:((Input)->Output?)?
    let testClosureThrowing:((Input) throws -> Output)?
    let testClosureThrowingOptional:((Input) throws ->Output?)?
    let testSpec:TestKitSpec
    let testCase:TestKitCase
    var currentInput:Any? = nil
    var currentInputIndex:Int = 0
    var casePassed = true
    
    
    var expectedOutput:Output.ExpectedOutputType? {
        if let expectedOutput = testCase.expectedOutput as? Output.ExpectedOutputType {
            return expectedOutput
        } else {
            return nil
        }
    }
    
    init(testSpec:TestKitSpec, testCase:TestKitCase, testClosure:@escaping (Input)->Output) {
        self.testSpec = testSpec
        self.testClosure = testClosure
        self.testClosureThrowing = nil
        self.testClosureThrowingOptional = nil
        self.testClosureOptional = nil
        self.testCase = testCase
    }
    
    init(testSpec:TestKitSpec, testCase:TestKitCase, testClosure:@escaping (Input)->Output?) {
        self.testSpec = testSpec
        self.testClosure = nil
        self.testClosureThrowing = nil
        self.testClosureThrowingOptional = nil
        self.testClosureOptional = testClosure
        self.testCase = testCase
    }
    
    init(testSpec:TestKitSpec, testCase:TestKitCase, testClosure:@escaping (Input) throws -> Output) {
        self.testSpec = testSpec
        self.testClosureThrowing = testClosure
        self.testClosure = nil
        self.testClosureThrowingOptional = nil
        self.testClosureOptional = nil
        self.testCase = testCase
    }
    
    init(testSpec:TestKitSpec, testCase:TestKitCase, testClosure:@escaping (Input) throws -> Output?) {
        self.testSpec = testSpec
        self.testClosure = nil
        self.testClosureThrowing = nil
        self.testClosureOptional = nil
        self.testClosureThrowingOptional = testClosure
        self.testCase = testCase
    }
    
    mutating func failWith(message:String, output:Any? = nil, error:Error? = nil) {
        casePassed = false
        testSpec.fail(with: TestKitFailure(message:message + "\n", file:testSpec.sourceFile, testCase:testCase, input:currentInput, output:output, error:error))
    }
}
