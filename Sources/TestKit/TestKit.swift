//
//  TestKit.swift
//  TestKit
//
//  Created by Hall, Daniel on 7/13/19.
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

public var app: XCUIApplication!

internal var isUITest: Bool {
    return ProcessInfo.processInfo.processName == "XCTRunner" || ProcessInfo.processInfo.processName.hasSuffix("-Runner")
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
