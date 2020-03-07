//
//  TestKit.swift
//  TestKit
//
//  Created by Hall, Daniel on 7/13/19.
//

import XCTest

public var app: XCUIApplication!

internal var registeredStepDefinitions = [StepDefinition]()

internal var isUITest: Bool {
    return ProcessInfo.processInfo.processName == "XCTRunner" || ProcessInfo.processInfo.processName.hasSuffix("-Runner")
}

private var hasTestKitStarted = false


public func startTestKit() {
    guard !hasTestKitStarted else { return }
    hasTestKitStarted = true
    
    // Find all developer-created features and register their steps
    var count = UInt32(0)
    let classList = objc_copyClassList(&count)!
    Array(0..<Int(count)).forEach {
        if let theSuperclass = class_getSuperclass(classList[$0]), theSuperclass == TestKitStepDefinitions.self {
            (classList[$0] as! TestKitStepDefinitions.Type).register()
        }
    }
}


/// Method for finding a step definition that is a regex match for the provided step
internal func findMatch(for step: Gherkin.Feature.Step, in definitions: [StepDefinition]) throws -> (StepDefinition, NSTextCheckingResult) {
    let matches: [(StepDefinition, NSTextCheckingResult)] = definitions.compactMap {
        let results = $0.regex.matches(in: step.description, options: [], range: NSRange(step.description.startIndex..<step.description.endIndex, in: step.description))
        return results.isEmpty ? nil : ($0, results.first!)
    }
    switch matches.count {
    case 1: return matches.first!
    case 0: throw NSError(domain: "TestKit", code: 101, userInfo: [NSLocalizedDescriptionKey: "No matching Step Definitions found for the step '\(step.description)'"])
    default: throw NSError(domain: "TestKit", code: 102, userInfo: [NSLocalizedDescriptionKey: "Multiple matching Step Definitions found for the step '\(step.description)'"])
    }
}
