//
//  File.swift
//  
//
//  Created by Daniel Hall on 1/24/20.
//

import Foundation
import XCTest
@testable import TestKit


let simpleScenario =
"""
Feature: A Simple Scenario
Scenario: Parse this correctly
Given this text
When TestKit parses it as Gherkin
Then a Gherkin instance is created successfully
"""


final class SimpleScenarioTests: XCTestCase {
    func testSimpleScenario() {
        let expectedFeature = Gherkin.Feature(description: "Feature: A Simple Scenario", tags: nil, background: nil, rules: [.init(tags: nil, description: nil, examples: [.init(tags: nil, description: "Scenario: Parse this correctly", steps: [.init(description: "Given this text", argument: nil), .init(description: "When TestKit parses it as Gherkin", argument: nil), .init(description: "Then a Gherkin instance is created successfully", argument: nil)])])])
        let feature = try! Gherkin.parse(simpleScenario)
        XCTAssertEqual(feature, expectedFeature)
    }

    static var allTests = [
        ("testSimpleScenario", testSimpleScenario),
    ]
}

