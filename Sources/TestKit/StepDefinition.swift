//
//  StepDefinition.swift
//  TestKit
//
//  Created by Hall, Daniel on 7/13/19.
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
