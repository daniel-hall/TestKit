//
//  TestKit.swift
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


@objc internal class TestKit: NSObject {
    internal static var testLog = ""
    internal static var currentFailures = [String]()
    internal static var currentCompletionHandler:(()->())?
    internal static var setup:()->() = {}
    internal static var teardown:()->() = {}
    internal static var currentStep: Step?
    internal static var currentStepType: String = ""
    internal static var scenarioCount = 0
    internal static var currentScenario: Scenario?
    internal static var remainingScenarios = [Scenario]()
    internal static var remainingGivens = [Step]()
    internal static var remainingWhens = [Step]()
    internal static var remainingThens = [Step]()
    internal static var remainingSteps:[Step] { return remainingGivens + remainingWhens + remainingThens }
    internal static var givenHandlers = [Handler]()
    internal static var whenHandlers = [Handler]()
    internal static var thenHandlers = [Handler]()
    internal static var notificationHandlers = [String: ([String: Any])->()]()
    
    private static var pingSuccess = false
    private static var startedUp = false
    
    /// Convenience method uses Darwin notifications and Pasteboard to send messages and payloads between UITestRunner and the running app
    internal static func postNotification(name:String, info:[String:Any]?) {
        if let info = info {
            let serializedData = NSKeyedArchiver.archivedData(withRootObject: info)
            UIPasteboard.general.setItems(UIPasteboard.general.items.filter { $0["testkit.notificationData"] == nil }, options: [:])
            UIPasteboard.general.addItems([["testkit.notificationData": serializedData]])
        }
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFNotificationName(rawValue: name as CFString), nil, nil, true)
    }
    
    /// Method for reconstituting a dictionary that was serialized to the Pasteboard
    internal static var notificationInfo:[String:Any]? {
        if let data = UIPasteboard.general.data(forPasteboardType: "testkit.notificationData", inItemSet: UIPasteboard.general.itemSet(withPasteboardTypes: ["testkit.notificationData"]))?.first as? Data, let notificationData = NSKeyedUnarchiver.unarchiveObject(with: data) as? [String:Any] {
            return notificationData
        }
        return nil
    }
    
    /// Method for finding a step handler that is a regex match for the provided step
    internal static func findMatch(forStep:Step, inArray:[Handler]) throws -> ((StepCallback)->())? {
        let matches:[(StepInput, Handler)] = inArray.flatMap {
            handler in
            let matches = handler.regex.matches(in: forStep.description, options: [], range: NSRange(location: 0, length: forStep.description.count))
            if let match = matches.first {
                let values:[String] = Array(0..<match.numberOfRanges).map {
                    let range = match.range(at: $0)
                    return (forStep.description as NSString).substring(with: range)
                }
                let filteredValues = values.count < 2 ? [] : values.dropFirst()
                let matchedValues: [String:String] = zip(handler.tokens, filteredValues).reduce([:]) { var result = $0; result[$1.0] = $1.1; return result }
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
    
    /// TestKit method for running all the scenarios in a feature file
    internal static func runFeature(url:URL, setup:@escaping ()->(), teardown:@escaping ()->(), excludingTags:[String]? = nil, limitingToTags:[String]? = nil, completion:@escaping ()->()) {
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
            remainingScenarios = excludingTags == nil ? feature.scenarios : feature.scenarios.filter{ Set($0.tags).isDisjoint(with: Set(excludingTags!)) }
            remainingScenarios = limitingToTags == nil ? remainingScenarios : remainingScenarios.filter{ !Set($0.tags).intersection(Set(limitingToTags!)).isEmpty
            }
            testLog += "\n\n------------------\n TestKit Results: \n------------------"
            testLog += "\n\tFeature: \(feature.name)\n"
            scenarioCount = remainingScenarios.count
            nextScenario()
        } catch {
            currentFailures.append("TestKit feature failed with error: \(error)")
            currentCompletionHandler?()
        }
    }
    
    /// Internal method for printing to the console with some extra formatting
    internal static func printFormatted(_ string: String, numberOfDashes: Int) {
        let topLines = "\n\n" + Array(repeating: "-", count: numberOfDashes).joined() + "\n"
        let bottomLines = "\n" + Array(repeating: "-", count: numberOfDashes).joined() + "\n\n"
        print(topLines + string + bottomLines)
    }
    
    /// Prints the provided step to the console, and saves it to the test log for the final report
    internal static func logStep(_ step:String) {
        guard currentCompletionHandler != nil else { return }
        testLog += "\t\t\t\t\(step)\n"
        printFormatted(" TESTKIT: " + step, numberOfDashes: step.count + 12)
    }
    
    /// Prints the provided scenario to the console, and saves it to the test log for the final report
    internal static func logScenario(_ scenario:String) {
        guard currentCompletionHandler != nil else { return }
        testLog += "\n\n\n\t\tScenario: \(scenario)\n"
        printFormatted(" TESTKIT: Starting Scenario \"" + scenario, numberOfDashes: scenario.count + 32)
    }
    
    /// Runs the next scenario in the feature
    internal static func nextScenario() {
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
    
    /// Runs the next step in the scenario
    internal static func nextStep() {
        // Abort if execution was terminated and the completion handler is nil
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
                // Try to find a matching step handler here, in the UI Test target
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
                    // If this is the UI Test bundle / UI Test Runner and no matching step handler was found, send a message to the Unit Test bundle running in the app itself to see if there is a matching step handler there
                    if ProcessInfo.processInfo.processName == "XCTRunner" || ProcessInfo.processInfo.processName.hasSuffix("-Runner") {
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
                        // This handles the case where TestKit is running entirely within the Unit Test bundle (spec testing) and no matching step handler was found, in which case no matching handler is an immediate failure
                        logStep("❌ " + currentStepType + " " + currentStep!.description)
                        currentFailures.append("No matching step handler found for: \(currentStep!.description)")
                        self.nextScenario()
                    }
                }
            } catch {
                logStep("❌ " + currentStepType + " " + currentStep!.description)
                currentFailures.append(String(describing: error))
                nextScenario()
            }
        }
    }
    
    /// Initializes TestKit and calls +registerStepHandlers and +registerNotificationHandlers on a TestKitFeature subclasses. Also sets up the appropriate Darwin notification callbacks depending on whether this instance of TestKit is running in the UI Test Bundle, or the Unit Test Bundle
    @objc internal static func startup() {
        // Temporary helper function
        func registerAsNotificationObserver(notificationName:String, callback:@escaping CFNotificationCallback) {
            CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), nil, callback, notificationName as CFString, nil, .deliverImmediately)
        }
        
        if !startedUp {
            startedUp = true
            
            // Find all developer-created features and register their steps
            var count = UInt32(0)
            let classList = objc_copyClassList(&count)!
            Array(0..<Int(count)).forEach {
                if let theSuperclass = class_getSuperclass(classList[$0]), theSuperclass == TestKitFeature.self {
                    (classList[$0] as! TestKitFeature.Type).registerStepHandlers()
                    (classList[$0] as! TestKitFeature.Type).registerNotificationHandlers()
                }
            }
            
            // Set up steps only for the instance of TestKit running in the UI Test Runner process
            if ProcessInfo.processInfo.processName == "XCTRunner" || ProcessInfo.processInfo.processName.hasSuffix("-Runner") {
                let stepSuccessCallback: CFNotificationCallback = {
                    _,_,_,_,_  in
                    TestKit.logStep("✅ " + TestKit.currentStepType + " " + TestKit.currentStep!.description)
                    TestKit.nextStep()
                }
                
                let stepFailureCallback: CFNotificationCallback = {
                    _,_,_,_,_  in
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
        }
    }
}

