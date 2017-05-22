//
//  TestKit.swift
//  TestKit
//
// Copyright (c) 2017 Daniel Hall
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
import XCTest


public extension XCTestCase {
    
    public func setUpScenario() {
        // unimplemented, override in XCTestCase subclass
    }
    
    public func tearDownScenario() {
        // unimplemented, override in XCTestCase subclass
    }
    
    public func testFeature(name:String, limitToTags tags:[String]? = nil, timeout:TimeInterval = 180, _ file:StaticString = #file, _ line:UInt = #line) {
        
        // A class to detect non-TestKit assertions and end the test run
        class TestObserver: NSObject, XCTestObservation {
            private var handler: (String)->()
            
            init(handler:@escaping (String)->()) {
                self.handler = handler
            }
            func testCase(_ testCase: XCTestCase, didFailWithDescription description: String, inFile filePath: String?, atLine lineNumber: UInt) {
                handler(description)
            }
        }
        
        continueAfterFailure = true
        var caughtFailure = false
        let wait = expectation(description: "All Scenarios for the TestKit Feature have completed")
        
        let observer = TestObserver {
            caughtFailure = true
            TestKit.logStep("❌ " + TestKit.currentStepType + " " + TestKit.currentStep!.description)
            print("TESTKIT ERROR. Aborting feature test due to unexpected assertion: \($0)")
            TestKit.currentCompletionHandler = nil
            TestKit.currentFailures.append($0)
            wait.fulfill()
        }
        
        XCTestObservationCenter.shared().addTestObserver(observer)
        
        guard let url = Bundle(for: type(of:self).self).url(forResource: name, withExtension: ".feature") else {
            XCTFail("Couldn't find \"\(name).feature\" in test bundle", file: file, line: line)
            return
        }
        
        TestKit.runFeature(url: url, setup: { [weak self] in self?.setUpScenario() }, teardown: { [weak self] in self?.tearDownScenario() }, limitToTags: tags) {
            caughtFailure = true
            TestKit.currentCompletionHandler = nil
            wait.fulfill()
        }
        
        waitForExpectations(timeout: timeout, handler: nil)
        
        if !caughtFailure {
            TestKit.logStep("❌ " + TestKit.currentStepType + " " + TestKit.currentStep!.description)
            print("TESTKIT ERROR. Aborting feature test due to unexpected unhandled exception")
            TestKit.currentCompletionHandler = nil
            TestKit.currentFailures.append("Encountered unhandled exception while running the most recent test step")
        }
        XCTestObservationCenter.shared().removeTestObserver(observer)
        if ProcessInfo.processInfo.processName == "XCTRunner" {
            XCUIApplication().terminate()
        }
        print(TestKit.testLog)
        TestKit.currentFailures.forEach {
            XCTFail($0, file:file, line:line)
        }
    }
}

// Use this extension method instead of XCUIApplication.launch() when you need steps to be executed in the app itself, not just the UI Test runner
public extension XCUIApplication {
    public func launchWithTestKitEnabled() {
        self.launchArguments += ["RunTestKit"]
        self.launch()
    }
}

// Subclass and override registerStepHandlers() to add hooks for different given, when, and then statements
@objc open class TestKitFeature: NSObject {
    open class func registerStepHandlers() {
        assertionFailure("You must override the registerStepHandlers class method")
    }
}

@objc public class TestKit: NSObject {
    private static var givenHandlers = [Handler]()
    private static var whenHandlers = [Handler]()
    private static var thenHandlers = [Handler]()
    
    fileprivate static var testLog = ""
    fileprivate static var currentFailures = [String]()
    fileprivate static var currentCompletionHandler:(()->())?
    fileprivate static var setup:()->() = {}
    fileprivate static var teardown:()->() = {}
    fileprivate static var currentStep: Step?
    fileprivate static var currentStepType: String = ""
    private static var pingSuccess = false
    private static var scenarioCount = 0
    private static var currentScenario: Scenario?
    fileprivate static var remainingScenarios = [Scenario]()
    private static var remainingGivens = [Step]()
    private static var remainingWhens = [Step]()
    private static var remainingThens = [Step]()
    fileprivate static var remainingSteps:[Step] { return remainingGivens + remainingWhens + remainingThens }
    
