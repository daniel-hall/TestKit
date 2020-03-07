//
//  TestKitStepDefinitions.swift
//  TestKit
//
//  Created by Hall, Daniel on 7/13/19.
//

import XCTest

@objc open class TestKitStepDefinitions: NSObject {
    
    public typealias Step = Gherkin.Feature.Step
    public typealias DataTable = Step.DataTable
    public typealias Formatter = DataTable.Formatter
    
    // Required override in subclasses to add step definitions for different given, when, and then statements
    open class func register() {
        assertionFailure("You must override the register() class method in your TestKitStepDefinitions subclass")
    }
    
    private static func add(_ expression: String, action: @escaping (StepDefinitionInput) throws -> ()) {
        registeredStepDefinitions.append(StepDefinition(expression: expression, action: action))
    }
    
    public static func given(_ expression: String, action: @escaping (StepDefinitionInput) throws -> ()) {
        add(expression, action: action)
    }
    
    public static func when(_ expression: String, action: @escaping (StepDefinitionInput) throws -> ()) {
        add(expression, action: action)
    }
    
    public static func then(_ expression: String, action: @escaping (StepDefinitionInput) throws -> ()) {
        add(expression, action: action)
    }
}
