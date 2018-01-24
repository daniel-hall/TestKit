//
//  StepHandling.swift
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

/// When a Step Handler is matched against the current step, the matching RegEx values, and any doc string and data table from the step definition are returned to the step handler inside this data structure
public struct StepInput {
    public let matchedValues:MatchedValues
    public let docString:String?
    public let dataTable:[[String: String]]?
}

/// A wrapper around the dictionary of matched token-value pairs.  It force unwraps the value at the given key since it is always assumed to exist in the event of a regex match
public struct MatchedValues {
    let dictionary: [String: String]
    internal init(_ dictionary:[String: String]) {
        self.dictionary = dictionary
    }
    public subscript(key: String) -> String {
        guard let value = dictionary[key] else {
            fatalError("The Matched Values for the current step do not contain a value for the key \(key)")
        }
        return value
    }
}

/// An object that allows a step handler to report back the success or failure of its actions
public class StepCallback {
    internal var completed = false
    private let success:()->()
    private let failure:(String)->()
    public func succeed() {
        if (!completed) {
            completed = true
            success()
        }
    }
    public func fail(reason:String) {
        if (!completed) {
            completed = true
            failure(reason)
        }
    }
    internal init(success:@escaping ()->(), failure:@escaping (String)->()) {
        self.success = success
        self.failure = failure
    }
}

/// A simple struct that contains a Regex expression to match against the current step, and a closure to run in the event of a match
internal struct Handler {
    let regex:NSRegularExpression
    let action:(StepInput, StepCallback)->()
    let tokens:[String]
    let timeout:TimeInterval?
    init(_ expression:String, timeout:TimeInterval? = nil, action: @escaping (StepInput, StepCallback)->()) {
        var pattern = expression
        let simpleRegex = try! NSRegularExpression(pattern: "(?<!\\\\)(<\\w+>)", options: [])
        let simpleMatches = simpleRegex.matches(in: pattern, options: [], range: NSRange(location: 0, length: pattern.count))
        let simpleTokens:[String] = simpleMatches.reduce([]) {
            (result, match) in
            return result + Array(0..<(match.numberOfRanges > 0 ? match.numberOfRanges - 1 : 0)).map {
                let range = match.range(at: $0)
                return (pattern as NSString).substring(with: range)
            }
        }
        simpleTokens.forEach{ pattern = pattern.replacingOccurrences(of: $0, with: "(.+)")}
        
        let customRegex = try! NSRegularExpression(pattern: "(?<!\\\\)(<\\w+\\(.+\\)>)", options: [])
        let customMatches = customRegex.matches(in: pattern, options: [], range: NSRange(location: 0, length: pattern.count))
        var customTokens:[String] = customMatches.reduce([]) {
            (result, match) in
            return result + Array(0..<(match.numberOfRanges > 0 ? match.numberOfRanges - 1 : 0)).map {
                let range = match.range(at: $0)
                return (pattern as NSString).substring(with: range)
            }
        }
        customTokens.forEach { pattern = pattern.replacingOccurrences(of: $0, with: $0[$0.range(of: "(")!.lowerBound...].trimmingCharacters(in: CharacterSet(charactersIn: "<>"))) }
        customTokens = customTokens.map {
            return String($0[...$0.range(of: "(")!.lowerBound])
        }
        tokens = (simpleTokens + customTokens).map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "<>")) }
        regex = try! NSRegularExpression(pattern: pattern)
        self.timeout = timeout
        self.action = action
    }
}
