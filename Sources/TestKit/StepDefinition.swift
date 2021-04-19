//
//  StepDefinition.swift
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


public struct StepDefinition {
    internal let regex: NSRegularExpression
    internal let action: (StepDefinitionInput) throws -> ()
    public init(expression: String, action: @escaping (StepDefinitionInput) throws -> ()) {
        self.action = action
        
        regex = try! NSRegularExpression(pattern: "^(?:(?i)given|when|then|and|but)[\\s]+" + expression.trimmingCharacters(in: .init(charactersIn: "^$")) + "$")
    }
}

public struct StepDefinitionInput {
    private let result: NSTextCheckingResult
    public let step: Gherkin.Feature.Step
    
    internal init(step: Gherkin.Feature.Step, result: NSTextCheckingResult) {
        self.step = step
        self.result = result
    }
    
    public subscript(_ captureGroupName: String) -> String? {
        get {
            let range = result.range(withName: captureGroupName)
            return range.location == NSNotFound ? nil : (step.description as NSString).substring(with: range)
        }
    }
}

public func given(_ expression: String, action: @escaping (StepDefinitionInput) throws -> ()) -> StepDefinition {
    StepDefinition(expression: expression, action: action)
}

public func when(_ expression: String, action: @escaping (StepDefinitionInput) throws -> ()) -> StepDefinition {
    StepDefinition(expression: expression, action: action)
}

public func then(_ expression: String, action: @escaping (StepDefinitionInput) throws -> ()) -> StepDefinition {
    StepDefinition(expression: expression, action: action)
}
