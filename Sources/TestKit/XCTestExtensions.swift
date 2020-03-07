//  XCTestExtensions.swift
//  TestKit
//
//  Created by Hall, Daniel on 7/13/19.
//

import Foundation
import XCTest


public extension XCTestCase {
    
    func testFeatures(_ names: [String], tags: TagExpression? = nil, continueAfterFailure shouldContinue: Bool = false, timeout: TimeInterval = 600) {
        names.forEach {
            testFeature($0, tags: tags, continueAfterFailure: shouldContinue, timeout: timeout)
        }
    }
    
    func testFeatures(_ features: [Gherkin.Feature], tags: TagExpression? = nil, continueAfterFailure shouldContinue: Bool = false, timeout: TimeInterval = 600) {
        features.forEach {
            testFeature($0, tags: tags, continueAfterFailure: shouldContinue, timeout: timeout)
        }
    }
    
    func testFeature(_ name: String, tags: TagExpression? = nil, continueAfterFailure shouldContinue: Bool = false, timeout: TimeInterval = 600) {
        guard let url = Bundle(for: type(of: self)).url(forResource: name, withExtension: "feature") else {
            XCTFail("Could not find the file \(name).feature")
            return
        }
        do {
            let feature = try Gherkin.Feature(url)
            testFeature(feature, tags: tags, continueAfterFailure: shouldContinue, timeout: timeout)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    func testFeature(_ feature: Gherkin.Feature, tags: TagExpression? = nil, continueAfterFailure shouldContinue: Bool = false, timeout: TimeInterval = 600) {
        startTestKit()
        TestExecution(feature: feature, stepDefinitions: registeredStepDefinitions, tagExpression: tags).run(continueAfterFailure: shouldContinue)
    }
}

public extension TimeInterval {
    /// This is a workaround for an XCTest bug that makes XCTWaiter fail with large timeouts.  This is about as large a timeout as would work in my testing
    static var indefinitely: TimeInterval {
        return 86400
    }
}
