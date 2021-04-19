//  XCTestExtensions.swift
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

import Foundation
import XCTest


public extension XCTestCase {
    
    func testAllFeatures(in directory: String?, recursively: Bool = true, stepDefinitions: [StepDefinition], tags: TagExpression? = nil, continueAfterFailure shouldContinue: Bool = false, timeout: TimeInterval = 600, beforeEachExample: ((Gherkin.Feature.Example) -> Void)? = nil) {
        let bundle = Bundle(for: type(of: self))
        let urls: [URL]
        if !recursively {
            urls = bundle.urls(forResourcesWithExtension: "feature", subdirectory: directory) ?? []
        } else {
            let subdirectoryPath = directory.map { "/\($0)" } ?? ""
            let enumerator = FileManager.default.enumerator(atPath: bundle.bundlePath.appending(subdirectoryPath))
            var recursiveURLs: [URL] = []
            while let path = enumerator?.nextObject() as? String {
                if URL(fileURLWithPath: path).pathExtension == "feature" {
                    recursiveURLs.append(bundle.bundleURL.appendingPathComponent(subdirectoryPath + "/" + path))
                }
            }
            urls = recursiveURLs
        }
        return testFeatures(urls, stepDefinitions: stepDefinitions, tags: tags, continueAfterFailure: shouldContinue, timeout: timeout, beforeEachExample: beforeEachExample)
    }

    func testFeatures(_ urls: [URL], stepDefinitions: [StepDefinition], tags: TagExpression? = nil, continueAfterFailure shouldContinue: Bool = false, timeout: TimeInterval = 600, beforeEachExample: ((Gherkin.Feature.Example) -> Void)? = nil) {
        urls.forEach {
            testFeature($0, stepDefinitions: stepDefinitions, tags: tags, continueAfterFailure: shouldContinue, timeout: timeout)
        }
    }
    
    func testFeatures(_ features: [Gherkin.Feature], stepDefinitions: [StepDefinition], tags: TagExpression? = nil, continueAfterFailure shouldContinue: Bool = false, timeout: TimeInterval = 600, beforeEachExample: ((Gherkin.Feature.Example) -> Void)? = nil) {
        features.forEach {
            testFeature($0, stepDefinitions: stepDefinitions, tags: tags, continueAfterFailure: shouldContinue, timeout: timeout, beforeEachExample: beforeEachExample)
        }
    }
    
    func testFeature(_ url: URL, stepDefinitions: [StepDefinition], tags: TagExpression? = nil, continueAfterFailure shouldContinue: Bool = false, timeout: TimeInterval = 600, beforeEachExample: ((Gherkin.Feature.Example) -> Void)? = nil) {
        do {
            let feature = try Gherkin.Feature(url)
            testFeature(feature, stepDefinitions: stepDefinitions, tags: tags, continueAfterFailure: shouldContinue, timeout: timeout, beforeEachExample: beforeEachExample)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    func testFeature(_ feature: Gherkin.Feature, stepDefinitions: [StepDefinition], tags: TagExpression? = nil, continueAfterFailure shouldContinue: Bool = false, timeout: TimeInterval = 600, beforeEachExample: ((Gherkin.Feature.Example) -> Void)? = nil) {
        TestExecution(feature: feature, stepDefinitions: stepDefinitions, tagExpression: tags).run(continueAfterFailure: shouldContinue, beforeEachExample: beforeEachExample)
    }
}

public extension TimeInterval {
    /// This is a workaround for an XCTest bug that makes XCTWaiter fail with large timeouts.  This is about as large a timeout as would work in my testing
    static var indefinitely: TimeInterval {
        return 86400
    }
}