    // A simple struct that contains a Regex expression to match against the current step, and a closure to run in the event of a match
    fileprivate struct Handler {
        let regex:NSRegularExpression
        let action:(StepInput, StepCallback)->()
        let tokens:[String]
        let timeout:TimeInterval?
        init(_ expression:String, timeout:TimeInterval? = nil, action: @escaping (StepInput, StepCallback)->()) {
            var pattern = expression
            let simpleRegex = try! NSRegularExpression(pattern: "(?<!\\\\)(<\\w+>)", options: [])
            let simpleMatches = simpleRegex.matches(in: pattern, options: [], range: NSRange(location: 0, length: pattern.characters.count))
            let simpleTokens:[String] = simpleMatches.reduce([]) {
                (result, match) in
                return result + Array(0..<(match.numberOfRanges > 0 ? match.numberOfRanges - 1 : 0)).map {
                    let range = match.rangeAt($0)
                    return (pattern as NSString).substring(with: range)
                }
            }
            simpleTokens.forEach{ pattern = pattern.replacingOccurrences(of: $0, with: "(.+)")}
            
            let customRegex = try! NSRegularExpression(pattern: "(?<!\\\\)(<\\w+\\(.+\\)>)", options: [])
            let customMatches = customRegex.matches(in: pattern, options: [], range: NSRange(location: 0, length: pattern.characters.count))
            var customTokens:[String] = customMatches.reduce([]) {
                (result, match) in
                return result + Array(0..<(match.numberOfRanges > 0 ? match.numberOfRanges - 1 : 0)).map {
                    let range = match.rangeAt($0)
                    return (pattern as NSString).substring(with: range)
                }
            }
            customTokens.forEach { pattern = pattern.replacingOccurrences(of: $0, with: $0.substring(from: $0.range(of: "(")!.lowerBound).trimmingCharacters(in: CharacterSet(charactersIn: "<>"))) }
            customTokens = customTokens.map {
                return $0.substring(to: $0.range(of: "(")!.lowerBound)
            }
            tokens = (simpleTokens + customTokens).map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "<>")) }
            regex = try! NSRegularExpression(pattern: pattern)
            self.timeout = timeout
            self.action = action
        }
    }
    
    // A wrapper around the dictionary of matched token-value pairs.  It force unwraps the value at the given key since it is always assumed to exist in the event of a regex match
    public struct MatchedValues {
        let dictionary: [String: String]
        fileprivate init(_ dictionary:[String: String]) {
            self.dictionary = dictionary
        }
        public subscript(key: String) -> String {
            guard let value = dictionary[key] else {
                fatalError("The Matched Values for the step '\(TestKit.currentStep!.description)' do not contain a value for the key \(key)")
            }
            return value
        }
    }
    
    public struct StepInput {
        public let matchedValues:MatchedValues
        public let docString:String?
        public let dataTable:[[String: String]]?
    }
    
    public class StepCallback {
        fileprivate var completed = false
        private let success:()->()
        private let failure:(String)->()
        public func succeed() {
            if (!completed) {
                completed = true
                success()
            }
        }
        public func fail(reason:String) {
            if (!completed) {
                completed = true
                failure(reason)
            }
        }
        fileprivate init(success:@escaping ()->(), failure:@escaping (String)->()) {
            self.success = success
            self.failure = failure
        }
    }
    
    public static func given(_ expression:String, action:@escaping (StepInput) throws ->()) {
        givenHandlers.append(Handler(expression){
            do {
                try action($0.0)
                $0.1.succeed()
            } catch {
                $0.1.fail(reason: String(describing: error))
            }
        })
    }
    
    public static func given(_ expression:String, timeout: TimeInterval, action:@escaping (StepInput, StepCallback)->()) {
        givenHandlers.append(Handler(expression, timeout:timeout, action: action))
    }
    
    public static func when(_ expression:String, action:@escaping (StepInput) throws ->()) {
        whenHandlers.append(Handler(expression){
            do {
                try action($0.0)
                $0.1.succeed()
            } catch {
                $0.1.fail(reason: String(describing: error))
            }
        })
    }
    
    public static func when(_ expression:String, timeout: TimeInterval, action:@escaping (StepInput, StepCallback)->()) {
        whenHandlers.append(Handler(expression, timeout:timeout, action: action))
    }
    
    public static func then(_ expression:String, action:@escaping (StepInput) throws ->()) {
        thenHandlers.append(Handler(expression){
            do {
                try action($0.0)
                $0.1.succeed()
            } catch {
                $0.1.fail(reason: String(describing: error))
            }
        })
    }
    
    public static func then(_ expression:String, timeout: TimeInterval, action:@escaping (StepInput, StepCallback)->()) {
        thenHandlers.append(Handler(expression, timeout:timeout, action: action))
    }
    
    private static func postNotification(name:String, info:[String:Any]?) {
        if let info = info {
            let serializedData = NSKeyedArchiver.archivedData(withRootObject: info)
            UIPasteboard.general.setItems(UIPasteboard.general.items.filter { $0["testkit.notificationData"] == nil }, options: [:])
            UIPasteboard.general.addItems([["testkit.notificationData": serializedData]])
        }
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFNotificationName(rawValue: name as CFString), nil, nil, true)
    }
    
    
    private static var notificationInfo:[String:Any]? {
        if let data = UIPasteboard.general.data(forPasteboardType: "testkit.notificationData", inItemSet: UIPasteboard.general.itemSet(withPasteboardTypes: ["testkit.notificationData"]))?.first as? Data, let notificationData = NSKeyedUnarchiver.unarchiveObject(with: data) as? [String:Any] {
            return notificationData
        }
        return nil
    }
    
    private static func findMatch(forStep:Step, inArray:[Handler]) throws -> ((StepCallback)->())? {
        let matches:[(StepInput, Handler)] = inArray.flatMap {
            handler in
            let matches = handler.regex.matches(in: forStep.description, options: [], range: NSRange(location: 0, length: forStep.description.characters.count))
            if let match = matches.first {
                let values:[String] = Array(0..<match.numberOfRanges).map {
                    let range = match.rangeAt($0)
                    return (forStep.description as NSString).substring(with: range)
                }
                let filteredValues = values.count < 2 ? [] : values.dropFirst()
                let matchedValues: [String:String] = zip(handler.tokens, filteredValues).reduce([:]) { var result = $0.0; result[$0.1.0] = $0.1.1; return result }
                return (StepInput(matchedValues: MatchedValues(matchedValues), docString: forStep.docString, dataTable: forStep.dataTable), handler)
            }
            return nil
        }
        if matches.count > 1 {
            throw NSError(domain:"TestKit", code:0, userInfo:[NSLocalizedDescriptionKey:"TestKit Error: Found more than one matching handler for the step: \"\(currentStepType) \(currentStep!.description)\""])
        }
        return matches.first == nil ? nil : {
            [match = matches.first!] result in
            if let timeout = match.1.timeout {
                DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
                    if !result.completed {
                        result.fail(reason: "The step timed out")
                    }
                }
            }
            match.1.action(match.0, result)
        }
    }
    
    public static func runFeature(url:URL, setup:@escaping ()->(), teardown:@escaping ()->(), limitToTags:[String]? = nil, completion:@escaping ()->()) {
        testLog = ""
        scenarioCount = 0
        currentFailures = []
        currentCompletionHandler = completion
        self.setup = setup
        self.teardown = teardown
        currentScenario = nil
        currentStep = nil
        currentStepType = ""
        remainingScenarios = []
        remainingGivens = []
        remainingWhens = []
        remainingThens = []
        
        
        guard let data = try? Data(contentsOf: url) else {
            currentFailures.append("Could not load TestKit feature from URL: \(url)")
            currentCompletionHandler?()
            return
        }
        guard let string = String(data: data, encoding: .utf8) else {
            currentFailures.append("Could not decode a UTF8 string from data at URL: \(url)")
            currentCompletionHandler?()
            return
        }
        do {
            let feature = try parse(gherkin: string)
            remainingScenarios = limitToTags == nil ? feature.scenarios : feature.scenarios.filter{ !Set($0.tags).intersection(Set(limitToTags!)).isEmpty }
            testLog += "\n\n------------------\n TestKit Results: \n------------------"
            testLog += "\n\tFeature: \(feature.name)\n"
            scenarioCount = remainingScenarios.count
            nextScenario()
        } catch {
            currentFailures.append("TestKit feature failed with error: \(error)")
            currentCompletionHandler?()
        }
    }
    
    fileprivate static func logStep(_ step:String) {
        guard currentCompletionHandler != nil else { return }
        testLog += "\t\t\t\t\(step)\n"
        let topLines = "\n\n" + Array(repeating: "-", count: step.characters.count + 12).joined() + "\n"
        let bottomLines = "\n" + Array(repeating: "-", count: step.characters.count + 12).joined() + "\n\n"
        print(topLines + " TESTKIT: " + step + bottomLines)
    }
    
    private static func logScenario(_ scenario:String) {
        guard currentCompletionHandler != nil else { return }
        testLog += "\n\n\n\t\tScenario: \(scenario)\n"
        let topLines = "\n\n" + Array(repeating: "-", count: scenario.characters.count + 32).joined() + "\n"
        let bottomLines = "\n" + Array(repeating: "-", count: scenario.characters.count + 32).joined() + "\n\n"
        print(topLines + " TESTKIT: Starting Scenario \"" + scenario + "\"" + bottomLines)
    }
    
    
    fileprivate static func nextScenario() {
        guard currentCompletionHandler != nil else { return }
        if scenarioCount != remainingScenarios.count {
            teardown()
        }
        if remainingScenarios.count > 0  {
            let next = remainingScenarios.removeFirst()
            currentScenario = next
            remainingGivens = next.givens
            remainingWhens = next.whens
            remainingThens = next.thens
            logScenario(currentScenario!.name)
            setup()
            nextStep()
        } else {
            TestKit.testLog += "\n\n-------------------------\n \(scenarioCount - currentFailures.count) / \(scenarioCount) Scenarios Passed.\n-------------------------\n\n"
            currentCompletionHandler?()
        }
    }
    
    private static func nextStep() {
        guard currentCompletionHandler != nil else { return }
        if remainingSteps.count == 0 {
            nextScenario()
        } else {
            var handlers = [Handler]()
            if remainingGivens.count > 0 {
                currentStep = remainingGivens.removeFirst()
                handlers = givenHandlers
                currentStepType = "Given"
            } else if remainingWhens.count > 0 {
                currentStep = remainingWhens.removeFirst()
                handlers = whenHandlers
                currentStepType = "When"
            } else if remainingThens.count > 0 {
                currentStep = remainingThens.removeFirst()
                handlers = thenHandlers
                currentStepType = "Then"
            }
            do {
                if let handler = try findMatch(forStep: currentStep!, inArray: handlers) {
                    let result = StepCallback(success: {
                        logStep("✅ " + currentStepType + " " + currentStep!.description)
                        self.nextStep()
                    }, failure: {
                        logStep("❌ " + currentStepType + " " + currentStep!.description)
                        currentFailures.append($0)
                        self.nextScenario()
                    })
                    handler(result)
                } else {
                    if ProcessInfo.processInfo.processName == "XCTRunner" {
                        // Don't wait indefinitely for a step response from the main application if we haven't even verified that it's set up, running TestKit, and receiving notifications properly
                        TestKit.pingSuccess = false
                        postNotification(name: "TestKit.Notification.Ping", info: nil)
                        
                        // We should get a notification back from TestKit in the app process in the same frame if it has been properly initialized
                        DispatchQueue.main.async {
                            if TestKit.pingSuccess == false {
                                TestKit.currentFailures.append("Couldn't establish connection to TestKit inside the main application.  Please ensure that your main application's AppDelegate is configured to load and initialize the unit test bundle as described in TestKit's documentation")
                                TestKit.currentCompletionHandler?()
                            }
                        }
                        
                        let notificationData: [String: Any] = ["description" : currentStep?.description as Any, "docString" : currentStep?.docString as Any, "dataTable" : currentStep?.dataTable as Any]
                        postNotification(name: "TestKit.Notification.RunStep", info: notificationData)
                    } else {
                        logStep("❌ " + currentStepType + " " + currentStep!.description)
                        currentFailures.append("No matching step handler found for: \(currentStep!.description)")
                        self.nextScenario()
                    }
                }
                
            } catch {
                TestKit.logStep("❌ " + TestKit.currentStepType + " " + TestKit.currentStep!.description)
                currentFailures.append(String(describing: error))
                nextScenario()
            }
        }
    }
    
    private static var initializeOnce: ()->() = {
        // Temporary helper function
        func registerAsNotificationObserver(notificationName:String, callback:@escaping CFNotificationCallback) {
            CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), nil, callback, notificationName as CFString, nil, .deliverImmediately)
        }
        // Register built-in features
        UnitTestFeature.registerStepHandlers()
        
        // Find all developer-created features and register their steps
        var count = UInt32(0)
        let classList = objc_copyClassList(&count)!
        Array(0..<Int(count)).forEach {
            if let theClass = classList[$0], let theSuperclass = class_getSuperclass(theClass), theSuperclass == TestKitFeature.self {
                (theClass as! TestKitFeature.Type).registerStepHandlers()
            }
        }
        
        // Set up steps only for the instance of TestKit running in the UI Test Runner process
        if ProcessInfo.processInfo.processName == "XCTRunner" {
            let stepSuccessCallback: CFNotificationCallback = {
                _ in
                TestKit.logStep("✅ " + TestKit.currentStepType + " " + TestKit.currentStep!.description)
                TestKit.nextStep()
            }
            
            let stepFailureCallback: CFNotificationCallback = {
                _ in
                TestKit.logStep("❌ " + TestKit.currentStepType + " " + TestKit.currentStep!.description)
                if let info = TestKit.notificationInfo, let reason = info["reason"] as? String {
                    TestKit.currentFailures.append(reason)
                } else {
                    TestKit.currentFailures.append("Couldn't handle step \(TestKit.currentStep!.description)")
                }
                TestKit.nextScenario()
            }
            
            let pongCallback: CFNotificationCallback = { (
                center: CFNotificationCenter?,
                observer: UnsafeMutableRawPointer?,
                name: CFNotificationName?,
                object: UnsafeRawPointer?,
                userInfo: CFDictionary?
                ) in
                TestKit.pingSuccess = true
            }
            
            registerAsNotificationObserver(notificationName: "TestKit.Notification.StepSuccess", callback: stepSuccessCallback)
            registerAsNotificationObserver(notificationName: "TestKit.Notification.StepFailure", callback: stepFailureCallback)
            registerAsNotificationObserver(notificationName: "TestKit.Notification.Pong", callback: pongCallback)
        }
            // These steps only happen in the main app, not in the XCUITest runner
        else {
            let pingCallback: CFNotificationCallback = {
                (center: CFNotificationCenter?, observer: UnsafeMutableRawPointer?, name: CFNotificationName?, object: UnsafeRawPointer?, userInfo: CFDictionary?) in
                CFNotificationCenterPostNotification(center, CFNotificationName(rawValue: "TestKit.Notification.Pong" as CFString), nil, nil, true)
            }
            
            let stepCallback: CFNotificationCallback = { (
                center: CFNotificationCenter?,
                observer: UnsafeMutableRawPointer?,
                name: CFNotificationName?,
                object: UnsafeRawPointer?,
                userInfo: CFDictionary?
                ) in
                if let info = TestKit.notificationInfo {
                    let step = Step(description: info["description"] as! String, docString: info["docString"] as? String, dataTable: info["dataTable"] as? [[String : String]])
                    if let handler = (try? TestKit.findMatch(forStep: step, inArray: TestKit.givenHandlers + TestKit.whenHandlers + TestKit.thenHandlers)) ?? nil {
                        let result = StepCallback(success: {
                            TestKit.postNotification(name: "TestKit.Notification.StepSuccess", info: nil)
                        }, failure: {
                            let notificationData: [String: Any] = ["reason": $0]
                            TestKit.postNotification(name: "TestKit.Notification.StepFailure", info: notificationData)
                        })
                        handler(result)
                    } else {
                        let notificationData: [String: Any] = ["reason": "No matching step handler found for: \(step.description)"]
                        TestKit.postNotification(name: "TestKit.Notification.StepFailure", info: notificationData)
                    }
                }
                else {
                    let notificationData: [String: Any] = ["reason": "Couldn't find TestKit notification data on pasteboard"]
                    TestKit.postNotification(name: "TestKit.Notification.StepFailure", info: notificationData)
                }
            }
            registerAsNotificationObserver(notificationName: "TestKit.Notification.RunStep", callback: stepCallback)
            registerAsNotificationObserver(notificationName: "TestKit.Notification.Ping", callback: pingCallback)
        }
        return {}
    }()
    
    override init() {
        TestKit.initializeOnce()
    }
}

