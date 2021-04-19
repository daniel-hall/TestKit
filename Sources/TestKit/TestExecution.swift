//
//  TestExecution.swift
//  TestKit
//
//  Created by Hall, Daniel on 7/12/19.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

import XCTest


public class TestExecution: NSObject, XCTestObservation {
    
    internal static var current: TestExecution?
    
    private let feature: Gherkin.Feature
    private var remainingRules = [Gherkin.Feature.Rule]()
    private var currentRule: Gherkin.Feature.Rule?
    
    private var remainingExamples = [Gherkin.Feature.Example]()
    internal var currentExample: Gherkin.Feature.Example?
    
    private var remainingSteps = [Gherkin.Feature.Step]()
    private var currentStep: Gherkin.Feature.Step?
    
    private let stepDefinitions: [StepDefinition]
    private var hasFailed = false
    
    private let expectation = XCTestExpectation()
    private var continueAfterFailure = false
    
    private let tagExpression: TagExpression?
    
    private var ruleExpectation: XCTestExpectation?
    private var exampleExpectation: XCTestExpectation?

    private var beforeEachExample: ((Gherkin.Feature.Example) -> Void)?
    
    
    public init(feature: Gherkin.Feature, stepDefinitions: [StepDefinition], tagExpression: TagExpression? = nil) {
        self.feature = feature
        self.stepDefinitions = stepDefinitions
        self.tagExpression = tagExpression
    }
    
    public func testCase(_ testCase: XCTestCase, didFailWithDescription description: String, inFile filePath: String?, atLine lineNumber: Int) {
        hasFailed = true
        if !continueAfterFailure {
            expectation.fulfill()
        }
    }
    
    public func run(timeout: TimeInterval = 300, continueAfterFailure: Bool = false, beforeEachExample: ((Gherkin.Feature.Example) -> Void)?) {
        guard TestExecution.current == nil else { fatalError("Can't start running a TextExecution when there is already one running") }
        TestExecution.current = self
        self.continueAfterFailure = continueAfterFailure
        self.beforeEachExample = beforeEachExample
        XCTestObservationCenter.shared.addTestObserver(self)
        XCTContext.runActivity(named: feature.description ?? "Feature") {
            _ in
            remainingRules = feature.rules.reversed()
            DispatchQueue.main.async {
                self.nextRule()
            }
            switch XCTWaiter().wait(for: [expectation], timeout: timeout) {
            case .completed: break
            default: XCTFail("Text Execution for \(feature.description ?? "") timed out")
            }
            TestExecution.current = nil
        }
    }
    
    private func executeStep(_ step: Gherkin.Feature.Step) {
        XCTContext.runActivity(named: step.description) {
            activity in
            do {
                let (definition, result) = try findMatch(for: step, in: stepDefinitions)
                try definition.action(StepDefinitionInput(step: step, result: result))
            } catch {
                XCTFail(error.localizedDescription)
            }
        }
        if continueAfterFailure || !hasFailed {
            nextStep()
        }
    }
    
    private func nextRule() {
        if let nextRule = remainingRules.popLast() {
            currentRule = nextRule
            remainingExamples = currentRule?.examples.reversed() ?? []
            var result = XCTWaiter.Result.completed
            XCTContext.runActivity(named: currentRule?.description ?? "Rule") {
                _ in
                self.ruleExpectation = XCTestExpectation()
                self.nextExample()
                result = XCTWaiter().wait(for: [self.ruleExpectation!], timeout: .indefinitely)
            }
            if result == .completed { self.nextRule() }
        } else {
            self.expectation.fulfill()
        }
    }
    
    private func nextExample() {
        if let nextExample = remainingExamples.popLast() {
            currentExample = nextExample
            app = isUITest ? XCUIApplication() : nil
            let tags = Array(Set((currentExample?.tags + currentRule?.tags + feature.tags) ?? []))
            if let tagExpression = tagExpression, !tagExpression.matches(tags) {
                let description = "Example: [SKIPPED] \(currentExample?.description.map{ $0.suffix(from: $0.lowercased().range(of: "example")?.upperBound ?? $0.startIndex).drop{ $0 == " " || $0 == ":" } } ?? "" )"

                XCTContext.runActivity(named: description) { _ in }
                self.nextExample()
                return
            }
            remainingSteps = ((feature.background?.steps ?? []) + (currentExample?.steps ?? [])).reversed()
            var result = XCTWaiter.Result.completed
            currentExample.map { beforeEachExample?($0) }
            XCTContext.runActivity(named: currentExample?.description ?? "Example") {
                _ in
                self.exampleExpectation = XCTestExpectation()
                self.nextStep()
                result = XCTWaiter().wait(for: [self.exampleExpectation!], timeout: .indefinitely)
            }
            if result == .completed { self.nextExample() }
        } else {
            ruleExpectation?.fulfill()        }
    }
    
    private func nextStep() {
        if let currentStep = currentStep {
            self.currentStep = nil
            executeStep(currentStep)
        } else if let nextStep = remainingSteps.popLast() {
            currentStep = nextStep
            self.nextStep()
        } else {
            exampleExpectation?.fulfill()
        }
    }
}
