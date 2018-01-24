//
//  XCTestExtensions.swift
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
import XCTest


// Use this extension method instead of XCUIApplication.launch() when you need steps to be executed in the app itself, not just the UI Test runner
public extension XCUIApplication {
    public func launchWithTestKitEnabled() {
        guard let buildPath = ProcessInfo.processInfo.environment["__XCODE_BUILT_PRODUCTS_DIR_PATHS"],
            let appName = (try? FileManager.default.contentsOfDirectory(atPath: buildPath))?.first(where: { $0.hasSuffix(".app") && !$0.contains("-Runner") && !$0.contains("XCTRunner") }),
            let appPath = Optional(buildPath + "/" + appName),
            let testBundleName = (try? FileManager.default.contentsOfDirectory(atPath: appPath + "/PlugIns"))?.first(where: { $0.hasSuffix("xctest") }) else {
                fatalError()
        }
        let testBundlePath = appPath + "/PlugIns/" + testBundleName
        self.launchEnvironment["TestKitUnitTestBundlePath"] = testBundlePath
        self.launch()
    }
}


public extension XCTestCase {
    
    /// A method that will run before every scenario in a feature file
    public func setUpScenario() {
        // unimplemented, override in XCTestCase subclass
    }
    
    /// A method that will run after every scenario in a feature file
    public func tearDownScenario() {
        // unimplemented, override in XCTestCase subclass
    }
    
    /// Parses and runs the Gherkin feature file at the specified URL.  Can optionally be narrowed to exclude certain tags in the feature file, or limit execution to only certain tags
    public func testFeature(name:String, excludingTags: [String]? = nil, limitingToTags:[String]? = nil, timeout:TimeInterval = 180, _ file:StaticString = #file, _ line:UInt = #line) {

        // A class to detect non-TestKit assertions and end the test run
        class TestObserver: NSObject, XCTestObservation {
            private var handler: (String)->()
            
            init(handler:@escaping (String)->()) {
                self.handler = handler
            }
            func testCase(_ testCase: XCTestCase, didFailWithDescription description: String, inFile filePath: String?, atLine lineNumber: Int) {
                handler(description)
            }
        }
        
        // Start TestKit in the UITest target if it hasn't been already
        TestKit.startup()
        
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
        
        XCTestObservationCenter.shared.addTestObserver(observer)
        
        guard let url = Bundle(for: type(of:self).self).url(forResource: name, withExtension: ".feature") else {
            XCTFail("Couldn't find \"\(name).feature\" in test bundle", file: file, line: line)
            return
        }
        
        TestKit.runFeature(url: url, setup: { [weak self] in self?.setUpScenario() }, teardown: { [weak self] in self?.tearDownScenario() }, excludingTags: excludingTags, limitingToTags: limitingToTags) {
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
        XCTestObservationCenter.shared.removeTestObserver(observer)
        if ProcessInfo.processInfo.processName == "XCTRunner" || ProcessInfo.processInfo.processName.hasSuffix("-Runner")  {
            XCUIApplication().terminate()
        }
        print(TestKit.testLog)
        TestKit.currentFailures.forEach {
            XCTFail($0, file:file, line:line)
        }
    }
}