// MARK: - Helper Functions -

public extension TestKit {
    public static func views<T: UIView>(ofType:T.Type, accessibilityIdentifier: String? = nil, inView:UIView = (UIApplication.shared.delegate?.window ?? nil) ?? UIView()) -> [T] {
        let viewArray = Array(inView.subviews.map { views(ofType: ofType, accessibilityIdentifier: accessibilityIdentifier, inView: $0) }.joined())
        guard let inViewTyped = inView as? T, accessibilityIdentifier == nil || inView.accessibilityIdentifier == accessibilityIdentifier else {
            return viewArray
        }
        return viewArray + [inViewTyped]
    }
    
    public static func views<T: UIView>(ofExactType:T.Type, accessibilityIdentifier: String? = nil, inView:UIView = (UIApplication.shared.delegate?.window ?? nil) ?? UIView()) -> [T] {
        let viewArray = Array(inView.subviews.map { views(ofExactType: ofExactType, accessibilityIdentifier: accessibilityIdentifier, inView: $0) }.joined())
        guard let inViewTyped = inView as? T, accessibilityIdentifier == nil || inView.accessibilityIdentifier == accessibilityIdentifier, type(of:inView) == ofExactType else {
            return viewArray
        }
        return viewArray + [inViewTyped]
    }
    
    public static func views(withAccessibilityIdentifier:String? = nil, inView: UIView = (UIApplication.shared.delegate?.window ?? nil) ?? UIView()) -> [UIView] {
        let viewArray = Array(inView.subviews.map { views(withAccessibilityIdentifier: withAccessibilityIdentifier, inView: $0) }.joined())
        guard withAccessibilityIdentifier == nil || inView.accessibilityIdentifier == withAccessibilityIdentifier else {
            return viewArray
        }
        return viewArray + [inView]
    }
}

// MARK: - Unit Test Feature -

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

public class UnitTestFeature {
    public static var input: TestKitUnitTestData?
    public static var output: TestKitUnitTestOutput?
    public static var error: TestKitUnitTestOutput?
    
    class func registerStepHandlers() {
        TestKit.given("the unit test input is <input>") {
            input = TestKitUnitTestData(value: $0.matchedValues["input"], docString: $0.docString, dataTable: $0.dataTable)
            output = nil
            error = nil
        }
        
        TestKit.then("the unit test output is <output>") {
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
        
        TestKit.then("an error is thrown") {
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

